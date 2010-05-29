package tags;
use strict;
 
use Data::Dumper;

sub new {
	my $class = shift;
	my $memcache = shift;
	my $db = shift;
	my ($type,$set) = @_;

die "MISSING REQUIRED THINGS!" unless $memcache && $db;

	my $self = {
		db => $db,
		cache => $memcache,
		master => undef,
		tags => undef,
		tagIds => undef,
		profiles => undef,
	};
	bless $self, ref($class) || $class;

	$self->loadSet($type,$set);

#	$self->load();

	$self;
}

sub loadSet {
	my $self = shift;
	my $type = shift || '';
	my $set = shift || '';
	$self->{$type}{$set} = $self->{cache}->get("GlobalTagRef_$type$set");
	unless (ref $self->{$type}{$set} eq 'HASH') {
		delete $self->{$type}{$set};
		return undef;
	} else {
		return $self->{$type}{$set};
	}
}

# don't call this unless you want to reload the entire index at once!!!
# it is VERY memory intensive and should not be used in CGI scripts!!!
# if you need help, ask Josh.Goldberg@cnet.com
sub load {
	my $self = shift;
	my $fromDb = shift;

	
	my $sets = $self->{cache}->get("GlobalTagRef_masterSets");
	for (@$sets) {
		$self->{master}{$_} = $self->{cache}->get("GlobalTagRef_master$_");
	}
	$sets = $self->{cache}->get("GlobalTagRef_tagsSets");
	for (@$sets) {
		$self->{tags}{$_} = $self->{cache}->get("GlobalTagRef_tags$_");
	}
	$sets = $self->{cache}->get("GlobalTagRef_tagIdsSets");
	for (@$sets) {
		$self->{tagIds}{$_} = $self->{cache}->get("GlobalTagRef_tagIds$_");
	}
	$sets = $self->{cache}->get("GlobalTagRef_profilesSets");
	for (@$sets) {
		$self->{profiles}{$_} = $self->{cache}->get("GlobalTagRef_profiles$_");
	}

	if ($fromDb || !keys %{$self->{master}} || !keys %{$self->{tags}} || !keys %{$self->{profiles}}) {
		delete $self->{master};
		delete $self->{tags};
		delete $self->{profiles};
		my $sth = $self->{db}->prepare("SELECT r.profileId,r.tagId,r.source,r.addedById,r.dateAdded,r.id,r.facetId,r.anonymous,t.value FROM tagRef r,tag t WHERE t.id = r.tagId AND t.value != ''");
		$sth->execute;
		while (my $t = $sth->fetchrow_hashref) {
			$self->addRow($t);
		}
		$sth->finish;
		my @sets;
		for my $set (keys %{$self->{master}}) {
			push @sets, $set;
			$self->{cache}->set("GlobalTagRef_master$set",$self->{master}{$set}) || warn "Can't set master cache $set!";
		}
		$self->{cache}->set('GlobalTagRef_masterSets',\@sets) || warn "Can't set master sets!";
		@sets=();
		for my $set (keys %{$self->{tags}}) {
			push @sets, $set;
			$self->{cache}->set("GlobalTagRef_tags$set",$self->{tags}{$set}) || warn "Can't set tags cache $set!";
		}
		$self->{cache}->set('GlobalTagRef_tagsSets',\@sets) || warn "Can't set tag sets!";
		@sets=();
		for my $set (keys %{$self->{tagIds}}) {
			push @sets, $set;
			$self->{cache}->set("GlobalTagRef_tagIds$set",$self->{tagIds}{$set}) || warn "Can't set tagIds cache $set!";
		}
		$self->{cache}->set('GlobalTagRef_tagIdsSets',\@sets) || warn "Can't set tagIds sets!";
		@sets=();
		for my $set (keys %{$self->{profiles}}) {
			push @sets, $set;
			$self->{cache}->set("GlobalTagRef_profiles$set",$self->{profiles}{$set}) || warn "Can't set profiles cache $set!";
		}
		$self->{cache}->set('GlobalTagRef_profilesSets',\@sets) || warn "Can't set tag sets!";
		
	}

}
sub save {
	my $self = shift;
	my $type = shift;
	my $set = shift;

	$self->{cache}->set("GlobalTagRef_$type$set",$self->{$type}{$set}) || warn "Can't set $type cache $set!";
}

sub getProfiles {
	my $self = shift;
	my $uids = shift;
	my $all  = shift;


	my @ret;

	my @notfound;
	for my $userId (@$uids) {
		$self->loadSet('profiles',int($userId/10)) unless defined $self->{profiles}{int($userId/10)} && ref($self->{profiles}{int($userId/10)}) =~ /ARRAY/ && scalar @{$self->{profiles}{int($userId/10)}};

		unless (defined $self->{profiles}{int($userId/10)}{$userId} and scalar @{$self->{profiles}{int($userId/10)}{$userId}}) {
			push @notfound, $userId;
		} else {
			push @ret, $self->{profiles}{int($userId/10)}{$userId};
		}
	}

	if (scalar @notfound) {
		my $sql = "SELECT r.profileId,r.tagId,r.source,r.addedById,r.dateAdded,r.id,r.facetId,r.anonymous,t.value FROM tagRef r,tag t WHERE t.id = r.tagId AND r.profileId IN (".join(',',@notfound).")";
#warn "SEARCH $sql;";

		my $sth = $self->{db}->prepare($sql);
		$sth->execute;
		while (my $t = $sth->fetchrow_hashref) {
			$self->addRow($t);
			$self->save('tags',substr($t->{value},0,2));
		}
		$sth->finish;
		for (@notfound) {
			push @ret, $self->{profiles}{int($_/10)}{$_};
			$self->save('master',int($_/10));
			$self->save('profiles',int($_/10));
		}
	}
	return @ret;
}
		

sub getProfile {
	my $self = shift;
	my $userId = shift;


	$self->loadSet('profiles',int($userId/10)) unless defined $self->{profiles}{int($userId/10)} && ref($self->{profiles}{int($userId/10)}) =~ /ARRAY/ && scalar @{$self->{profiles}{int($userId/10)}};

	unless (defined $self->{profiles}{int($userId/10)}{$userId} and scalar @{$self->{profiles}{int($userId/10)}{$userId}}) {
		unless ($self->{getProfileSTH}) {
			$self->{getProfileSTH} = $self->{db}->prepare("SELECT r.profileId,r.tagId,r.source,r.addedById,r.dateAdded,r.id,r.facetId,r.anonymous,t.value FROM tagRef r,tag t WHERE t.id = r.tagId AND r.profileId=?");
		}
		$self->{getProfileSTH}->execute($userId);
		while (my $t = $self->{getProfileSTH}->fetchrow_hashref) {
			$self->addRow($t);
			$self->save('tags',substr($t->{value},0,2));
		}
	}
	$self->save('master',int($userId/10));
	$self->save('profiles',int($userId/10));

	open F,">foo";print F Dumper( $self->{profiles}{int($userId/10)}{$userId});close F;
	return $self->{profiles}{int($userId/10)}{$userId};
}
sub getTag {
	my $self = shift;
	my $tag = shift;

	my $set = substr($tag,0,2);

	$self->loadSet('profiles',$set) unless $self->{tags}{$set};
	unless ($self->{tags}{$set}) {
		my $sth = $self->{db}->prepare("SELECT r.profileId,r.tagId,r.source,r.addedById,r.dateAdded,r.id,r.facetId,r.anonymous,t.value FROM tagRef r,tag t WHERE t.id = r.tagId AND t.value LIKE '$set%'");
		$sth->execute;
		while (my $t = $sth->fetchrow_hashref) {
			$self->addRow($t);
			$self->save('tags',substr($t->{value},0,2));
		}
		$sth->finish;
	}

	return $self->{tags}{substr $tag,0,2}{$tag};
}

sub getTags {
	my $self = shift;
	my $tags = shift;

	my @ret;
	for (@$tags) {
		push @ret, $self->getTag($_);
	}

	return @ret;
}


sub getTagref {
	my $self = shift;

	my $set = int $_[0]/10;

	$self->loadSet('master',$set) unless $self->{master}{$set};

	unless (defined $self->{master}{$set}{join('-',@_)} and scalar keys %{$self->{master}{$set}{join('-',@_)}}) {
#warn "DB LOOKUP Tagref: $_[0], $_[1]";
		my $sth = $self->{db}->prepare("SELECT r.profileId,r.tagId,r.source,r.addedById,r.dateAdded,r.id,r.facetId,r.anonymous,t.value FROM tagRef r,tag t WHERE t.id = r.tagId AND r.profileId=?");
		$sth->execute($_[0]);
		while (my $t = $sth->fetchrow_hashref) {
			$self->addRow($t);
		}
		$sth->finish;
	}

	return $self->{master}{$set}{join('-',@_)};
}

sub removeTagrefById {
	my $self = shift;
	my ($userId,$tagId) = @_;

	$self->loadSet('master',int($userId/10));
	my $ref = $self->{master}{int $userId/10}{"$userId-$tagId"};
	unless (defined $ref) {
		$ref = $self->getTagref($userId,$tagId);
	}

	unless (defined $ref) {
		# we have to find the value to kill it from the cache
		# this should not happen very often
		my $sth = $self->{db}->prepare("SELECT value FROM tag WHERE id = ?");
		$sth->execute($tagId);
		$ref->{value} = $sth->fetchrow;
		$sth->finish;
	}


	# clear tags
	my $sub = substr($ref->{value},0,2);
	$self->loadSet('tags',$sub);
	for my $idx (0 .. $#{$self->{tags}{$sub}{$ref->{value}}}) {
		if ($self->{tags}{$sub}{$ref->{value}}[$idx] eq $userId) {
#warn "CLEARING TAGS ($idx)".Dumper($self->{tags}{$sub}{$ref->{value}}[$idx]);
			splice @{$self->{tags}{$sub}{$ref->{value}}},$idx,1;
			last;
		}
	}
	$self->save('tags',$sub);

	# clear profiles
	$sub = int $userId/10;
	$self->loadSet('profiles',$sub);
	for my $idx (0 .. $#{$self->{profiles}{$sub}{$userId}}) {
		if ($self->{profiles}{$sub}{$userId}[$idx] eq $ref->{value}) {
#warn "CLEARING PROFILES ($idx)".Dumper($self->{profiles}{$sub}{$userId}[$idx]);
			splice @{$self->{profiles}{$sub}{$userId}},$idx,1;
			last;
		}
	}
	$self->save('profiles',$sub);

	# clear master
	$self->loadSet('master',$sub);
#warn "MASTER: ".Dumper($self->{master}{$sub}{$userId.'-'.$tagId});
	delete $self->{master}{$sub}{$userId.'-'.$ref->{value}};
	delete $self->{master}{$sub}{"$userId-$tagId"};
	$self->save('master',$sub);
}

sub add {
	my $self = shift;
	my $userId = shift;
	my $tagId = shift;

	my $sth = $self->{db}->prepare("SELECT r.profileId,r.tagId,r.source,r.addedById,r.dateAdded,r.id,r.facetId,r.anonymous,t.value FROM tagRef r,tag t WHERE t.id = r.tagId AND r.profileId=?");
	$sth->execute($userId);
	while (my $t = $sth->fetchrow_hashref) {
		$self->addRow($t);
		$self->save('tags',substr($t->{value},0,2));
	}
	$sth->finish;
	$self->save('master',int($userId/10));
	$self->save('profiles',int($userId/10));
}

sub addRow {
	my $self = shift;
	my $t = shift;

	my $pid = int($t->{profileId}/10);

#warn "CACHE Adding $t->{value} ($t->{tagId}) to profile $t->{profileId}";
	$self->{master}{$pid}{$t->{profileId}.'-'.$t->{value}} = \%{$t};
	$self->{master}{$pid}{$t->{profileId}.'-'.$t->{tagId}} = \%{$t};

	push @{$self->{tags}{substr($t->{value},0,2)}{$t->{value}}}, $t->{profileId};
	$self->{tagIds}{int $t->{tagId}/10}{$t->{tagId}} = $t->{value};
	push @{$self->{profiles}{$pid}{$t->{profileId}}}, $t->{value};
}

1;
