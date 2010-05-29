package mail;
use strict;
 
use Data::Dumper;
use Mail::Send;

sub new {
	my $class = shift;
	my %args = @_;

	my $self = {%args};
	bless $self,ref($class)||$class;
	$self;
}

sub set {
	my $self = shift;
	my ($name,$value) = @_;
	$self->{$name} = $value;
}

sub send {
	my $self = shift;

	my $m = new Mail::Send;

 	$ENV{MAILADDRESS} = $self->{From};
	$m->set('From',$self->{From});
	$m->set('Content-Type',$self->{'Content-Type'}) if $self->{'Content-Type'};
	$m->subject($self->{subject});
	$m->to($self->{to});
	$m->add('X-sbi','consumate');
	$m->add('Envelope-Sender',$self->{From});
	
	my $fh = $m->open('smtp', Server => 'outbound.online.com');
	print $fh $self->{body};
	$fh->close();
}

1;
