package api::admin;

use strict;
 
use Data::Dumper;


use lib qw(lib ../lib ../../lib);
use api;
use Users;
use util;
use template2;
use CM_Tags;
use messages;

our @ISA = qw(api);

sub validateAdmin {
	my $self = shift;

	if ($self->{user}{user}{id} != 1 && $self->{user}{user}{id} != 2447 && $self->{user}{user}{id} != 9656) {
		return 0;
	}
	return 1;
}

sub setStatus {
	my $self = shift;
	return $self->generateResponse('fail','','Who do you think you are?') unless $self->validateAdmin;

	my $userid = $self->{query}->param('userId');
	my $status = $self->{query}->param('status');


	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userid);
	$U->updateField(status => $status);

	return $self->generateResponse('ok','','<info>Rock on!</info>');
}

sub topicChannel {
	my $self = shift;
	return $self->generateResponse('fail','','Who do you think you are?') unless $self->validateAdmin;

	my $topicId = $self->{query}->param('topicId');
	my $channelId = $self->{query}->param('channelId');


	return $self->generateResponse('fail','','<info>you fail.</info>') unless $topicId && $channelId;

	$self->{dbh}->do("UPDATE profileTopic SET channelId = ? WHERE id = ?",undef,$channelId,$topicId);

	return $self->generateResponse('ok','','<info>Rock on!</info>');
}

sub topic_nsfw {
	my $self = shift;
	return $self->generateResponse('fail','','Who do you think you are?') unless $self->validateAdmin;	

	my $topicId = $self->{query}->param('topicId');
	return $self->generateResponse('fail','',"I think you're forgetting someting.") unless $topicId;


	my $nsfw = $self->{dbh}->selectrow_array("SELECT nsfw FROM profileTopic WHERE id = ?",undef,$topicId);
	$nsfw = !$nsfw || 0;
	$self->{dbh}->do("UPDATE profileTopic SET nsfw = ? WHERE id = ?",undef,$nsfw,$topicId);
	return $self->generateResponse('ok','',qq|<topic id="$topicId">$nsfw</topic>|);
}

sub qow_nsfw {
	my $self = shift;
	return $self->generateResponse('fail','','Who do you think you are?') unless $self->validateAdmin;	

	my $rid = $self->{query}->param('rid');
	my $uid = $self->{query}->param('userId');
	warn $self->generateResponse('fail','',"I think you're forgetting someting. ($rid,$uid)") unless $rid && $uid;
	return $self->generateResponse('fail','',"I think you're forgetting someting. ($rid,$uid)") unless $rid && $uid;


	my $nsfw = $self->{dbh}->selectrow_array("SELECT nsfw FROM questionresponse WHERE id = ? AND userId = ?",undef,$rid,$uid);
warn "OLD NSFW: $nsfw";
	$nsfw = !$nsfw || 0;
warn "NEW NSFW: $nsfw";
	$self->{dbh}->do("UPDATE questionresponse SET nsfw = ? WHERE id = ? AND userId = ?",undef,$nsfw,$rid,$uid);
	return $self->generateResponse('ok','',qq|<response id="$rid">$nsfw</response>|);
}

sub deleteUser {
	my $self = shift;
	return $self->generateResponse('fail','','Who do you think you are?') unless $self->validateAdmin;	

	my $userId = $self->{query}->param('userId');

	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userId);
	$U->updateField(status => -2);

	# purge the user cache
	warn "ADMIN DELETING USER $userId, $U->{profile}{status}";
	$self->{cache}->delete("userByName$U->{profile}{username}");
	$self->{cache}->delete("userById$userId");
	$self->{cache}->delete("Popularity$userId");
	$self->{cache}->delete("handleById$userId");

	return $self->generateResponse('ok','',"<ret>Deleted $userId</ret>");
}

sub notASpammer {
	my $self = shift;
	return $self->generateResponse('fail','','Who do you think you are?') unless $self->validateAdmin;	

	$self->{dbh}->do("DELETE FROM spamUser WHERE userId = ?",undef,$self->{query}->param('userId'));
	return $self->generateResponse('ok','',"<ret>done</ret>");
}

sub disqualifyPhoto {
	my $self = shift;
	return $self->generateResponse('fail','','Who do you think you are?') unless $self->validateAdmin;	

	my $uid = $self->{query}->param('userId') or return $self->generateResponse('fail','','Missing ID');

	# get the current contest ID and entry ID
	my ($cid,$tag) = $self->{dbh}->selectrow_array("SELECT id,tagname FROM photo_contest WHERE itson = 1 ORDER BY id DESC LIMIT 1");
	my $entryId = $self->{dbh}->selectrow_array("SELECT id FROM photo_contest_entry WHERE userId = ? AND contestId = ? ORDER BY id DESC LIMIT 1",undef,$uid,$cid);

	# count blings
	my $blings = $self->{dbh}->selectall_arrayref("SELECT type,COUNT(*) FROM photo_contest_bling WHERE contestId=$cid AND entryId=$entryId GROUP BY 1");
	warn("SELECT type,COUNT(*) FROM photo_contest_bling WHERE contestId=$cid AND entryId=$entryId GROUP BY 1");
	# update popularity
	my $diff = 0;
	for (@$blings) {
		if ($_->[0] eq 'U') {
			$diff -= ($_->[1] * 2);
		} elsif ($_->[0] eq 'D') {
			$diff += $_->[1];
		}
	}
	warn "ADJUST POPULARITY FOR $uid BY $diff";
	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid);
	$U->updateField('popularity',$U->{profile}->{popularity} + $diff);


	# remove entry and blings
	$self->{dbh}->do("DELETE FROM photo_contest_entry WHERE id = $entryId");
	$self->{dbh}->do("DELETE FROM photo_contest_bling WHERE contestId=$cid AND entryId=$entryId");

	# get tag ID
	$tag .= '_contest';
	my $tid = $self->{dbh}->selectrow_array("SELECT id FROM tag WHERE value = '$tag'");
	removeTag($self->{dbh},$tid,$uid);

	# send message
	$self->{query}->param('to',$uid);
	$self->{query}->param('from',9656);
	$self->{query}->param('message',<<MESSAGE);
Sorry! Your photo contest entry has been disqualified for violating the contest rules.  Rules are listed <a href="http://www.consumating.com/weekly/photo/index.pl/current">here</a> on the contest entry page.  Please try again!
MESSAGE
	my $zombie = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => 9656);
	$self->{user}{user} = $zombie->profile;
	messages::sendMessage($self);


	return $self->generateResponse('ok','','<ret>DQ</ret>');
}





1;
