package teams;

use strict;
 
use Data::Dumper;
use Email::Valid;
use Image::Magick;
use CONFIG;

our $photoDir = "$staticPath/img/teams/";
our $tmp = $tempPath;

use lib qw(. lib);
use util;
use mail;
use template2;

our %sizes = (
	0	=> 'partnership',
	5	=> 'group',
	20	=> 'team',
	60	=> 'gang',
	100	=> 'army',
);

sub new {
	my $class = shift;
	my %args = @_;

	return bless {
		dbh		=> $args{dbh}||undef,
		cache	=> $args{cache}||undef,
		util	=> util->new(dbh => $args{dbh}, cache => $args{cache}),
		teams	=> [],
		sizes	=> \%sizes,
	}, ref($class) || $class;
}


sub getTeams {
	my $self = shift;
	my $args = shift;

	$args->{sort}   ||= 'memberCount DESC, points DESC';
	$args->{limit}  ||= 10;
	$args->{offset} ||= 0;
	$args->{where}	||= '1=1';

	$self->{teams} = [];

	my $sql = "SELECT id,".join(',',map{"memberCount >= $_ AS ".$self->{dbh}->quote($self->{sizes}{$_})}(keys %{$self->{sizes}}))." FROM teams WHERE $args->{where} ORDER BY $args->{sort} LIMIT $args->{offset},$args->{limit}";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	while (my $tt = $sth->fetchrow_hashref) {
		my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $tt->{id});
		for (sort{$b <=> $a} keys %{$self->{sizes}}) {
			if ($tt->{$self->{sizes}{$_}}) {
				$team->data(sizename => $self->{util}->singularize($self->{sizes}{$_}),1);
				$team->data(size => $_,1);
				last;
			}
		}
		push @{$self->{teams}}, $team;
	}

#warn "GETTEAMS $args->{where}: ".join(',',map{$_->data('name')}@{$self->{teams}});

	return @{$self->{teams}};
}

sub getUserTeams {
	my $self = shift;
	my $uid = shift;

	return grep {$_->isMember($uid)} $self->getTeams;
}

1;


package team;
use Data::Dumper;

sub err {
	open F, ">>/home/goldberg/err";
	print F $_[0]."\n";
	close F;
}

sub new {
	my $class = shift;
	my %args = @_;

	my $self = { 
		dbh		=> $args{dbh},
		cache	=> $args{cache},
		util	=> util->new(dbh => $args{dbh}, cache => $args{cache}),
	};

	bless $self, ref($class)||$class;


	if ($args{id} || $args{name}) {
		if ($args{id}) {
			$self->load($args{id});
		} elsif ($args{name}) {
			$self->loadByName($args{name});
		}
		return undef unless $self->data('id');
	}

	return $self;
}

sub load {
	my $self = shift;
	my $id = shift;

	unless (0 && ($self->{data} = $self->{cache}->get("team$id"))) {
		$self->{data} = $self->{dbh}->selectrow_hashref("SELECT * FROM teams WHERE id = ?",undef,$id);
		$self->commonLoad;
	}
	$self;
}

sub loadByName {
	my $self = shift;
	my $name = shift;

	my $cname = $self->{util}->linkify($self->data('name'));
	
	unless (0 && ($self->{data} = $self->{cache}->get("team$cname"))) {
		$self->{data} = $self->{dbh}->selectrow_hashref("SELECT * FROM teams WHERE name = ?",undef,$name);
		$self->commonLoad;
	}
	$self;
}
sub commonLoad {
	my $self = shift;

	$self->{data}{linkname} = $self->{util}->linkify($self->data('name'));
	if (ref $self->{data} eq 'HASH') {
		$self->{cache}->set("team$self->{data}->{id}",$self->{data});
		$self->{cache}->set("team$self->{data}{linkname}",$self->{data});
	}
	for (sort{$b <=> $a} keys %teams::sizes) {
		if ($self->{data}{memberCount} >= $_) {
			$self->{data}{sizename} = $self->{util}->singularize($teams::sizes{$_});
			$self->{data}{size} = $_;
			last;
		}
	}
	return $self;
}
	

sub members {
	my $self = shift;

    my $tid = $self->data('id');
 
	return @{$self->{members}} if ref $self->{members} eq 'ARRAY' && scalar @{$self->{members}};

	if (0) {


	$self->{members} = $self->{cache}->get("teammembers$tid");
	return @{$self->{members}} if ref $self->{members} eq 'ARRAY' && scalar @{$self->{members}};
	if (defined $self->{members}) { return (0) };

	}


	unless ($self->{membersSTH}) {
		$self->{membersSTH} = $self->{dbh}->prepare("SELECT * FROM team_members WHERE teamId = ? ORDER BY pointContribution");
	}
	$self->{membersSTH}->execute($tid);
	while (my $member = $self->{membersSTH}->fetchrow_hashref) {
		($member->{handle},$member->{linkhandle}) = $self->{util}->getHandle($member->{userId});
		push @{$self->{members}}, $member;
	}

	$self->{cache}->set("teammembers$tid",$self->{members});

	return ref $self->{members} eq 'ARRAY' ? @{$self->{members}} : (0);
}


sub invites {
	my $self = shift;

	return @{$self->{invites}} if ref $self->{invites} eq 'ARRAY' && scalar @{$self->{invites}};

	my $sth = $self->{dbh}->prepare("SELECT * FROM team_invites WHERE teamId = ? ORDER BY date");
	my $inc = $self->{dbh}->prepare("SELECT SUM(points) FROM team_invite_incentives WHERE inviteId = ?");
	$sth->execute($self->data('id'));
	while (my $member = $sth->fetchrow_hashref) {
		$inc->execute($member->{id});
		if ($inc->rows) {
			$member->{incentive} = $inc->fetchrow;
		}
		($member->{handle},$member->{linkhandle}) = $self->{util}->getHandle($member->{userId});
		push @{$self->{invites}}, $member;
	}
	return ref $self->{invites} eq 'ARRAY' ? @{$self->{invites}} : ();
}
sub joins {
	my $self = shift;
	my $uid  = shift;

	return @{$self->{joins}} if ref $self->{joins} eq 'ARRAY' && scalar @{$self->{joins}};


    my $mc = scalar $self->members;
    my $votesneeded = int((2/3) * $mc);
	if (($votesneeded % 2) == 0) {
		$votesneeded++;
	}

	my $sth  = $self->{dbh}->prepare("SELECT * FROM team_joins WHERE teamId = ? ORDER BY date");
	my $vote = $self->{dbh}->prepare("SELECT type FROM team_join_votes WHERE team_join_id = ? AND userId = $uid");
	$sth->execute($self->data('id'));
	while (my $join = $sth->fetchrow_hashref) {
		$vote->execute($join->{id});
		if ($vote->rows) {
			$join->{type} = $vote->fetchrow;
		}

    	my $ups = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_join_votes WHERE teamId=? AND team_join_Id=? AND type='U'",undef,$self->data('id'),$join->{id});
    	my $dns = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_join_votes WHERE teamId=? AND team_join_Id=? AND type='D'",undef,$self->data('id'),$join->{id});

		$join->{ups} = $ups;
		$join->{downs} = $dns;
		$join->{votesneeded} = $votesneeded;
		($join->{handle},$join->{linkhandle}) = $self->{util}->getHandle($join->{userId});
		push @{$self->{joins}}, $join;
	}
	return ref $self->{joins} eq 'ARRAY' ? @{$self->{joins}} : ();
}

sub boots {
	my $self = shift;
	my $uid  = shift;

	return @{$self->{boots}} if ref $self->{boots} eq 'ARRAY' && scalar @{$self->{boots}};


    my $mc = scalar $self->members;
    my $votesneeded = int((2/3) * $mc);
    if (($votesneeded % 2) == 0) {
        $votesneeded++;
    }

	my $sth  = $self->{dbh}->prepare("SELECT * FROM team_boots WHERE teamId = ?");
	my $vote = $self->{dbh}->prepare("SELECT type FROM team_boot_votes WHERE team_boot_id = ? AND userId = $uid");
	$sth->execute($self->data('id'));
	while (my $boot = $sth->fetchrow_hashref) {
		$vote->execute($boot->{id});
		if ($vote->rows) {
			$boot->{type} = $vote->fetchrow;
		}

        my $ups = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_boot_votes WHERE teamId=? AND team_boot_Id=? AND type='U'",undef,$self->data('id'),$boot->{id});
        my $dns = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_boot_votes WHERE teamId=? AND team_boot_Id=? AND type='D'",undef,$self->data('id'),$boot->{id});

        $boot->{ups} = $ups;
        $boot->{downs} = $dns;
        $boot->{votesneeded} = $votesneeded;

		($boot->{handle},$boot->{linkhandle}) = $self->{util}->getHandle($boot->{userId});
		push @{$self->{boots}}, $boot;
	}
	return ref $self->{boots} eq 'ARRAY' ? @{$self->{boots}} : ();
}

sub topics {
	my $self = shift;
	my $limit = shift;

	return @{$self->{topics}} if ref $self->{topics} eq 'ARRAY' && scalar @{$self->{topics}};

	$limit = "LIMIT $limit" if $limit > 0;

	my $sth = $self->{dbh}->prepare("SELECT DISTINCT t.*,COUNT(r.id) AS responseCount FROM teamTopic t LEFT JOIN teamResponse r ON r.teamTopicId = t.id WHERE t.teamId = ? GROUP BY 1 ORDER BY r.date DESC,t.date DESC $limit");

	$sth->execute($self->data('id'));
	while (my $top = $sth->fetchrow_hashref) {
		push @{$self->{topics}}, $top;
	}

	return ref $self->{topics} eq 'ARRAY' ? @{$self->{topics}} : ();
}


sub data {
	my $self = shift;

	if (ref $_[0]) {
		my $data = shift;
		for (keys %$data) {
			$self->{data}->{$_} = $data->{$_};
		}
		$self->save;
	} elsif ($_[0]) {
		my ($name,$value,$nosave) = @_;
		if ($value) {
			$self->{data}->{$name} = $value;
			$self->save unless $nosave;
		}
		return $self->{data}->{$name};
	}
	return $self->{data};
}

sub private {
	my $self = shift;
	return $self->data('private');
}
sub isMember {
	my $self = shift;
	my $uid = shift;

	return 1 if grep {$uid == $_->{userId}} $self->members;
	unless ($self->{isMemberSTH}) {
		$self->{isMemberSTH} = $self->{dbh}->prepare("SELECT COUNT(*) FROM team_members WHERE teamId=? AND userId=?");
	}
	$self->{isMemberSTH}->execute($self->data('id'),$uid);
	return $self->{isMemberSTH}->fetchrow;
}

sub save {
	my $self = shift;

	my @setfields = qw(name tagline description private points memberCount ownerId);


	if ($self->data('id')) {
		my $sql = "UPDATE teams SET ".join(',',map{"$_ = ?"} @setfields).",updatedate=NOW() WHERE id = ?";
		#warn "FILLING $sql;\n WITH: ".join(',',map{$self->data($_)}@setfields);
		$self->{dbh}->do("UPDATE teams SET ".join(',',map{"$_ = ?"} @setfields).",updatedate=NOW() WHERE id = ?",undef,map{$self->data($_)}(@setfields,'id'));
	} else {
		$self->{dbh}->do("INSERT INTO teams SET ".join(',',map{"$_ = ?"} @setfields).",date=NOW(),updatedate=NOW()",undef,map{$self->data($_)}@setfields);
		$self->data('id',$self->{dbh}->selectrow_array("SELECT last_insert_id()"));
	}

	$self->{cache}->set("team".$self->data('id'),$self->{data});
	$self->{cache}->set("team".$self->data('linkname'),$self->{data});

	return 1;
}

sub addmember {
	my $self = shift;
	my $userid = shift;
	my $invite = shift;

	my $user = Users->new(dbh => $self->{dbh}, cache => $self->{cache},userId => $userid) or return;

	if ($invite) {
		# add points to user, remove invite/incentive db rows
		my $points = $self->{dbh}->selectrow_array("SELECT SUM(points) FROM team_invite_incentives WHERE inviteId = ?",undef,$invite->{id});
		my $P = points->new(dbh => $self->{dbh}, cache => $self->{cache});
		$P->storeTransaction({userid => $userid, points => $points, type => 'team', desc => "Bonus for joining ".$self->data('name')});
		$self->{dbh}->do("DELETE FROM team_invite_incentives WHERE inviteId=?",undef,$invite->{id});
		$self->{dbh}->do("DELETE FROM team_invites WHERE id=?",undef,$invite->{id});

	}

	my $joinId = $self->{dbh}->selectrow_array("SELECT id FROM team_joins WHERE userId = $userid");
	if ($joinId) {
		$self->{dbh}->do("DELETE FROM team_joins WHERE id = $joinId");
		$self->{dbh}->do("DELETE FROM team_join_votes WHERE team_join_id = $joinId");
	}

	my $divisor = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_members WHERE userId = ?",undef,$userid) + 1;
	
	if ($self->{dbh}->do("INSERT INTO team_members (teamId,userId,pointContribution,joindate) VALUES (?,?,?,NOW())",undef,$self->data('id'),$userid,int($user->{profile}->{popularity}/$divisor))) {
		$self->data('memberCount',$self->data('memberCount')+1);
#warn "ADDING ".int($user->{profile}->{popularity}/$divisor)." POINTS FOR $userid TO TEAM ".$self->data('id');
		$self->data('points',$self->data('points')+int($user->{profile}->{popularity}/$divisor));
	}
}

sub reject {
	my $self = shift;
	my $userid = shift;

	$self->{dbh}->do("INSERT INTO team_reject (teamId,userId,date) VALUES (?,?,NOW())",undef,$self->data('id'),$userid);
}

sub rejected {
	my $self = shift;
	my $userid = shift;

	my $days =  $self->{dbh}->selectrow_array("TIME_TO_SEC(TIMEDIFF(NOW(),date))/60/60/24 FROM team_reject WHERE teamId=? AND userId=?",undef,$self->data('id'),$userid);
	return 30 - $days if (defined $days && $days < 30);
	return 0;
}

sub removemember {
	my $self = shift;
	my $userid = shift;
	my $boot = shift;

	$self->members();

	for my $member (@{$self->{members}}) {
		if ($member->{userId} == $userid) {
			$self->{dbh}->do("DELETE FROM team_members WHERE id = ?",undef,$member->{id});
			if ($boot) {
				$self->{dbh}->do("DELETE FROM team_boots WHERE id = ?",undef,$boot->{userId});
				$self->{dbh}->do("DELETE FROM team_boot_votes WHERE team_boot_id = ?",undef,$boot->{id});
			}
			$self->data('memberCount',$self->data('memberCount')-1);
			$self->data('points',$self->data('points')-$member->{pointContribution});

			$self->{cache}->delete("teammembers".$self->data('id'));

			$self->reject($userid);

			return 1;
		}
	}
	return;
}

sub disband {
	my $self = shift;

	my $id = $self->data('id');
	my $sth = $self->{dbh}->prepare("SELECT * FROM team_invite_incentives WHERE teamId = ?");
	$sth->execute($id);	
	my $points = points->new(dbh => $self->{dbh},cache => $self->{cache});
	while (my $tii = $sth->fetchrow_hashref) {
		$points->storeTransaction({
			userid 	=> $tii->{userId},
			points 	=> $tii->{points},
			type	=> 'team',
			desc	=> "Refund incentive, team ".$self->data('name')." disbanded."
		});
	}
	$sth->finish;
	
	my @deletes = (
		"DELETE FROM team_invites WHERE teamId = ?",
		"DELETE FROM team_invite_incentives WHERE teamId = ?",
		"DELETE FROM team_joins WHERE teamId = ?",
		"DELETE FROM team_join_votes WHERE teamId = ?",
		"DELETE FROM team_reject WHERE teamId = ?",
		"DELETE FROM team_members WHERE teamId = ?",
		"DELETE FROM teams WHERE id = ?",
	);
	for (@deletes) {
		$self->{dbh}->do($_,undef,$id);
	}
	$self->{cache}->delete("teammembers".$self->data('id'));
}

sub join {
	my $self = shift;
	my $uid = shift;

	# check for an invite
	my $invite = $self->{dbh}->selectrow_array("SELECT id FROM team_invites WHERE userId = ?",undef,$uid);
	if ($invite) {
		return $self->addmember($uid,$invite);
	}

	my $rejectdays = $self->rejected($uid);
	return "WAIT $rejectdays" if $rejectdays > 0;

	if ($self->private) {
		# private group, enable voting
		$self->{dbh}->do("INSERT INTO team_joins (teamId,userId,date) VALUES (?,?,NOW())",undef,$self->data('id'),$uid);

		my $msg = new mail;
		$msg->set(From 		=> 'notepasser@notepasser.consumating.com');
		$msg->set(subject	=> "Someone wants to join your team on Consumating.com!");
		$msg->set(body		=> template2::processTemplate($self->{data},"teams/join.txt",1));
		for ($self->members) {
			# send email
			my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $_->{userId}) or next;
			$msg->set(to		=> $U->{profile}->{username});
			$msg->send();
		}
		return "JOIN REQUEST ACCEPTED; TEAM ".$self->data('id')." USER $uid ";
	} else {
		# public group, add immediately
		return $self->addmember($uid);
	}
}

sub boot {
	my $self = shift;
	my $uid = shift;

	$self->{dbh}->do("INSERT INTO team_boots (teamId,userId,date) VALUES (?,?,NOW())",undef,$self->data('id'),$uid);

	my $msg = new mail;
	$msg->set(From 		=> 'notepasser@notepasser.consumating.com');
	$msg->set(subject	=> "Someone wants to boot a memeber from team on Consumating.com!");
	$msg->set(body		=> template2::processTemplate($self->{data},"teams/boot.txt",1));
	for ($self->members) {
		# send email
		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $_->{userId}) or next;
		$msg->set(to		=> $U->{profile}->{username});
		$msg->send();
	}
}


sub invite {
	my $self = shift;
	my $inviter = shift;
	my $handle = shift;

	unless (ref $self->{lksth}) {
		$self->{lksth} = $self->{dbh}->prepare("SELECT userid FROM profiles WHERE handle = ?");
		$self->{emsth} = $self->{dbh}->prepare("SELECT id FROM users WHERE username = ?");
	}

	if (Email::Valid->address($handle)) {
		$self->{emsth}->execute($handle);
		if ($self->{emsth}->rows) {
			return $self->setinvite($inviter,$self->{emsth}->fetchrow);
		} else {
			return $self->sendinvite($inviter,$handle);
		}
	} else {
		$self->{lksth}->execute($handle);
		if ($self->{lksth}->rows) {
			return $self->setinvite($inviter,$self->{lksth}->fetchrow);
		} else {
			return "INVITE HANDLE LOOKUP ERROR: $handle";
		}
	}
}

sub setinvite {
	my $self = shift;
	my $inviter = shift;
	my $id = shift;

	return "INVITE ERROR $id,$inviter" if $id == $inviter;

	my $rejectdays = $self->rejected($id);
	return "WAIT $rejectdays" if $rejectdays > 0;

	my $u = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $id) or return;

	my $joinId = $self->{dbh}->selectrow_array("SELECT id FROM team_joins WHERE userId = ?",undef,$id);
	if ($joinId) {
		# clear all voting and add member
		$self->{dbh}->do("DELETE FROM team_joins WHERE id = ?",undef,$joinId);
		$self->{dbh}->do("DELETE FROM team_join_votes WHERE team_join_id = ?",undef,$joinId);
		return $self->addmember($id);
	}

	unless ($self->{inviteSth}) {
		$self->{inviteSth} = $self->{dbh}->prepare("INSERT INTO team_invites (teamId,inviterId,userId,date) VALUES (?,?,?,NOW())");
	}
	$self->{inviteSth}->execute($self->data('id'),$inviter,$id);



	my $msg = new mail;
	$msg->set(From 		=> 'notepasser@notepasser.consumating.com');
	$msg->set(to		=> $u->{profile}->{username});
	$msg->set(subject	=> "You've been invited to join a team on Consumating.com!");
	$msg->set(body		=> template2::processTemplate($self->{data},"teams/invite.txt",1));
	$msg->send();
	return "INVITE SET";
}

sub sendinvite {
	my $self = shift;
	my $inviter = shift;
	my $email = shift;

	my $msg = new mail;
	$msg->set(From 		=> 'notepasser@notepasser.consumating.com');
	$msg->set(to		=> $email);
	$msg->set(subject	=> "Someone has invited you to join a team on Consumating.com!");
	$msg->set(body		=> template2::processTemplate($self->{data},"teams/invitejoin.txt",1));
	$msg->send();
	return "INVITE SENT";
}

sub invited {
	my $self = shift;
	my $uid = shift;

	my $invite = $self->{dbh}->selectrow_hashref("SELECT id,teamId,inviterId,notes,(TIME_TO_SEC(TIMEDIFF(NOW(),date))/60) AS minutes FROM team_invites WHERE userId = $uid");
	if (ref $invite) {
		$invite->{points} =  $self->{dbh}->selectrow_array("SELECT SUM(POINTS) FROM team_invite_incentives WHERE inviteId = $invite->{id}") || 0;
		$self->{util}->getHandle($invite->{inviterId},$invite);
		$invite->{date} = $self->{util}->timesince($invite->{minutes});
		return $invite;
	}
	return;
}

sub joinReq {
	my $self = shift;
	my $uid = shift;

	my $join = $self->{dbh}->selectrow_hashref("SELECT id,teamId,userId,(TIME_TO_SEC(TIMEDIFF(NOW(),date))/60) AS minutes FROM team_joins WHERE userId=$uid");
	if (ref $join) {
		$join->{date} = $self->{util}->timesince($join->{minutes});
		return $join;
	}
	return;
}

sub saveMascot {
	my $self = shift;
	my $query = shift;

	my $mascot = $query->param('mascot');
	my $teamId = $self->data('id');

	#warn "MASCOT $mascot";
	$mascot =~ s/.*?\.(.*?)/$1/gs;
	$mascot = lc $mascot;
	eval {
	open OUT, ">$tmp/$teamId.$mascot";
	my $F = $query->param('mascot');
	{
		local $/=undef;
		print OUT <$F>;
	}
	close OUT;
	};
	#warn "UPLOAD? $@";

	if ($mascot ne 'jpg') {
		system("convert $tmp/$teamId.$mascot $tmp/$teamId.jpg");
	}

	my $image = Image::Magick->new();

	my $rv = $image->Read("$tmp/$teamId.jpg");
	#warn "IMAGE READ $rv";
	$image->Set(magick => 'jpg');

	my ($w,$h) = $image->Get('width', 'height');
	if ($w != 0 && $h != 0) {

		# make it 50 px square

		my $mult = 50 / $h;

		my $nw = $w * $mult;
		my $nh = $h * $mult;


		$image->Scale(width => $nw, height => $nh);

		my $wv = $image->Write("$photoDir$teamId.jpg");
		#warn "IMAGE WRITE $wv";
	}
}

sub hasMascot {
	my $self = shift;
	return -e "$photoDir".$self->data('id').".jpg";
}
	
1;
