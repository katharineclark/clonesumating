package video;

use strict;


sub new {
	my $class = shift;

	my $self = {@_};
	bless $self, ref($class)||$class;
	$self->init;
	return $self;
}

1;
