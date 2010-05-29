package Profile::Answers;

use strict;
use Page;
use Profile;

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;

	$self->prepare;
	$self->displayDefault;
	$self->loadQuestions(9999999);

	print $self->{P}->process('Profile/answers.html');

	return (0);
}


1;
