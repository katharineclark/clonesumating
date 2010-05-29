#!/usr/bin/perl

use lib '../../lib';
 
use Data::Dumper;
use template2;
use Profiles;
use Users;
use Cache;
use CM_Tags;
use points;
use blog;

use strict;


{ 

	my $P = Profiles->new();
	$P->{user}{system}{tab} = 'Questions';
	my %commands = (
		'' => \&previous,
		'/current' => \&showContest,
		'/winners' => \&winners,
		'/save' => \&save,
		'/bling' => \&bling,
		'/previous' => \&previous,
	);

	$P->{user}{page}{title} = "See Photos That Don't Suck";

	if ($commands{$P->{command}}) {
		$commands{$P->{command}}->($P);
	} else {
		$commands{''}->($P);
	}

}



sub showContest {
	my ($P) = @_;
	my $sth;
	

	$P->{user}{page}{saved} = $P->{query}->param('saved');

	if ($P->{query}->param('contestId')) {
		$sth = $P->{dbh}->prepare("SELECT * FROM photo_contest WHERE id = ?");
		$sth->execute($P->{query}->param('contestId'));
	} else {
		$sth = $P->{dbh}->prepare("SELECT * FROM photo_contest WHERE itson=1 AND startDate <= NOW() ORDER BY startDate DESC LIMIT 1");
		$sth->execute;
	}
	my $contest = $sth->fetchrow_hashref;
	$sth->finish;
	%{$P->{user}{contest}} = %{$contest};
        $P->{user}{contest}{tagname} = lc cleanTag($P->{user}{contest}{tagname}).'_contest';

	if ($P->{user}{user}{id} && $P->{user}{user}{profileId}) {
		$P->{user}{contest}{readytopost} = 1;

		$P->{user}{photo}{incontest} = $P->{dbh}->selectrow_array("SELECT COUNT(*) FROM photo_contest_entry WHERE userId=? AND contestId=?",undef,$P->{user}{user}{id},$contest->{id}) ? 1 : 0;
	}

	my $offset = $P->{query}->param('offset') || 0;
	my $sql = "SELECT * FROM photo_contest_entry WHERE contestId = ? ORDER BY RAND() LIMIT 12";
	#my $sql = "SELECT userId,id as photoId FROM photos WHERE rank=1 ORDER BY RAND() LIMIT 49";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute($contest->{id});

	my $getvotes = $P->{dbh}->prepare("SELECT COUNT(*) FROM photo_contest_bling WHERE type = ? AND entryId = ?");
	my $getMyvote = $P->{dbh}->prepare("SELECT type FROM photo_contest_bling WHERE entryId = ? AND userId = ?") if $P->{user}{user}{id};
	my $photo = $P->{dbh}->prepare("SELECT width,height FROM photos WHERE id = ?");

	my $lastResponse = 0;
	while (my $entry = $sth->fetchrow_hashref) {
		$lastResponse = $entry->{id} if $entry->{id} > $lastResponse;
		$entry->{handle} = $P->{util}->getHandle($entry->{userId});
		$entry->{linkhandle} = $P->{util}->linkify($entry->{handle});
		
		$getvotes->execute('U',$entry->{id});
		$entry->{thumbups} = $getvotes->fetchrow || 0;
		$getvotes->execute('D',$entry->{id});
		$entry->{thumbdns} = $getvotes->fetchrow || 0;

		$photo->execute($entry->{photoId});
		($entry->{width},$entry->{height}) = $photo->fetchrow;

		if ($P->{user}{user}{id}) {
			$getMyvote->execute($entry->{id},$P->{user}{user}{id});
			$entry->{type} = $getMyvote->fetchrow if $getMyvote->rows;
		}
		push(@{ $P->{user}{entries}},{entry => $entry});
	}

	$getvotes->finish;
	if ($P->{user}{user}{id}) {
		$getMyvote->finish;
	}
	$photo->finish;
	$sth->finish;

	$sth = $P->{dbh}->prepare("SELECT count(1) FROM photo_contest_entry WHERE contestId=$P->{user}{contest}{id}");
	$sth->execute;
	$P->{user}{contest}{responses} = $sth->fetchrow;
	$sth->finish;
	

	# create leaderboard
	$sth = $P->{dbh}->prepare("SELECT b.entryId AS id,e.insertDate,COUNT(*) AS count FROM photo_contest_bling b ,photo_contest_entry e WHERE e.id=b.entryId AND b.contestId = ? AND b.type=? GROUP BY 1,2");
	$sth->execute($contest->{id},'U');
	my $ups = $sth->fetchall_hashref('id');
	$sth->execute($contest->{id},'D');
	my $dns = $sth->fetchall_hashref('id');
	$sth->finish;

	my %best;
	for my $id (keys %$ups) {
		my $total = $ups->{$id}->{count} - $dns->{$id}->{count};
		$best{$id} = [$total,$ups->{$id}->{insertDate}];
	}
	my @best = map [$best{$_},$_] => sort {$best{$b}->[0] <=> $best{$a}->[0] || $best{$a}->[1] cmp $best{$b}->[1]} keys %best;

	my $count=0;
	my $sth = $P->{dbh}->prepare("SELECT id,userId,photoId FROM photo_contest_entry WHERE id = ?");
	my @ordinals = qw(1st 2nd 3rd 4th 5th 6th);
	for (@best[0..5]) {
		$sth->execute($ups->{$_->[1]}->{id});
		my $entry = $sth->fetchrow_hashref;
		next unless $entry;
		$entry->{handle} = $P->{util}->getHandle($entry->{userId});
		$entry->{linkhandle} = $P->{util}->linkify($entry->{handle});
		$entry->{place} = $count+1;
		$entry->{ordinal} = $ordinals[$count];

		$getvotes->execute('U',$entry->{id});
		$entry->{thumbups} = $getvotes->fetchrow || 0;
		$getvotes->execute('D',$entry->{id});
		$entry->{thumbdns} = $getvotes->fetchrow || 0;
		
		#%{$P->{user}{winners}{$count++}{entry}} = %{$entry};
		push(@{ $P->{user}{winners} },{entry => $entry});
	}
	$getvotes->finish;
	$sth->finish;

	$P->{user}{page}{lastmessage} = (defined $P->{user}{entries}[0] ? $P->{user}{entries}[0]{entry}{id} : $lastResponse) || 0;

	$sth = $P->{dbh}->prepare("SELECT * FROM photo_contest_entry WHERE userId = ? AND contestId=?");
	$sth->execute($P->{user}{user}{id},$contest->{id});
	if ($sth->rows) {
		my $entry = $sth->fetchrow_hashref;

		my $b = $P->{dbh}->prepare("SELECT COUNT(*) FROM photo_contest_bling WHERE entryId = ? AND type = ?");
		$b->execute($entry->{id},'U');
		$entry->{ups} = $b->fetchrow||0;
		$b->execute($entry->{id},'D');
		$entry->{dns} = $b->fetchrow||0;
		$b->finish;
		$P->{user}{entry} = $entry;
	}
	$sth->finish;
	$P->{user}{entry}{photoId} ||= 0;

	$P->{user}{offset}{next} = $offset + ($count > 12 ? $count : 0);

	print $P->Header();
	print processTemplate($P->{user},"play/photos/current.html");
}


sub save {
	my ($P) = @_;
	my $contestId = $P->{query}->param('id');
	my $photoId = $P->{query}->param('photoId')||0;

	my $entryId = $P->{dbh}->selectrow_array("SELECT id FROM photo_contest_entry WHERE userId=$P->{user}{user}{id} AND contestId = $contestId");
	$P->{dbh}->do("DELETE FROM photo_contest_entry WHERE userId=$P->{user}{user}{id} AND contestid=$contestId");
	$P->{dbh}->do("DELETE FROM photo_contest_bling WHERE entryId = $entryId");
	if ($photoId == 0) {
		my $contestname = $P->{dbh}->selectrow_array("SELECT tagname FROM photo_contest WHERE id = ?",undef,$contestId);
		my $tid = $P->{dbh}->selectrow_array("SELECT id FROM tag WHERE value = ?",undef, lc(cleanTag($contestname.'_contest')) );
		removeTag($P->{dbh},$tid,$P->{user}{user}{id});
	} else {
		my $contestname = $P->{dbh}->selectrow_array("SELECT name FROM photo_contest WHERE id = ?",undef,$contestId);
		$P->{dbh}->do("INSERT INTO photo_contest_entry (userId,photoId,insertDate,contestId) VALUES (?,?,NOW(),?)",undef,$P->{user}{user}{id},$photoId,$contestId) or warn "CANNOT ENTER CONTEST: ".$P->{dbh}->errstr;
		if (0) {
		my $Points = points->new(dbh => $P->{dbh}, cache => $P->{cache});
		$Points->storeTransaction({
			userid	=> $P->{user}{user}{id},
			points	=> $Points->{system}{photocontest},
			type	=> 'system',
			desc	=> "$Points->{system}{photocontest}{desc} $contestname"
			}
		);
		}

	# set as primary profile photo
	if ($photoId > 0) {
		$P->{dbh}->do("UPDATE photos SET rank=99 WHERE rank=1 AND userId = ?",undef,$P->{user}{user}{id});
		$P->{dbh}->do("UPDATE photos SET rank=1 WHERE id = ?",undef,$photoId);
	}

    my $contestname = $P->{dbh}->selectrow_array("SELECT tagname FROM photo_contest WHERE id = ?",undef,$contestId);
    addTag($P->{dbh},$contestname.'_contest',$P->{user}{user}{id},9656);

  		my $blog = blog->new(db => $P->{dbh});
        if ($blog->blogthis($P->{user}{user}{id},'contest')) {
            my $sql = "SELECT description FROM photo_contest WHERE id=$contestId";
            my $getQ = $P->{dbh}->prepare($sql); 
            $getQ->execute;
            $P->{user}{blog}{name} = $getQ->fetchrow;
            $P->{user}{blog}{photoId} = $photoId;
            my $blogpost = processTemplate($P->{user},"blog/photo.html",1);
            $blog->post($P->{user}{user}{id},'qow','Consumating\'s Photo Contest',$blogpost);
        }



	} # done saving



	# update user cache
	my $u = Users->new(dbh => $P->{dbh},cache => $P->{cache}, userId => $P->{user}{user}{id},force => 1);

	print $P->{query}->redirect("/weekly/photo/index.pl/current?saved=1");
}






sub bling {
	my ($P) = @_;

	my $entryId = $P->{query}->param('en');
	my $type = $P->{query}->param('t');
	my $uid = $P->{user}{user}{id};

	my $oldbling = $P->{dbh}->selectrow_hashref("SELECT * FROM photo_contest_bling WHERE entryId=$entryId AND userId=$uid");

	my $userId = $P->{dbh}->selectrow_array("SELECT userId FROM photo_contest_entry WHERE id = ?",undef,$entryId);
	my $User = Users->new(dbh => $P->{dbh}, cache => new Cache, userId => $userId);

	if ($oldbling) {
		$P->{dbh}->do("DELETE FROM photo_contest_bling WHERE entryId=$entryId AND userId=$uid");
		if ($oldbling->{type} eq 'D') {
			$User->updateField('popularity',$User->{profile}->{popularity}+3);
		} else {
			$User->updateField('popularity',$User->{profile}->{popularity}-3);
		}
	} elsif ($type eq 'U') {
		$User->updateField('popularity',$User->{profile}->{popularity}+2);
	} else {
		$User->updateField('popularity',$User->{profile}->{popularity}-1);
	}
	my $cid = $P->{dbh}->selectrow_array("SELECT contestId FROM photo_contest_entry WHERE id = $entryId");
	$P->{dbh}->do("INSERT INTO photo_contest_bling (contestId,entryId,userId,type,insertDate) VALUES (?,?,?,?,NOW())",undef,$cid,$entryId,$uid,$type);


	my $sth = $P->{dbh}->prepare("SELECT type,COUNT(*) AS count FROM photo_contest_bling WHERE entryId=? GROUP BY 1");
	$sth->execute($entryId);
	my %blings;
	while (my @r = $sth->fetchrow) {
		$blings{$r[0]} = $r[1];
	}
	$sth->finish;
	$blings{U}=0 unless $blings{U};
	$blings{D}=0 unless $blings{D};
	
	print $P->Header();
	print "$type;".join(';',map{"$_-$blings{$_}"}keys %blings);
}

sub previous {
	my ($P) = @_;
	$P->{user}{contest} = $P->{dbh}->selectrow_hashref("SELECT * FROM photo_contest WHERE itson=1 AND startDate <= NOW() ORDER BY startDate DESC LIMIT 1") || {name => 'No Contest', description => "What?!? There's no contest going on right now!"};

	$P->{user}{contest}{tagname} = lc cleanTag($P->{user}{contest}{tagname}).'_contest';

	$P->{user}{contest}{responses} = $P->{dbh}->selectrow_array("SELECT count(*) FROM photo_contest_entry WHERE contestId = $P->{user}{contest}{id};");

	$P->{user}{nextcontest} = $P->{dbh}->selectrow_hashref("SELECT * FROM photo_contest WHERE startDate > '$P->{user}{contest}{startDate}' ORDER BY startDate ASC LIMIT 1");

      # get contest entrants
        {
                my $sql = qq|SELECT userId,photoId FROM photo_contest_entry WHERE contestId = $P->{user}{contest}{id} ORDER BY RAND() LIMIT 6|;
                my $sth = $P->{dbh}->prepare($sql);
                $sth->execute;
                my $count = 0;
                while (my ($uid,$pid) = $sth->fetchrow) {

                         my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid);
					 	$User->{profile}{photoId} = $pid;
						push(@{ $P->{user}{photocontestentries}},{profile => $User->profile});
                        #$P->{user}{photocontestentries}{$count}{profile} = $User->profile;
						#$P->{user}{photocontestentries}{$count}{profile}{photoId} = $pid;
						#$count++;
                }
                $sth->finish;
        }



	my $sth = $P->{dbh}->prepare("SELECT * FROM photo_contest WHERE itson=0 AND startDate <= NOW() ORDER BY startDate DESC LIMIT 10");
	my $substh = $P->{dbh}->prepare("SELECT id,userId,contestId,photoId FROM photo_contest_entry WHERE id = ?");
	my $leaderboard = $P->{dbh}->prepare("SELECT b.entryId AS id,COUNT(*) AS count FROM photo_contest_bling b WHERE b.contestId = ? AND b.type=? GROUP BY 1");
	my $myvotes = $P->{dbh}->prepare("SELECT COUNT(*) FROM photo_contest_entry e, photo_contest_bling b WHERE b.entryId=e.id AND e.contestId = ? AND e.userId = ? AND b.type = ?");
	$sth->execute;
	my $count = 0;
	while (my $c = $sth->fetchrow_hashref) {

		delete $P->{user}{winners};

		# create leaderboard
		$leaderboard->execute($c->{id},'U');
		my $ups = $leaderboard->fetchall_hashref('id');
		$leaderboard->execute($c->{id},'D');
		my $dns = $leaderboard->fetchall_hashref('id');

		my %best;
		for my $id (keys %$ups) {
			my $total = $ups->{$id}->{count} - $dns->{$id}->{count};
			$best{$id} = [$total,$ups->{$id}->{insertDate}];
		}
		my @best = map [$best{$_},$_] => sort {$best{$b}->[0] <=> $best{$a}->[0] || $best{$a}->[1] cmp $best{$b}->[1]} keys %best;

		for (@best) {
			$substh->execute($_->[1]);
			my $entry = $substh->fetchrow_hashref;
			next unless $entry;
			$entry->{handle} = $P->{util}->getHandle($entry->{userId});
			$entry->{linkhandle} = $P->{util}->linkify($entry->{handle});

			$entry->{votes} = $_->[0][0];
			
			%{$P->{user}{winners}[0]{entry}} = %{$entry};
			last;
		}

		$c->{totalvotes} = $P->{dbh}->selectrow_array("SELECT COUNT(*) FROM photo_contest_bling WHERE contestId = $c->{id}");
		my %total = map {$_ => 1}(keys %$ups, keys %$dns);
		$c->{totalentries} = $P->{dbh}->selectrow_array("SELECT COUNT(*) FROM photo_contest_entry WHERE contestId = $c->{id}");

		if ($P->{user}{user}{id}) {
			$myvotes->execute($c->{id},$P->{user}{user}{id},'U');
			my $ups = $myvotes->fetchrow;
			$myvotes->execute($c->{id},$P->{user}{user}{id},'D');
			my $dns = $myvotes->fetchrow;
			if ($ups || $dns) {
				$c->{myvotes} = $ups - $dns;
			}
		}

		$c->{leaderboard} = processTemplate($P->{user},"play/photos/leaderboard.html",1);

		#%{$P->{user}{contests}{$count++}{contest}} = %{$c};
		push(@{$P->{user}{contests}},{contest => $c });

	}
	$sth->finish;

	print $P->Header();
	print processTemplate($P->{user},'play/photos/index.html');
}

sub winners {
	my ($P) = @_;
	my $cid = $P->{query}->param('id');

	if ($cid eq 'current') {
		$cid = $P->{dbh}->selectrow_array("SELECT id FROM photo_contest WHERE itson=1 AND startDate <= NOW() ORDER BY startDate DESC LIMIT 1");
	}

	# get contest info
	my $sth = $P->{dbh}->prepare("SELECT * FROM photo_contest WHERE id = ?");
	$sth->execute($cid);
	my $contest = $sth->fetchrow_hashref;

	$contest->{winner} = $P->{user}{entries}[0]{entry}{handle};
	$contest->{linkwinner} = $P->{user}{entries}[0]{entry}{linkhandle};

	%{$P->{user}{contest}} = %{$contest};
	$sth->finish;


	# create leaderboard
	$sth = $P->{dbh}->prepare("SELECT b.entryId AS id,e.insertDate,COUNT(*) AS count FROM photo_contest_entry e left join photo_contest_bling b on e.id=b.entryId WHERE e.contestId = ? AND b.type=? GROUP BY 1,2");
	$sth->execute($contest->{id},'U');
	my $ups = $sth->fetchall_hashref('id');
	$sth->execute($contest->{id},'D');
	my $dns = $sth->fetchall_hashref('id');
	$sth->finish;

	my $getvotes = $P->{dbh}->prepare("SELECT COUNT(*) FROM photo_contest_bling WHERE type = ? AND entryId = ?");
	my $photo = $P->{dbh}->prepare("SELECT width,height FROM photos WHERE id = ?");


	my %best;
	for my $id (keys %$ups) {
		my $total = $ups->{$id}->{count} - $dns->{$id}->{count};
		$best{$id} = [$total,$ups->{$id}->{insertDate}];
	}
	my @best = map [$best{$_},$_] => sort {$best{$b}->[0] <=> $best{$a}->[0] || $best{$a}->[1] cmp $best{$b}->[1]} keys %best;

	my $count=0;
	my %places;
	$places{0} = "first";
	$places{1} = "second";
	$places{2} = "third";
	my $sth = $P->{dbh}->prepare("SELECT id,contestId,userId,photoId FROM photo_contest_entry WHERE id = ?");
	for (@best[0..2]) {
		$sth->execute($ups->{$_->[1]}->{id});
		my $entry = $sth->fetchrow_hashref;
		next unless $entry;
		$entry->{handle} = $P->{util}->getHandle($entry->{userId});
		$entry->{linkhandle} = $P->{util}->linkify($entry->{handle});
		$entry->{place} = $count+1;

		$getvotes->execute('U',$entry->{id});
		$entry->{thumbups} = $getvotes->fetchrow || 0;
		$getvotes->execute('D',$entry->{id});
		$entry->{thumbdns} = $getvotes->fetchrow || 0;

		$entry->{votes} = $entry->{thumbups} - $entry->{thumbdns};
		
		%{$P->{user}{$places{$count++}}} = %{$entry};
	}


	# get all other entries
	#$sth = $P->{dbh}->prepare("SELECT * FROM photo_contest_entry WHERE contestId = ? AND userId NOT IN (".join(',',map{$_->[1]}@best[0..2]).") ORDER BY RAND() LIMIT 140");
	#$sth->execute($cid);
	$count=0;
	#while (my $e = $sth->fetchrow_hashref) { 
	for (@best[3..$#best]) {
		$sth->execute($_->[1]);
		my $e = $sth->fetchrow_hashref;
		$e->{handle} = $P->{util}->getHandle($e->{userId});
		$e->{linkhandle} = $P->{util}->linkify($e->{handle});

		$getvotes->execute('U',$e->{id});
		$e->{thumbups} = $getvotes->fetchrow || 0;
		$getvotes->execute('D',$e->{id});
		$e->{thumbdns} = $getvotes->fetchrow || 0;

		$e->{votes} = $e->{thumbups} - $e->{thumbdns};
		
		delete $e->{contestId} if ($P->{user}{contest}{itson});
		push(@{ $P->{user}{entries} },{contest => $P->{user}{contest},entry=>$e});
		$count++;
		#$P->{user}{entries}{$count}{contest} = {itson => $P->{user}{contest}{itson}};
		#$P->{user}{entries}{$count++}{entry} = $e;
	}
	delete $P->{user}{entries} if $count == 0;
	$sth->finish;

    shift(@{$P->{user}{entries}});

	print $P->Header();
	print processTemplate($P->{user},'play/photos/winners.html');
}
