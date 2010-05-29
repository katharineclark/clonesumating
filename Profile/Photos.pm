package Profile::Photos;

use strict;
use Page;
use Profile;

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;

	$self->prepare;
	$self->displayDefault;
	$self->loadContests(9999999);


	print $self->{P}->process('Profile/photos.html');

	return (0);


}

1;
