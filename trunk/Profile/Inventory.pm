package Profile::Inventory;

use strict;
use Page;
use Profile;

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;

	$self->prepare;
	$self->displayDefault;

	my $I = items->new($self->{cache},$self->{dbh},$self->{user}{profile}{userId});

	my $newid = $self->{query}->param('newtoy');
	for (sort {$a->{type} cmp $b->{type} || $a->{name} cmp $b->{name}} $I->pocketItems,$I->drawerItems) {
		if ($newid == $_->{id}) {
			$_->{new} = time();
		}
		push @{$self->{user}{itemlist}}, { item => $_ };
	}
	if (ref $self->{user}{itemlist} eq 'ARRAY') {
		$self->{user}{itembox}{height} = int(scalar(@{$self->{user}{itemlist}})/7) * 100;
		if (scalar(@{$self->{user}{itemlist}}) % 6 > 0) {
			$self->{user}{itembox}{height} += 100;
		}

		if (scalar(@{$self->{user}{itemlist}}) % 6 != 0) {
			for (1 .. 6-(scalar(@{$self->{user}{itemlist}}) % 6)) {
				push @{$self->{user}{blanks}}, {};
			}
		}
	} else {
		for (1 .. 6) {
			push @{$self->{user}{blanks}}, {};
		}
	}

	print $self->{P}->process('Profile/inventory.html');

	return (0);


}

1;
