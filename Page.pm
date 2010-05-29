package Page;

use strict;
 
use lib qw(. lib ../lib);
use util;
use Cache;

sub new {
	my ($class,%args) = @_;
	
	my $self = {%args};
	$self->{cache} ||= new Cache;
	$self->{util}  ||= new util(dbh => $self->{dbh},cache => $self->{cache});

	bless $self, ref($class) || $class;

	return $self;
}

1;
