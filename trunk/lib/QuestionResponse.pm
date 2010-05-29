package QuestionResponse;

use strict;
 
use Data::Dumper;

sub new {
	my $class = shift;
	my %args = @_;

	my $self = {
		profile => undef,
		dbh => $args{dbh} ,
		memcache => $args{cache},
		force => $args{force},
	};

	bless $self, ref($class) || $class;

	if ($args{questionId} && $args{userId}) {
		return $self->loadFromQuestionId($args{questionId},$args{userId});
	} elsif ($args{responseId}) {
		return $self->loadFromId($args{responseId});
	}

	return $self
}

sub loadFromQuestionId {
	my $self = shift;
	my $questionId = shift;
	my $userId = shift;

	my $r = $self->{memcache}->get("responseByQid$questionId,$userId");
	if (1 && $r && !$self->{force}) {
		$self->{response} = $r;
	} else {
		unless ($self->{qidSth}) {
			$self->{qidSth} = $self->{dbh}->prepare("SELECT *,UNIX_TIMESTAMP(date) AS timestamp FROM questionresponse WHERE questionId = ? AND userId = ?");
		}
		$self->{qidSth}->execute($questionId,$userId);

		if ($self->{qidSth}->rows) {
			$self->{response} = $self->{qidSth}->fetchrow_hashref;

			$self->save;
		} else {
			return;
		}
	}

	return $self;
}

sub loadFromId {
	my $self = shift;
	my $qrid = shift;

	my $r = $self->{memcache}->get("responseById$qrid");
	if (1 && $r && !$self->{force}) {
		$self->{response} = $r;
	} else {
		unless ($self->{idSth}) {
			$self->{idSth} = $self->{dbh}->prepare("SELECT *,UNIX_TIMESTAMP(date) AS timestamp FROM questionresponse WHERE id = ?");
		}
		$self->{idSth}->execute($qrid);

		if ($self->{idSth}->rows) {
			$self->{response} = $self->{idSth}->fetchrow_hashref;

			$self->save;
		} else {
			return;
		}
	}

	return $self;
}

sub getUserEntries {
	my $self = shift;
	my $userId = shift;
	my $entries = $self->{memcache}->get("userResponses$userId") || {};
	if (!scalar keys %$entries || $self->{force}) {
		my $sth = $self->{dbh}->prepare("SELECT id,UNIX_TIMESTAMP(date) FROM questionresponse WHERE userId = ?");
		$sth->execute($userId);
		$entries = {};
		while (my ($id,$timestamp) = $sth->fetchrow) {
			$entries->{$id} = $timestamp;
		}
		$self->{memcache}->set("userResponses$userId",$entries);
	}
	return $entries;
}
	
sub getByUser {
	my $self = shift;
	my $userId = shift;

	my $entries = $self->getUserEntries($userId);
	my @list = map {"responseById$_"} keys %$entries;
	my %responses = $self->{memcache}->get_multi(@list);

	for my $e (keys %$entries) {
		unless (scalar keys %{$responses{$_}}) {
			my $QR = $self->loadFromId($e);
			$responses{"responseById$e"} = $QR->response;
		}
	}

	return \%responses;
}

sub response {
	$_[0]->{response};
}

sub save {
	my $self = shift;

	$self->{memcache}->set("responseByQid$self->{response}->{questionId},$self->{response}->{userId}",$self->{response});
	$self->{memcache}->set("responseById$self->{response}->{id}",$self->{response});
	my $entries = $self->{memcache}->get("userResponses$self->{response}->{userId}");
	$entries->{$self->{response}->{id}} = $self->{response}->{timestamp};
	$self->{memcache}->set("userResponses$self->{response}->{userId}",$entries);
}

sub delete {
	my $self = shift;
	$self->{memcache}->delete("responseByQid$self->{response}->{questionId},$self->{response}->{userId}");
	$self->{memcache}->delete("responseById$self->{response}->{id}");
	my $entries = $self->{memcache}->get("userResponses$self->{response}->{userId}");
	delete $entries->{$self->{response}->{id}};
	$self->{memcache}->set("userResponses$self->{response}->{userId}",$entries);

	$self->{dbh}->do("DELETE FROM questionresponse WHERE id = ? AND userId = ?",undef,$self->{response}->{id},$self->{response}->{userId});
	delete $self->{response};
}

sub updatePhoto {
	my $self = shift;
	my $photoId = shift;

	return unless $self->{response};

	$self->{dbh}->do("UPDATE questionresponse SET photoId = ? WHERE id = ?",undef,$photoId,$self->{response}->{id});

	$self->{response}->{photoId} = $photoId;

	$self->save;
}
sub updatevideo {
	my $self = shift;
	my $videoId = shift;

	return unless $self->{response};

	$self->{dbh}->do("UPDATE questionresponse SET videoId = ? WHERE id = ?",undef,$videoId,$self->{response}->{id});

	$self->{response}->{videoId} = $videoId;

	$self->save;
}

sub updateAnswer {
	my $self = shift;
	my $answer = shift;

	return unless $self->{response};

	$self->{dbh}->do("UPDATE questionresponse SET answer = ? WHERE id = ?",undef,$answer,$self->{response}->{id});

	$self->{response}->{answer} = $answer;
	
	$self->save;
}


1;
