package Users;

use strict;
 
use HTML::Entities;
use Data::Dumper;
use CGI::Carp qw(cluck);
use lib qw(. lib/ ../lib);
use Cache;

our @usersFields = qw(firstName lastName zipcode city state username password createDate lastLogin lastActive points sex birthDate partner country firstUpload popularity oldPopularity todayPopularity questionPopularity optout lastChat localQuery subLevel authkey peoplePref peoplePrefQuery trouble cell norank status);
our @profileFields = qw(userId handle tagline wantsMen wantsWomen relationship1 relationship2 relationship3 relationship4 relationship5 qowOrder auto_overheard auto_topics);

our $expiry = 60 * 60 * 5;

sub new {
	my $class= shift;
	my %args = @_;

	my $self = {
		profile 	=> undef,
		dbh			=> $args{dbh},
		memcache	=> $args{cache} || new Cache,
		args		=> \%args,
	};

	bless $self, ref($class) || $class;

	$args{force} = 1 if $ENV{'SERVER_NAME'} =~ /dev/;

	if ($args{username}) {
		return $self->loadFromLogin($args{username});
	} elsif ($args{userId}) {
		return $self->loadFromId($args{userId},$args{force});
	}

	return $self;
}

sub loadFromLogin {
	my $self = shift;
	my $name = shift;

	my $user = $self->{memcache}->get("userByName$name");

	if (ref $user eq 'HASH' && scalar keys %$user) {
		$self->{profile} = $user;
	} else {
		my $sql = "SELECT u.*,p.handle,p.tagline,p.wantsMen,p.wantsWomen,p.relationship1,p.relationship2,p.relationship3,p.relationship4,p.relationship5, "
				. "p.height,p.weight,p.subculture,p.modifyDate,p.relationshipStatus,p.views,p.tagPublicly,p.allowAnonymousTags, "
				. "h.id as primaryPhoto,h.id as photoId, u.id as userId,u.id as profileId,  "
				. "DATE_FORMAT(NOW(), '%Y') - DATE_FORMAT(birthDate, '%Y') - (DATE_FORMAT(NOW(), '00-%m-%d') < DATE_FORMAT(birthDate, '00-%m-%d')) AS age, "
				. "qowOrder, status, auto_overheard, auto_topics "
				. "FROM (users u INNER JOIN profiles p ON p.userId=u.id) LEFT JOIN photos h ON u.id=h.userId and h.rank=1 "
				. "WHERE  u.username = ? ";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute($name);
		if ($sth->rows) {
			$self->{profile} = $sth->fetchrow_hashref;

			$self->{memcache}->set("userByName$name",$self->{profile},$expiry);
			$self->{memcache}->set("userById$self->{profile}->{id}",$self->{profile},$expiry);
			$self->{memcache}->set("Popularity$self->{profile}->{id}",$self->{profile}->{popularity},$expiry);
			$self->{memcache}->set("handleById$self->{profile}->{id}",$self->{profile}->{handle},$expiry);

			$sth->finish;
		} else {
			$sth->finish;
			return;
		}
	}

	return undef if $self->{profile}->{status} == -2 && !$self->{args}{meeting};

	if ($self->{profile}{sex} eq "M") {
			$self->{profile}{pronoun} = "he";
			$self->{profile}{cpronoun} = "He";
			$self->{profile}{ppronoun} = "his";
            $self->{profile}{cppronoun} = "His";
			$self->{profile}{tpronoun} = "him";
	} else {
			$self->{profile}{pronoun} = "she";
			$self->{profile}{cpronoun} = "She";
            $self->{profile}{cppronoun} = "Her";
			$self->{profile}{ppronoun} = "her";
			$self->{profile}{tpronoun} = "her";
	}

	$self->{profile}->{userid} = $self->{profile}->{id};
	$self->{profile}->{linkhandle} = linkify($self->{profile}->{handle});
	($self->{profile}->{eschandle} = $self->{profile}->{handle}) =~ s/"/'/g;
	$self->{profile}->{eschandle} =~ s/&/&amp;/g;

	return $self;
}

sub loadFromId {
	my $self = shift;
	my $id = shift;
	my $force = shift;

	my $user = $self->{memcache}->get("userById$id");

	if ($force) {
		$self->{memcache}->delete("userByName$self->{profile}->{username}");
		$self->{memcache}->delete("userById$id");
		$self->{memcache}->delete("Popularity$id");
		$self->{memcache}->delete("handleById$id");
	}

	if (ref $user eq 'HASH' && !$force) {
		%{$self->{profile}} = %{$user};
	} else {


		my $sth = $self->{dbh}->prepare("SELECT u.*,p.handle,p.tagline,p.wantsMen,p.wantsWomen,p.relationship1,p.relationship2,p.relationship3,p.relationship4,p.relationship5, "
				. "p.height,p.weight,p.subculture,p.modifyDate,p.relationshipStatus,p.views,p.tagPublicly,p.allowAnonymousTags, "
				. "h.id as primaryPhoto, h.id as photoId, u.id as userId,u.id as profileId, "
				. "DATE_FORMAT(NOW(), '%Y') - DATE_FORMAT(birthDate, '%Y') - (DATE_FORMAT(NOW(), '00-%m-%d') < DATE_FORMAT(birthDate, '00-%m-%d')) AS age, "
				. "qowOrder, status, auto_overheard, auto_topics "
				. "FROM (users u INNER JOIN profiles p ON p.userId=u.id) LEFT JOIN photos h ON u.id=h.userId and h.rank=1 WHERE u.id=?");
		$sth->execute($id);
		if ($sth->rows) {
			$self->{profile} = $sth->fetchrow_hashref;


			$self->{memcache}->set("userByName$self->{profile}->{username}",$self->{profile},$expiry);
			$self->{memcache}->set("userById$id",$self->{profile},$expiry);
			$self->{memcache}->set("Popularity$id",$self->{profile}->{popularity},$expiry);
			$self->{memcache}->set("handleById$id",$self->{profile}->{handle},$expiry);

			$sth->finish;
		} else {
			$sth->finish;
			return;
		}
	}

	return undef if $self->{profile}->{status} == -2 && !$self->{args}{meeting};

	if ($self->{profile}{sex} eq "M") {
			$self->{profile}{pronoun} = "he";
			$self->{profile}{cpronoun} = "He";
			$self->{profile}{ppronoun} = "his";
            $self->{profile}{cppronoun} = "His";
			$self->{profile}{tpronoun} = "him";
	} else {
			$self->{profile}{pronoun} = "she";
			$self->{profile}{cpronoun} = "She";
            $self->{profile}{cppronoun} = "Her";
			$self->{profile}{ppronoun} = "her";
			$self->{profile}{tpronoun} = "her";
	}

	$self->{profile}->{userid} = $self->{profile}->{id};
	$self->{profile}->{linkhandle} = linkify($self->{profile}->{handle});
	($self->{profile}->{eschandle} = $self->{profile}->{handle}) =~ s/"/'/g;
	$self->{profile}->{eschandle} = HTML::Entities::encode_entities($self->{profile}->{eschandle},"'\200-\377");
	
	return $self;
}

sub save {
	my $self = shift;

	unless ($self->{profile}->{id}) {
		# insert and set the ID
		my $sql = "INSERT INTO users (".join(',',@usersFields).") VALUES (".join(',',map{'?'}@usersFields).")";
		my $ins = $self->{dbh}->prepare($sql);
		$ins->execute(map{$self->{profile}->{$_}}@usersFields) or cluck "INSERT users FAILED: ";

		my $sth = $self->{dbh}->prepare("SELECT last_insert_id()");
		$self->{profile}->{id} = $self->{profile}->{userId} = $self->{profile}->{profileId} = $sth->fetchrow;
		$sth->finish;
		$ins->finish;

		# insert profiles record
		$sql = "INSERT INTO profiles (".join(',',@profileFields).") VALUES (".join(',',map{'?'}@profileFields).")";
		$ins = $self->{dbh}->prepare($sql);
		$ins->execute(map{$self->{profile}->{$_}}@profileFields);
		$ins->finish;

		# clear the handle autocomplete for this user
		my $str;
		for (split //,$self->{profile}->{handle}) {
			$str.= $_;
			$self->{cache}->delete("autocompletehandles_$str");
		}
	} elsif ($self->{modified}) {
		if (grep {/$self->{modified}/} @usersFields) {
			my $sql = "UPDATE users SET $self->{modified} = ? WHERE id = ?";
			my $upd = $self->{dbh}->prepare($sql);
			$upd->execute($self->{profile}->{$self->{modified}},$self->{profile}->{id});
			$upd->finish;
		} else {
			my $sql = "UPDATE profiles SET $self->{modified} = ? WHERE userid = ?";
			my $upd = $self->{dbh}->prepare($sql);
			$upd->execute($self->{profile}->{$self->{modified}},$self->{profile}->{id});
			$upd->finish;
		}
		if ($self->{modified} eq 'handle') {
			# clear the handle autocomplete for the new handle
			my $str;
			for (split //,$self->{profile}->{handle}) {
				$str.= $_;
				$self->{cache}->delete("autocompletehandles_$str");
			}
		}
		delete $self->{modified};
	} else {
		return;
	}
		

	$self->{memcache}->set("userByName$self->{profile}->{username},$self->{profile}->{password}",$self->{profile},900);
	$self->{memcache}->set("userById$self->{profile}->{id}",$self->{profile},900);


	return $self;
}

sub updateField {
	my $self = shift;
	my ($field,$value) = @_;

	if ($field eq 'handle') {
		# clear the handle autocomplete for the old handle
		my $str;
		for (split //,$self->{profile}->{handle}) {
			$str.= $_;
			$self->{cache}->delete("autocompletehandles_$str");
		}
	}
	$self->{profile}->{$field} = $value;
	if ($field eq 'photoId') {
		$self->{profile}{primaryPhoto} = $value;
		return $self;
	}

	$self->{modified} = $field;

	$self->save;

	return $self;
}

sub profile {
	my $self = shift;

	return $self->{profile};
}

sub rank {
	my $self = shift;

	if ($self->{profile}{norank}) {
		return ['unranked',''];
	}

	my $rank = $self->{memcache}->get("Rank$self->{profile}->{id}");
	unless (0 && ref $rank =~ /ARRAY/ && scalar @$rank) {
#warn "POP $self->{profile}->{popularity} RANK $rank->[0]";
		# figure out popularity
		if ($self->{profile}->{popularity} eq "") {
			$self->{profile}->{popularity} = -100;
		}
		my $sql = "SELECT count(1) FROM users WHERE status != -2 AND norank=0 AND popularity > $self->{profile}->{popularity};";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		$rank = $sth->fetchrow;
		$sth->finish;
		$self->{profile}->{rank} = ($rank + 1);
		$self->{profile}->{rankword} = wordize($rank + 1);

		$self->{memcache}->set("Rank$self->{profile}->{id}",[$self->{profile}->{rank},$self->{profile}->{rankword}],60*60);
	} else {
		$self->{profile}->{rank} = $rank->[0];
		$self->{profile}->{rankword} = $rank->[1];
	}
	return [$self->{profile}->{rank},$self->{profile}->{rankword}];
}

sub linkify {
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


sub wordize {
	my ($number) = @_;
	if( $number =~ /11$/ || $number =~ /12$/ || $number =~ /13$/) {
		return "th";
	}elsif ($number =~ /1$/) {
		return "st";
	} elsif ($number =~ /2$/) {
		return "nd"; 
	} elsif ($number =~ /3$/) {
		return "rd";
	} else {
		return "th";	
	}
}

sub getBlocklist {
	my $self = shift;
	my $userId = shift;

	my $blocks = $self->{memcache}->get("block".$self->{profile}{userId}."-$userId");
	unless ($blocks) {
		$blocks = [];
		unless ($self->{blockSTH}) {
			$self->{blockSTH} = $self->{dbh}->prepare("SELECT type FROM blocklist WHERE profileId = ? AND userId = ?");
		}
		$self->{blockSTH}->execute($self->{profile}{userId},$userId);
		while (my $t = $self->{blockSTH}->fetchrow) {
			push @{$blocks}, $t;
		}
		$self->{memcache}->set("block".$self->{profile}{userId}."-$userId",$blocks);
	}
	return $blocks;
}

1;
