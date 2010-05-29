package api::register;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use Users;

our @ISA = qw(api);

sub validate {
	my $self = shift;

	my ($badusername,$badhandle,@err);
	
	($badusername,@err) = $self->{util}->validateUser($self->{query});
	my $data = $self->badFields(@err) if scalar @err;
	$data .= "<usernameTaken><![CDATA[$badusername]]></usernameTaken>\n" if length $badusername;

	($badhandle,@err) = $self->{util}->validateProfile($self->{query});

	$data .= $self->badFields(@err) if scalar @err;
	$data .= "<handleTaken><![CDATA[$badhandle]]></handleTaken>\n" if length $badhandle;

	return length $data 
		? $self->generateResponse("ok","validateReturn","$data<validate>FAIL</validate>")
		: $self->generateResponse("ok","validateReturn","<validate>OK</validate>");
	
}

sub badFields {
	my $self = shift;

	return join "\n",map{"<badField>$_</badField>"} @_;
}

1;
