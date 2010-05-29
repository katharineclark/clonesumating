package Alerts;

use strict;
 
use lib qw(. lib);
use template2;
use Users;
use mail;

sub new {
	my $class = shift;
	my %args = @_;

	return unless $args{dbh} && $args{cache} && $args{userId};

	my $self = {
		dbh => $args{dbh},
		cache => $args{cache},
		userId => $args{userId}
	};
	bless $self,ref($class)||$class;

	$self->init;

	return $self;
}

sub init {
	my $self = shift;
	my $sth = $self->{dbh}->prepare("SELECT description,name,id FROM alertTypes");
	$sth->execute;
	while (my $at = $sth->fetchrow_hashref) {
		$self->{subs}{$at->{id}}{alert} = $at;
		$self->{types}{$at->{name}} = $at->{id};
	}
	
	$sth = $self->{dbh}->prepare("SELECT alertId,target FROM alertSubscriptions WHERE userId = ?");
	$sth->execute($self->{userId});
	my ($id,$type);
	$sth->bind_columns(\$id,\$type);
	while ($sth->fetchrow_arrayref) {
		$self->{subs}{$id}{alert}{subscribed} = 1;
		$self->{subs}{$id}{alert}{target} = $type;
	}
}

sub getSubs {
	my $self = shift;
	return $self->{subs};
}

sub getSubByName {
	my $self = shift;
	my $name = shift;

	return $self->{subs}{$self->{types}{$name}}{alert};
}

sub setSubs {
	my $self = shift;
	my $alerts = shift;

	$self->{dbh}->do("DELETE FROM alertSubscriptions WHERE userId = $self->{userId}");

	for my $id (keys %{$self->{subs}}) {
		$self->{subs}{$id}{alert}{subscribed} = 0;
	}

	my $sth = $self->{dbh}->prepare("INSERT INTO alertSubscriptions (userId,alertId,target) VALUES ($self->{userId},?,?)");
	for (keys %$alerts) {
		my $id = $self->{types}{$_};
		$self->{subs}{$id}{alert}{subscribed} = 1;
		$sth->execute($id,$alerts->{$_});
	}
}

sub checkSub {
	my $self = shift;
	my $name = shift;

	return $self->{subs}{$self->{types}{$name}}{alert}{subscribed};

	return 0;
}

sub send {
	my $self = shift;
	my $name = shift;
	my $hash = shift;


	if ($self->checkSub($name)) {
		my $msg = new mail;

		my $sub = $self->getSubByName($name);
		
		if ($sub->{target} eq 'both' || $sub->{target} eq 'cell') {
			if ($hash->{user}{cell} =~ /^\d+$/ && !$hash->{user}{skipCellAuth}) { 
				authenticate($hash->{user}{cell}); 
			} else {
				$msg->set("From",'sms@sms.consumating.com');
				$msg->set("subject",processTemplate($hash,"alerts/$name.subject.mobile.txt",1));
				$msg->set("body",processTemplate($hash,"alerts/$name.mobile.txt",1));
				$msg->set("to",$hash->{user}{cell});
				$msg->send();
			}
		} 
		if ($sub->{target} eq 'both' || $sub->{target} eq 'email') {
			$msg->set("From",'notepasser@notepasser.consumating.com');
			$msg->set("subject",processTemplate($hash,"alerts/$name.subject.txt",1));
			$msg->set("body",processTemplate($hash,"alerts/$name.txt",1));
			$msg->set("to",$hash->{user}{username});
			$msg->send();
		}

	}
}

sub authenticate {
	my $cell = shift;
	my $msg = new mail;
	$msg->set("From",'sms@sms.consumating.com');
	$msg->set("subject",'Verify your txt number');
	$msg->set('body',qq|Hi! rply 2 ths msg w/ ur cell# 2 verify Consumating.com!|);
	warn "Authenticating $cell";
	$msg->set('to',$cell.'@teleflip.com');
	$msg->send();

	return 1;
}
1;
