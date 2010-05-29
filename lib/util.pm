package util;

use strict;
use lib qw(lib ../lib .);
 
use Digest::MD5 qw(md5_hex);
use HTML::Detoxifier qw(detoxify);

sub new {
	my $class = shift;
	my %args = @_;

	my $self = { 
		dbh		=> $args{dbh},
		cache 	=> $args{cache},
	};

	bless $self,ref($class)||$class;

	$self;
}

sub timesince {
	my $self = shift;
	my ($minutes) = @_;
	my $str = '';
	if ($minutes > 60) {
		my $hours = $minutes / 60;                
		$minutes = $minutes % 60;
		if ($hours > 24) {
			my $days = $hours / 24;
			$hours = $hours % 24;
			$str = int($days) . " day";
			if (int($days) != 1) {
				$str.="s";
			}
		} else {
			$str =int($hours) . " hour";
			if (int($hours) != 1) {
				$str.="s";
			}
		}
	} else {
		$str = int($minutes) . " minute";
		if (int($minutes) != 1) {
			$str.="s";
		}
	}
	return $str;
}


sub countrySelect {

	my $self = shift;
	my $mycountry = shift;

    my ($sth,$c,$res) = "";

    $sth = $self->{dbh}->prepare("SELECT iso,printable_name FROM country ORDER BY printable_name");
    $sth->execute;
    while ($c = $sth->fetchrow_hashref) {

        if ($c->{iso} eq $mycountry) {
            $res .= qq|<option value="$$c{iso}" selected>$$c{printable_name}</option>\n|;
        } else {
                        $res .= qq|<option value="$$c{iso}">$$c{printable_name}</option>\n|;
                }

    }

    return $res;

}


sub getHandle {
	my $self = shift;
	my $userId = shift;
	my $hashref = shift;

	my $handle = undef;$self->{cache}->get("handleById$userId");
	if (!$handle || $handle eq '<i>missing profile</i>') {
		unless ($self->{handleLookupSTH}) {
			$self->{handleLookupSTH} = $self->{dbh}->prepare("SELECT handle FROM profiles WHERE userId = ?");
		}
		$self->{handleLookupSTH}->execute($userId);
		$handle = $self->{handleLookupSTH}->fetchrow || '<i>missing profile</i>';
		$self->{cache}->set("handleById$userId",$handle);
	}
	if (ref $hashref eq 'HASH') {
		$hashref->{handle} = $handle;
		$hashref->{linkhandle} = linkify($handle);
		return;
	}
	return wantarray ? ($handle,linkify($handle)) : $handle;
}
sub getUserId {
	my $self = shift;
	my $handle = shift;

	my $id = $self->{cache}->get("idByHandle".linkify($handle));
	if (!$id) {
		unless ($self->{userIdLookupSTH}) {
			$self->{userIdLookupSTH} = $self->{dbh}->prepare("SELECT userId FROM profiles WHERE handle = ?");
		}
		$self->{userIdLookupSTH}->execute($handle);
		$id = $self->{userIdLookupSTH}->fetchrow || undef;
		$self->{cache}->set("idByHandle".linkify($handle),$id);
	}
	return $id;
}

sub getPoints {
	my $self = shift;
	my $userId = shift;

	my $points = $self->{cache}->get("Popularity$userId");
	if (!$points) {
		unless ($self->{pointsLookupSTH}) {
			$self->{pointsLookupSTH} = $self->{dbh}->prepare("SELECT popularity FROM users WHERE id = ?");
		}
		$self->{pointsLookupSTH}->execute($userId);
		$points = $self->{pointsLookupSTH}->fetchrow;
		$self->{cache}->set("points$userId",$points);
	}
	return $points;
}


sub parseSearchString {
	my $self = shift;
	my $str = shift;

	my (@p,$tmp,@f);

	for my $w (split / /,$str) {
		if (length $tmp) {
			if ($w =~ /"$/) {
				$tmp .= " $w";
				$tmp =~ y/"//d;
				push @f, $tmp;
				$tmp = '';
			}
		} elsif ($w =~ /^"/) {
			$tmp = $w;
		} else {
			push @f, $w;
		}
	}
	return \@f;
}

sub linkify {
	my $self = shift if ref $_[0];
	my ($word) = @_;
	$word =~ s/_/_us_/g;
	$word =~ s/\?/_qm_/g;
	$word =~ s/\s/_/g;
	$word =~ s/&/_amp_/g;
	$word =~ s/;/_sc_/g;
	$word =~ s/#/_lb_/g;
	$word =~ s/\//_fs_/g;
	$word =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
	return $word;
}
sub delinkify {
	my $self = shift;
	my $word = shift;

	$word =~ s/_qm_/?/g;
	$word =~ s/_amp_/\&/g;
	$word =~ s/_lb_/#/g;
	$word =~ s/_sc_/;/g;
	$word =~ s/_fs_/\//g;
	$word =~ s/_us_/#%#%#/g;
	$word =~ s/_/ /g;
	$word =~ s/#%#%#/_/g;
	return $word;
}

# this is a class method, i.e. util::cleanHtml($foo); not $util->cleanHtml($foo);
sub cleanHtml(\$;@) {
	my $str = shift;

	$$str = detoxify($$str, disallow => [qw(dynamic document comments images annoying forms ),@_]);
	return $$str;
}


our @encryption_key = qw(a 4 b N c 8 d A e r f l g 6 h t i o j c k h l V m P n f o k p U q G r x s b t F u 5 v u w X x W y p z y A 1 B g C q D L E a F v G k H 3 I n J Q K R L E M e N 9 O S P z Q 2 R m S 0 T D U w V i W M X j Y I Z O 0 T 1 s 2 C 3 Y 4 7 5 d 6 B 7 H 8 Z 9 J ! / _ ! / _);
our %encryption_codex = (
    in => {@encryption_key},
);
sub _remap {
	my $self = shift;
    my $str = shift;
    my @c = split //,$str;
    for (@c) {
        $_ = $encryption_codex{'in'}{$_};
    }
    return join '',@c;
}
sub encrypt {
	my $self = shift;
    my $str = shift;
    my $handle = $self->_remap($str);
    my $t = time();
    return $t.'_'.md5_hex('csm17'.$t.$handle);
}
sub decrypt {
	my $self = shift;
    my $str = shift;
    my $t = substr($str,0,10);
    my $handle = $self->_remap(+shift);
    my $test = $t.'_'.md5_hex('csm17'.$t.$handle);
    return $str eq $test;
}
sub shortenString {
	my $self = shift if ref $_[0];
	my ($headline,$length) = @_;

	return undef unless defined $headline && length $headline;

	return $headline if $headline =~ /^\s+$/;

    if (length($headline) > $length) {

        my @words = split(/\s+/,$headline);
        my $newstr = '';
        my $count = 0;
        do {
            $newstr .= " " . $words[$count++];
            $newstr =~ s/^\s//gsm;
        } while (length($newstr) < $length);
        $newstr .= "...";
        return $newstr;
    } else {
        return $headline;
    }
}

sub validateUser {
	my $self = shift;
	my $q = shift;
	# check user table values
	my %form = map {$_ => $q->param($_)||''}qw(firstName lastName username password sex year month day optout);
	$form{birthDate} = join '-',@form{qw(year month day)};
	$form{optout} ||= 'N';

	if ($q->param('country') eq 'US') {
		$form{$_} = $q->param($_) for (qw(city state zipcode));
	} else {
		$form{city} = $q->param('foreigncity');
		delete $form{zipcode};
		delete $form{state};
	}
	my @err = grep {!length $form{$_}} keys %form;

	if (length $form{zipcode} && !($form{zipcode} =~ /\d{5}/)) {
		push @err, 'zipcode';
	}
	if (length $form{state} > 2) {
		push @err, 'state';
	}


	my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM users WHERE status != -2 AND username = ?");
	my $badusername = undef;
	$sth->execute($form{username});
	if ($sth->fetchrow > 0) {
		$badusername = $form{username};
	}
	$sth->finish;

	if (!$badusername && length $form{username} && !Email::Valid->address($form{username})) {
		$badusername = $form{username};
	}

	return ($badusername,@err);
}

sub validateProfile {
	my $self = shift;
	my $q = shift;
	# check profile table values
	my %form = map {$_ => $q->param($_)||''}qw(handle tagline relationshipStatus);
	for (qw(wantsMen wantsWomen relationship1 relationship2 relationship3 relationship4 relationship5)) {
		$form{$_} = $q->param($_) || 0;
	}

	my @err = grep{!length $form{$_}} keys %form;

	my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM profiles WHERE handle = ?");
	$sth->execute($form{handle});
	my $badhandle = undef;
	if ($sth->fetchrow > 0) {
		$badhandle = $form{handle};
	}
	$sth->finish;

	return ($badhandle,@err);

}

sub pluralize {
	my $self = shift;
	my $word = shift;

	return $word =~ /(.+)y$/ 
		? "$1ies" 
		: $word =~ /(.+)s$/
			? "$1es" : $word.'s';
}

sub singularize {
	my $self = shift;
	my $word = shift;

	if ($word =~ /^(a|e|i|o|u)/) {
		return "an $word";
	} else {
		return "a $word";
	}
}
1;
