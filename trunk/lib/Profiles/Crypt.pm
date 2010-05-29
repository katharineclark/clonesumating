package Profiles::Crypt;
use strict;
 
use Digest::MD5 qw(md5_hex);

our @encryption_key = qw(a 4 b N c 8 d A e r f l g 6 h t i o j c k h l V m P n f o k p U q G r x s b t F u 5 v u w X x W y p z y A 1 B g C q D L E a F v G k H 3 I n J Q K R L E M e N 9 O S P z Q 2 R m S 0 T D U w V i W M X j Y I Z O 0 T 1 s 2 C 3 Y 4 7 5 d 6 B 7 H 8 Z 9 J ! / _ ! / _);
our %encryption_codex = (
    in => {@encryption_key},
);

sub new {
	my $class = shift;
	my %args = @_;

	my $self = {
	};

	bless $self, ref($class) || $class;

	return $self;
}

sub _remap {
	my $self = shift;
	my $str = shift;

	my @c = split //, $str;
	for (@c) {
		$_ = $encryption_codex{'in'}{$_};
	}
	return join '',@c;
}

sub encrypt {
	my ($self,$str) = @_;
	my $handle = $self->_remap($str);

	my $t = time();
	my $f = join '', @c;
	return $t.'_'.md5_hex('csm17'.$t.$handle);
}
sub decrypt {
	my $self = shift;
	my $str = shift;
	my $t = substr($str,0,10);
	my $handle = _remap(+shift);
	my $test = $t.'_'.md5_hex('csm17'.$t.$handle);
	return $str eq $test;
}


1;
