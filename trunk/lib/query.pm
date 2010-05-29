package query;

use strict;
 
use URI::Escape;

sub new  {
	my $class = shift;
	my $req = shift;

	my $self = {
		req => $req
	};

	bless $self, ref($class)||$class;

	$self->init;

	return $self;
}

sub init {
	my $self = shift;

	# get query parameters
	my $a = $self->{req}->args;
	my @a = split /&/,$a;
	for my $pair (@a) {
		my ($k,$v) = split /=/,$pair;
		$v = uri_unescape($v);
		$v =~ s/\+/ /g;
		if ($self->{parms}{$k} && !ref $self->{parms}{$k}) {
			my $t = $self->{parms}{$k};
			delete $self->{parms}{$k};
			$self->{parms}{$k} = [$t,$v];
		} elsif (ref $self->{parms}{$k}) {
			push @{$self->{parms}{$k}}, $v;
		} else {
			$self->{parms}{$k} = $v;
		}
	}

	# get post parameters

	# get cookies
	my $c = $self->{req}->headers_in->{Cookie};
	my @c = split /; /,$c;
	for my $pair (@c) {
		my ($k,$v) = split /=/,$pair;
		$self->{cookies}{$k} = uri_unescape($v);
	}
}
sub cookie {
	my $self = shift;
	my $name = shift;

	return $self->{cookies}{$name};
}

sub param {
	my $self = shift;
	my $name = shift;

	if ($name) {
		return $self->{parms}{$name};
	} else {
		return (keys %{$self->{parms}});
	}
}



1;
