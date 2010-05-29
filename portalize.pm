package portalize;

use strict;
 
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);


use lib qw(lib ../lib);
use Profiles;
use template2;

our $dbh;
our $cache = new Cache;

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $dbActive = ref $dbh && $dbh->ping;

	my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
	unless ($P->{user}{user}{id}) {
		warn "portalize show login";
		print $P->process('portalize/login.html',1);
		return 0;
	}

	my $self = { 
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> CGI->new($r),
	};
	bless $self, ref($class) || $class;

	$self->{command} = $P->{command};

	return $self->doPortal($dbActive);
}


1;
