package apiInterface;

use strict;
use lib qw(. lib);
 
use Class::Inspector;
use Apache2::Const qw(REDIRECT OK);
use CGI;

use Profiles;
use CM_Tags;
use template;
use util;
use api;
use api::system;
use api::user;
use api::popularity;
use api::topic;
use api::autocomplete;
use api::register;
use api::photos;
use api::ticker;
use api::item;
use api::messages;
use api::teamtopic;
use api::tags;
use api::updates;
use api::team;
use api::meetings;
use api::meetingtopic;
use api::admin;
use api::photocontest;
use api::peeps;


sub handler :method {
	my $class = shift;
	my $r = shift;

	my $P = Profiles->new(request => $r);

	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh 	=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
	};

	bless $self, ref($class) || $class;

	my $q = CGI->new($self->{req});

	my ($subclass,$method) = split /\./, 'api::'.$q->param('method');

	for (keys %ENV) {
		#warn "ENV: $_ => $ENV{$_}";
	}

	$self->{req}->content_type('text/xml');
	$self->{req}->headers_out->add('Cache-Control' => 'no-cache, must-revalidate');
	$self->{req}->headers_out->add('Pragma' => 'no-cache');

	if (Class::Inspector->loaded($subclass)) {
		my $API = $subclass->new(
			dbh 		=> $self->{dbh}, 
			req 		=> $self->{req},
			user 		=> $self->{user}, 
			cache		=> $self->{cache},
			query 		=> $q, 
			actingUser 	=> $self->{user}{user}{id}, 
		);

		if ($API->can($method)) {
			print $API->$method;
		} else {
			print $API->generateResponse('fail','',"Who do you think you're trying to kid?");
		}
	} else {
		print api::generateResponse('fail','',"Who do you think you're trying to kid?");
	}

	return 0;
}



1;
