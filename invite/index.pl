#!/usr/bin/perl

use lib qw(lib ../lib);
use strict;
 
use Profiles;
use template2;
use mail;
use invite;



{


	my $P = Profiles->new();
	$P->{user}{system}{tab} = "Invite";
	if (!$P->verify($P->{user})) {
		exit;
	} 

	if ($P->{command} eq "") {
		default($P);
	} elsif ($P->{command} eq "/send") {
		sendInvite($P);
	}


}


sub default {
	my ($P) = @_;

	if (my $tags = $P->{query}->param('tagsIn')) {
		for (1..5) {
			$P->{user}{form}{"tags$_"} = $tags;
		}
	}
	for (1..5) {
		if (my $t = $P->{query}->param("tags$_")) {
			$P->{user}{form}{"tags$_"} = $t;
		}
	}
	$P->{user}{form}{type} = $P->{query}->param('type')||'';
	$P->{user}{form}{typeId} = $P->{query}->param('typeId')||'';

    	$P->{user}{email}{verification} = $P->{util}->encrypt($P->{user}{user}{handle});
		print $P->Header();
		print processTemplate($P->{user},"invite/index.html");	

}

sub sendInvite {
	my ($P) = @_;

	$P->{user}{email}{verification} = $P->{util}->encrypt($P->{user}{user}{handle});

	foreach my $field (1..5) {
		if ((my $email = $P->{query}->param("email$field")) ne "") {
			my $tags = $P->{query}->param('tags' . $field);
			invite::processInvite($P,$email,$tags);
		}
	}

	print $P->Header();
	print processTemplate($P->{user},"invite/send.html");
}


