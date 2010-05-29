package points;
use strict;
 
use Data::Dumper;
use POSIX qw(strftime);
use lib qw(. lib);
use util;
use Users;

sub new {
	my $class = shift;
	my %args = @_;

	my $self = {
		dbh 	=> $args{dbh},
		cache	=> $args{cache},
		util	=> util->new(dbh => $args{dbh}, cache => $args{cache}),
		system	=> {
			questionanswer 	=> { amount => 5, desc => "You answered a question of the week!" },
			photocontest	=> { amount => 5, desc => "You entered a photo contest!" },
			first5upload	=> { amount => 5, desc => "You've uploaded your first five photos!" },
			firstupload		=> { amount => 1, desc => "You've uploaded your first photo!" },
			goodinvite		=> { amount => 10, desc => "Someone you invited has joined Consumating!" },
			register		=> { amount => 60, desc => "Thanks for joining Consumating!" },
			thumbbomb		=> { amount => sub {$_[0] / 2}, desc => "You were thumbbombed! Here's some compensation." },
		},
	};

	bless $self, ref($class) || $class;

	return $self;
}

sub storeTransaction {
	my $self = shift;
	my $args = shift;

	# make sure they have a positive balance if they are spending points
	return if $args->{points} < 0 && $self->{util}->getPoints($args->{userid}) < 0;

	$args->{date} = strftime("%F %H:%M:%S",localtime);

	unless ($self->{storeTransaction}) {
		$self->{storeTransaction} = $self->{dbh}->prepare("INSERT INTO point_transaction (userid,points,type,description,date) VALUES (?,?,?,?,?)");
	}
	$self->{storeTransaction}->execute(map{$args->{$_}}qw(userid points type desc date));

	$args->{id} = $self->{dbh}->selectrow_array("SELECT last_insert_id()");


	$self->usercache($args->{userid}, $args);
	$self->typecache($args->{type}, $args);

	return $args->{id};
}

sub usercache {
	my $self = shift;
	my $userid = shift;
	my $args = shift;

	my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userid);
	#$User->updateField('popularity',$User->{profile}->{popularity}+$args->{points});
	
	my $user = $self->{cache}->get("usertransactions$userid");
	if ($args) {
		push @{$user->{$args->{type}}}, $args;
		$self->{cache}->set("usertransactions$userid",$user);
	}
	return $user;
}

sub typecache {
	my $self = shift;
	my $type = shift;
	my $args = shift;

	my $ref = $self->{cache}->get("typetransactions$type");
	if ($args) {
		push @{$ref->{$type}}, $args;
		$self->{cache}->set("typetransactions$type",$ref);
	}
	return $ref;
}

sub getTransactions {
	my $self = shift;
	my $args = shift;

	if ($args->{userid}) {
		my $user = $self->usercache($args->{userid});
		if ($args->{type}) {
			return $user->{$args->{type}};
		}
		return $user;
	}
	if ($args->{type}) {
		return $self->typecache($args->{type});
	}

	return;
}



1;
