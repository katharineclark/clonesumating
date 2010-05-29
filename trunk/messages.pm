package messages;

use strict;

 
use Data::Dumper;
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use HTTP::Date;

use lib "lib";
use Profiles;
use template2;
use profmanager;
use Users;
use mail;
use CGI;
use Alerts;
use sphere;

my $cache = new Cache;

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');
	$r->headers_out->set('Expires', HTTP::Date::time2str(time - 60));

	my $P = Profiles->new(request => $r, cache => $cache);

	unless (ref $P) { return 0; }

	#warn "MESSAGES PID: $$";
	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> CGI->new($r),
	};
	bless $self, $class;

	$self->{command} = $P->{command};


	if (!$P->verify($P->{user})) {
		$r->headers_out->set(Location => "/");
		return REDIRECT;
	}

	#warn "COMMAND $self->{command}";

	if ($self->{command} eq "" || $self->{command} eq "/inbox") {
		return $self->showInbox();	
	} elsif ($self->{command} eq "/sendMessage") {
		return $self->sendMessage();
	} elsif ($self->{command} eq "/sent") {	
		return $self->messageSentLandingPage();
	} elsif ($self->{command} eq "/delete") {
		return $self->deleteMessages();
	}

	return showInbox($self);
}



sub showInbox {
	my $P = shift;
	my %ids;


	my $offset = $P->{query}->param('offset') || 0;
# get all the recent messages

	my %conversations;
	my $sql = qq|SELECT fromId,toId,date FROM messages WHERE (toId=$P->{user}{user}{id} OR fromId=$P->{user}{user}{id}) AND (hide NOT LIKE '%_$P->{user}{user}{id}_%' OR hide IS NULL) ORDER BY date DESC|;
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	while (my $message = $sth->fetchrow_hashref) {

			my $cid;
			if ($message->{toId} eq $P->{user}{user}{id}) {
				$cid = $message->{fromId};	
			} else {
				$cid = $message->{toId};
			}

			if ($conversations{$cid}) {
				if ($message->{date} gt $conversations{$cid}) {
					$conversations{$cid} = $message->{date};
				}
			} else {
				$conversations{$cid} = $message->{date};
			}

	}


    my $isRead = $P->{dbh}->prepare("SELECT COUNT(1) FROM messages WHERE (toId=$P->{user}{user}{id} AND fromId=?) AND isRead=0");
    my $lastMessageRead = $P->{dbh}->prepare("SELECT toId,isRead FROM messages WHERE (fromId=$P->{user}{user}{id} AND toId=?) OR (fromId=? AND toId=$P->{user}{user}{id}) ORDER BY date DESC LIMIT 1");

	my $i = 0;
	foreach my $uid (sort {$conversations{$b} cmp $conversations{$a}} keys %conversations) {
		my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or next;
		next unless ++$i > $offset;
		if ($i < $offset+11) {
			$User->{profile}{lastDate} = $conversations{$uid};
			$isRead->execute($uid);
			$User->{profile}{isRead} = $isRead->fetchrow;
			$lastMessageRead->execute($uid,$uid);
			if ($lastMessageRead->rows) {
				my @r = $lastMessageRead->fetchrow;
				if ($r[0] != $uid) {
					$User->{profile}{toIsRead} = 0;
				} else {
					$User->{profile}{toIsRead}= $r[1] == 1 ? 2 : 1;
				}
			} else {
				$User->{profile}{toIsRead} = 0;
			}

			push(@{ $P->{user}{recent} },{message => $User->profile });
		}
	}

	$P->{user}{message}{total} = $i;
	if ($i > $offset+10) {
		$P->{user}{inbox}{next} = $offset + 10;
	}
	if ($offset >= 10) {
		$P->{user}{inbox}{prev} = $offset - 10;
	}
			

	$isRead->finish;
	$lastMessageRead->finish;





	print processTemplate($P->{user},"messages.inbox.html");
	return 0;
}


sub sendMessage {

	my ($P) = @_;

# insert the new message into the database.  Then, send the recipient an email.
	my $to =   $P->{query}->param('to');
	my $from = $P->{query}->param('from');
	my $text = $P->{query}->param('message');
#warn Dumper($P->{query});

# check to see if this needs to debit a point

	my $sql = "SELECT count(1) FROM messages WHERE (toId=$to AND fromId=$from) OR (toId=$from and fromId=$to);";
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	my $count = $sth->fetchrow;
	$sth->finish;

	if ($count < 1 && $to != 9656) {
		if ($P->{user}{user}{points} < 1) {
			$P->ErrorOut("You can't send a message without any points.");
			return 0;
		}
	}

	# check blocklist
	my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $to);
	if ($U) {
		my $blocks = $U->getBlocklist($P->{user}{user}{id});
		if (ref $blocks eq 'ARRAY') {
			$P->{user}{blocklist} = {
				map {$_ => 1} @$blocks
			};
		}
		if ($P->{user}{blocklist}{message}) {
			$P->{req}->headers_out->set(Location => "/profiles/".$U->{profile}{linkhandle});
			return REDIRECT;
		}
	}
	

	$text = $P->{dbh}->quote($text);
	$sql = "INSERT INTO messages SET hide='',toId=$to,fromId=$from,date=NOW(),text=$text;";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute || warn("Failed inserting message into database.");
	$sth->finish;

	# unhide any previously hidden messages between these people
	$P->{dbh}->do("UPDATE messages SET hide=null WHERE (toid=$to and fromid=$from) OR (toid=$from AND fromid=$to)");


	# notes to the zombie are free
	if ($count == 0 && $to != 9656) {
		$P->{dbh}->do("UPDATE users SET points=points - 1 WHERE id=$P->{user}{user}{id};");
        	$P->{dbh}->do("INSERT INTO spent (userId,date,partner) VALUES ($P->{user}{user}{id},NOW(),'$P->{user}{global}{cobrand}')");
		$P->{user}{user}{points}--;

	}

	my $A = Alerts->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $to);
	if ($A->checkSub('newmessage')) {
		my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $to);
		if ($U) {
			my %data;
			$data{user} = $U->profile;
			$data{sender} = $P->{user}{user};
			$data{message} = {text => $text};
			$A->send('newmessage',\%data);
		}
	}
			

	$P->{req}->headers_out->set(Location => "/messages.csm/sent?to=$to");
	return (REDIRECT);
}



sub messageSentLandingPage {
	my ($P) = @_;

	my $to = $P->{query}->param('to');
	$P->{user}{page}{showpoints} = 1;

	my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $to);
	$P->{user}{profile} = $User->profile;


	if (0 && sphere::getSuperSphere($P)) {
		# randomize a little
		my $i;
		for ($i = @{$P->{user}{superResults}}; --$i; ) {
			my $j = int rand ($i+1);
			@{$P->{user}{superResults}}[$i,$j] = @{$P->{user}{superResults}}[$j,$i];
		}
	} else {
		my $sql = "SELECT profileId FROM thumb WHERE type='U' AND profileId != $P->{user}{user}{id} ORDER BY RAND() LIMIT 15";

		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;

		my $count =0;
		while (my $id = $sth->fetchrow) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id);
			next unless $User;
			push(@{$P->{user}{superResults}},{user => $User->profile});
			$count++;
			last if $count == 5;
		}
		$sth->finish;
	}



	print processTemplate($P->{user},"messages.sent.html");


	return 0;
}






sub deleteMessages {

	my ($P) = @_;
	my $otheruser = $P->{query}->param('userId');
	my $sth = $P->{dbh}->prepare("SELECT hide FROM messages WHERE (toId=? AND fromId=$P->{user}{user}{id}) OR (toId=$P->{user}{user}{id} AND fromId=?)");
	$sth->execute($otheruser,$otheruser);
	my $hide = $sth->fetchrow;
	$hide .= '_'.$P->{user}{user}{id}.'_';
#warn "UPDATING HIDE: $hide";
	$P->{dbh}->do("UPDATE messages SET hide = ?, isread = 1 WHERE (toId=? AND fromId=$P->{user}{user}{id}) OR (toId=$P->{user}{user}{id} AND fromId=?)",undef,$hide,$otheruser,$otheruser);

	$P->{req}->headers_out->set(Location => '/messages.csm/inbox');
	return REDIRECT;
}

sub ErrorOut {
	my $self = shift;
	$self->{user}{page}{message} = +shift;
	Profiles::ErrorOut($self->{user});
}
