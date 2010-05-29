package blings;

use strict;
 
use Data::Dumper;

our $maxDownRate = 10;  # seconds / downbling.  60 would be one down per minute.
our $maxRateSample = 600; # 10 minutes is the max time to examine.

sub new {
	my $class = shift;
	my %args = @_;

	my $self = {
		dbh => $args{dbh},
		cache => $args{cache},
	};
	bless $self, ref($class) || $class;

	return $self;
}

sub getResponseBlings {
	my $self = shift;
	my $id = shift;

	my $blings = $self->{cache}->get("ResponseBlings$id");
	unless (0 && $blings) {
		$blings = undef;
		unless ($self->{responseBlingsSth}) {
			$self->{responseBlingsSth} = $self->{dbh}->prepare("SELECT *,unix_timestamp(insertDate) AS timestamp FROM bling WHERE questionresponseId = ?");
		}
		$self->{responseBlingsSth}->execute($id);
		while (my $bling = $self->{responseBlingsSth}->fetchrow_hashref) {
			$blings->{$bling->{userId}} = $bling;
		}
		$self->{cache}->set("ResponseBlings$id",$blings);
	}
	return $blings;
}

sub getBling {
	my $self = shift;
	my $responseId = shift;
	my $userId = shift;

	my $blings = $self->getResponseBlings($responseId);
	return $blings->{$userId};
}

sub addBling {
	my $self = shift;
	my %args = @_;

	my $blings = $self->getResponseBlings($args{questionresponseId});

	my @now = $self->getNow;
	$args{insertDate} = $now[0];
	$args{timestamp} = $now[1];

	$blings->{$args{userId}} = {map {$_ => $args{$_}}qw(userId questionresponseId type insertDate timestamp)};

	$self->{cache}->set("ResponseBlings$args{questionresponseId}",$blings) or return 0;

	$self->{dbh}->do("INSERT INTO bling (userId,questionresponseId,type,insertDate) VALUES (?,?,?,?)",undef,map{$args{$_}}qw(userId questionresponseId type insertDate)) or return 0;

	my $userId = $self->{dbh}->selectrow_array("SELECT userId FROM questionresponse WHERE id = ?",undef,$args{questionresponseId});

	my $User = Users->new(dbh => $self->{dbh},cache => $self->{cache},userId => $userId) or return;
	if ($args{type} eq 'D') {
		$User->updateField('popularity',$User->{profile}->{popularity}-1) or warn "FAILED TO UPDATE POPULARITY: $userId pop - 1";
	} else {
		$User->updateField('popularity',$User->{profile}->{popularity}+2) or warn "FAILED TO UPDATE POPULARITY: $userId pop + 2";
	}
		
}

sub getNow {
	my $self = shift;
	unless ($self->{nowsth}) {
		$self->{nowsth} = $self->{dbh}->prepare("SELECT NOW(),UNIX_TIMESTAMP(NOW()) AS timestamp");
	}
	$self->{nowsth}->execute;
	return ($self->{nowsth}->fetchrow);
}

sub updateBling {
	my $self = shift;
	my %args = @_;

	my $blings = $self->getResponseBlings($args{questionresponseId});
	if (ref $blings->{$args{userId}}) {
		my $oldtype = $blings->{$args{userId}}->{type};
		$blings->{$args{userId}}->{type} = $args{type};

		my ($insD,$ts) = $self->getNow;
		$args{insertDate} = $blings->{$args{userId}}->{insertDate} = $insD;
		$blings->{$args{userId}}->{timestamp} = $ts;

		$self->{cache}->set("ResponseBlings$args{questionresponseId}",$blings) or return 0;
		$self->{dbh}->do("UPDATE bling SET type = ?, insertDate = ? WHERE userId = ? AND questionresponseId = ?",undef,map{$args{$_}}qw(type insertDate userId questionresponseId)) or return 0;

		if ($oldtype ne $args{type}) {
			my $userId = $self->{dbh}->selectrow_array("SELECT userId FROM questionresponse WHERE id = ?",undef,$args{questionresponseId});
			my $User = Users->new(dbh => $self->{dbh},cache => $self->{cache},userId => $userId) or return;
			if ($args{type} eq 'D') {
warn "UPDATE $args{questionresponseId} BLING $userId: -3";
				$User->updateField('popularity',$User->{profile}->{popularity}-3) or warn "FAILED TO UPDATE POPULARITY: $userId pop - 3";
			} else {
warn "UPDATE BLING $userId: +3";
				$User->updateField('popularity',$User->{profile}->{popularity}+3) or warn "FAILED TO UPDATE POPULARITY: $userId pop + 3";
			}
		} else {
warn "NO UPDATE BLING $args{userId}, QRID $args{questionresponseId}";
		}
		return 1;
	} else {
		return $self->addBling(%args);
	}
}

sub checkAbuse {
	my $self = shift;
	my $uid = shift;
	my $qruid = shift;

	my $lastbling = $self->{cache}->get("blingrate$uid"."_$qruid");
	my $t = time();
	$self->{cache}->set("blingrate$uid"."_$qruid",$t);
	my $rate = abs($t-$lastbling) / 2;
warn "RATE: $rate";
	if ($rate < $blings::maxDownRate) {
		warn "$uid IS PAST THE DOWN RATE FOR $qruid!!!!";
		return 1;
	}

	return 0;
}

1;
