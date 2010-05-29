package api::messages;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use util;

our @ISA = qw(api);

sub getUnreadCount {
    my $self = shift;
    my $userId = $self->{user}{user}{id};


	warn "$userId";

    my $sth = $self->{dbh}->prepare("SELECT count(1) from messages WHERE toId = ? AND isread = 0");
    $sth->execute($userId);
	my $unread = $sth->fetchrow;
	$sth->finish;
	my $data = "<unread>$unread</unread>";
    return $self->generateResponse('ok','updateUnread',$data);

}

sub getUnread {
	my $self = shift;
	my $userId = userLogin($self->{query});


	my $sth = $self->{dbh}->prepare("SELECT * from messages WHERE toId = ? AND isread = 0");
	$sth->execute($userId);

	my $userlookup = $self->{dbh}->prepare("SELECT handle FROM profiles WHERE userid = ?");
	my $photo = $self->{dbh}->prepare("SELECT id FROM photos WHERE userId = ? AND rank=1");
	my $data;
	while (my $mess = $sth->fetchrow_hashref) {
		$mess->{handle} = $self->{cache}->get("handleById$mess->{fromId}");
		unless ($mess->{handle}) {
			$userlookup->execute($mess->{fromId});
			$mess->{handle} = $userlookup->fetchrow;
		}
		$mess->{linkhandle} = linkify($mess->{handle});
		$photo->execute($mess->{fromId});
		$mess->{photoId} = $photo->fetchrow;
		$data .= $self->hashToXML('message',$mess);
	}
	$sth->finish;

	$sth = $self->{dbh}->prepare("SELECT h.profileId FROM hotlist h,users u WHERE u.id=h.profileId AND h.userId = ? ORDER BY u.lastLogin DESC");
	$sth->execute($userId);
	while (my $u = $sth->fetchrow_hashref) {
		$u->{handle} = $self->{cache}->get("handleById$u->{userId}");
		unless ($u->{handle}) {
			$userlookup->execute($u->{profileId});
			$u->{handle} = $userlookup->fetchrow;
		}
		$u->{linkhandle} = linkify($u->{handle});
		$photo->execute($u->{profileId});
		$u->{photoId} = $photo->fetchrow;
		$data .= $self->hashToXML('user',$u);
	}
	$sth->finish;

	return $self->generateResponse('ok','listMessages',$data);
}
sub send {
	my $self = shift;
	my $userId = $self->{user}{user}{id};
	my $text = $self->{query}->param('text');
	my $toId = $self->{query}->param('toId');


# check to see if this needs to debit a point
	my $sql = "SELECT count(1) FROM messages WHERE (toId=$toId AND fromId=$userId) OR (toId=$userId and fromId=$toId)";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $count = $sth->fetchrow;
	$sth->finish;

	if ($count < 1 && $toId != 9656) {
		if ($self->{user}{user}{points} < 1) {
			return $self->generateResponse('fail','',"You can't send a message without any points.");
		}
	}

# go!
	$self->{dbh}->do("INSERT INTO messages (date,text,fromId,toId) VALUES (NOW(),?,?,?)",undef,$text,$userId,$toId);
	return $self->generateResponse('ok','messageSent','');
}

sub markRead {
	my $self = shift;
	my $userId = $self->{user}{user}{id};

	my $fromId = $self->{query}->param('fromId');

	$self->{dbh}->do("UPDATE messages SET isread=1 WHERE fromId=? AND toId = ?",undef,$fromId,$userId);
	return $self->generateResponse('ok','','');
}

sub getMessage {
	my $self = shift;
	my $id = $self->{query}->param('messageId');
	my $fromId = $self->{query}->param('fromId');

	my $message;
	if ($id) {
		$message = $self->{dbh}->selectrow_hashref("SELECT * FROM messages WHERE id = ? AND (toId = ? OR fromId = ?)",undef,$id,$self->{user}{user}{id},$self->{user}{user}{id});
	} elsif (!$id && $fromId) {
		# get last message
		$message = $self->{dbh}->selectrow_hashref("SELECT * FROM messages WHERE (toId=? AND fromId = ?) OR (toId = ? AND fromId = ?) ORDER BY id DESC LIMIT 1",
			undef,
			$fromId,$self->{user}{user}{id},
			$self->{user}{user}{id},$fromId
		);
	} else {
		return undef;
	}

	my $dir = $message->{toId} == $self->{user}{user}{id} ? 'in' : 'out';
	my $date = template2::timeformat($message->{date});

	util::cleanHtml($message->{text});
	$message->{text} =~ s|\n|<br/>|gs;
	return $fromId 
		? $self->generateResponse('ok','handleGetMessage',<<XML)
<resp>$message->{text}</resp>
<dir>$dir</dir>
<to>$message->{toId}</to>
<from>$message->{fromId}</from>
<date>$date</date>
XML
		: "<resp>$message->{text}<br/><br/></resp>";
}

sub expandAll {
	my $self = shift;
	my $target = $self->{query}->param('target');
	my $sth = $self->{dbh}->prepare("SELECT id,text FROM messages WHERE (toId = ? AND fromId = ?) OR (fromId = ? AND toId = ?)");
	$sth->execute($self->{user}{user}{id},$target,$self->{user}{user}{id},$target);
	my $data;
	while (my $r = $sth->fetchrow_arrayref) {
		util::cleanHtml($r->[1]);
		$r->[1] =~ s|\n|<br/>|gs;
		$data .= qq|<message id="$r->[0]"><![CDATA[$r->[1]<br/><br/>]]></message>|;
	}
	return "<resp>$data</resp>";
}

sub spammer {
	my $self = shift;
	my $userId = $self->{query}->param('userId');

	return $self->generateResponse('fail','','No userid sent.') unless $userId;

	$self->{dbh}->do("INSERT INTO spamUser (userId,message,insertDate) values ($userId,(SELECT text FROM messages WHERE fromId=$userId AND toId=$self->{user}{user}{id} ORDER BY id DESC LIMIT 1),NOW())");
	$self->{dbh}->do("DELETE FROM messages WHERE fromId=$userId AND toId=$self->{user}{user}{id}");

	return $self->generateResponse('ok','','<ret>OK</ret>');
}

1;
