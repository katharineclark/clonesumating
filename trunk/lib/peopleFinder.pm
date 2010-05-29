package peopleFinder;

use strict;
use lib qw(. ../lib lib);
use tagmatch;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);

our $imult = 1.5;
our $hmult = 0.9;
our $amult = 1.1;
our $cosTh = 0.04;

our ($dbh,$blings,$blingcount,$thumbs,$thumbcount,$tags,$idLookup,$userLookup,$userInit,$handleLookupSTH,$memcache);

sub new {
	my $class = shift;
	my %args = @_;

	$dbh = $args{dbh};
	$memcache = $args{cache};

	my $self = {
		userId 	=> undef,
		user	=> undef,
	};

	bless $self, ref($class) || $class;

	$self->init;
	return $self;
}

sub init {
	my $self = shift;

	$blings = $dbh->prepare("SELECT questionresponseId FROM bling WHERE type = ? AND userId = ?");
	$blingcount = $dbh->prepare("SELECT COUNT(*) FROM bling WHERE type = ? AND userId = ?");
	$thumbs = $dbh->prepare("SELECT profileId FROM thumb WHERE type = ? AND userId = ?");
	$thumbcount = $dbh->prepare("SELECT count(*) FROM thumb WHERE userId=?");
	$tags = $dbh->prepare("SELECT value FROM tag t,tagRef r WHERE t.id=r.tagId AND r.profileId = ? AND r.source = 'O'");
	$idLookup = $dbh->prepare("SELECT userId FROM profiles WHERE handle = ?");
	$userLookup = $dbh->prepare("SELECT handle,profiles.userid as userId,photos.id as photoId FROM profiles inner join users on profiles.userId=users.id left join photos on profiles.userid=photos.userId and photos.rank=1 WHERE profiles.userid=? AND  users.createDate > DATE_SUB(NOW(),interval 30 day) ");

	$userInit = $dbh->prepare("SELECT u.*,p.handle,h.id AS primaryPhoto FROM (users u LEFT JOIN photos h ON u.id=h.userId AND h.rank=1) INNER JOIN profiles p ON u.id = p.userId WHERE u.id = ?");
}

sub loadUser {
	my ($self,$userId) = @_;

	$userInit->execute($userId);

	unless ($userInit->rows) {
		return undef;
	}

	$self->{user} = $userInit->fetchrow_hashref;
	$self->{userId} = $userId;
	$self->{user}->{linkhandle} = linkify($self->{user}->{handle});

	return $self;
}

sub search {
	my $self = shift;

	my $t0 = [gettimeofday];

	my $recommended;
	%{$recommended} = 
		map {$_->[0] => {humor => $_->[1]} } 
		$self->getHumorUsers($self->{user}->{id}, $self->getResponseIds('U',$self->{user}->{id}) );
	$t0 = [gettimeofday];

	my %peopleidolike 	 = map {$_ => 1} $self->getThumbs('U',$self->{user}->{id});
	my %peopleidonotlike = map {$_ => 1} $self->getThumbs('D',$self->{user}->{id});
	$t0 = [gettimeofday];

	my $recommenders = $self->getRecommenders($self->{user}->{id},\%peopleidolike,\%peopleidonotlike);
	$t0 = [gettimeofday];

	$self->getRecommended($recommenders,$recommended);
	$t0 = [gettimeofday];
	$self->getSharedTags($self->{user}->{id},$recommended);
	$t0 = [gettimeofday];
	$self->normalizeAttraction($recommended);
	$t0 = [gettimeofday];
	$self->ageDistanceDiff($self->{user}->{birthDate},$self->{user}->{localQuery},$recommended);
	$t0 = [gettimeofday];
	my $stats = $self->calcWeights($recommended,\%peopleidolike,\%peopleidonotlike);
	$t0 = [gettimeofday];
	my $people = $self->loadPeople($recommended,\%peopleidolike,\%peopleidonotlike);
	$t0 = [gettimeofday];

	return ($people,$stats);
}

sub getResponseIds {
	my $self = shift;
	my ($type,$userId) = @_;

	$blings->execute($type,$userId);

	my $res = $blings->fetchall_arrayref;

	return map {$_->[0]} @$res;
}

sub getHumorUsers {
	my $self = shift;
	my ($userId,@userLikes) = @_;

	local $"=',';
	my $sth = $dbh->prepare("SELECT userId,COUNT(*) FROM bling WHERE questionresponseId IN (@userLikes) AND type='U' AND userId != $userId GROUP BY 1 ORDER BY 2 DESC");
	$sth->execute;

	my @users;
	while (my @r = $sth->fetchrow) {
		$blingcount->execute('U',$r[0]);
		push @users, [$r[0],senseOfHumorPoints(scalar(@userLikes),$r[1],$blingcount->fetchrow)];
	}
	$sth->finish;

	return \@users;
}

sub getThumbs {
	my $self = shift;
	my ($type,$userId) = @_;

	$thumbs->execute($type,$userId);
	return map {$_->[0]} @{$thumbs->fetchall_arrayref};
}

sub getRecommenders {
	my $self = shift;
	my ($userId,$ilike,$reject) = @_;

	my $recommenders;

	my $sth = $dbh->prepare("SELECT userId,profileId,type FROM thumb WHERE profileId IN (".join(',',keys %$ilike,keys %$reject).") AND userId != $userId");
	$sth->execute;

	while (my ($uid,$pid,$type) = $sth->fetchrow) {
		if ( ($type eq 'U' && $ilike->{$pid} == 1) || ($type eq 'D' && $reject->{$pid} == 1) ) {
			$$recommenders{$uid}{agree}++;
		} else {
			$$recommenders{$uid}{disagree}++;
		}
	}
	$sth->finish;

	for my $uid (keys %$recommenders) {
		$thumbcount->execute($uid);
		my $tot = $thumbcount->fetchrow;

		if ($tot < 10) {
			delete $$recommenders{$uid};
			next;
		}

		$$recommenders{$uid}{agreepercent} = int(($$recommenders{$uid}{agree} / $tot) * 100);
		$$recommenders{$uid}{disagreepercent} = int(($$recommenders{$uid}{disagree} / $tot) * 100);

		#warn "$uid has $$recommenders{$uid}{agree} agrees and $$recommenders{$uid}{disagree} disagrees out of a total $tot votes";
		#warn "agrees $$recommenders{$uid}{agreepercent}%, disagrees $$recommenders{$uid}{disagreepercent}%";

	}

	my $count = 0;
	for my $uid (sort { $$recommenders{$b}{agreepercent} <=> $$recommenders{$a}{agreepercent} || $$recommenders{$a}{disagreepercent} <=> $$recommenders{$b}{disagreepercent} } keys %$recommenders) {
		if ($count++ > 10) { 
			# we only want to use the top ten
			delete $$recommenders{$uid};
			next;
		}
			
		$$recommenders{$uid}{taste} = $$recommenders{$uid}{agreepercent};

	}

	return $recommenders;
}

sub getRecommended {
	my $self = shift;
	my ($recommenders,$recommended) = @_;

	my $sth = $dbh->prepare("SELECT profileId,userId FROM thumb t INNER JOIN users u ON u.id=t.profileId WHERE userId IN (".join(',',keys(%$recommenders)).") AND type = 'U'");
	$sth->execute;

	while (my ($uid,$sid) = $sth->fetchrow) {
		$$recommended{$uid}{attraction} += int($$recommenders{$sid}{taste} * 100);
	}
	$sth->finish;
}

sub getSharedTags {
	my $self = shift;
	my ($userId,$recommended) = @_;

	$tags->execute($userId);

	my $taglist = $tags->fetchall_arrayref();

	my $sql = "SELECT DISTINCT p.userId,COUNT(*) AS count FROM tag t, tagRef r, profiles p WHERE r.tagId = t.id "
			. "AND t.value IN (\'".join("','",map{$_->[0]}@$taglist)."') AND r.profileId=p.userId GROUP BY 1 ORDER BY 2 DESC";
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	while (my ($uid,$weight) = $sth->fetchrow) {
		$$recommended{$uid}{interests} = $self->senseOfHumorPoints(scalar(@$taglist), $weight);
	}
	$sth->finish;


	# tag vector search
	my $matcher = new tagmatch;

	my $res;
	if (!$memcache->get("tagmatch$userId")) {
		$res = $matcher->searchUser(getHandle($userId));
		$memcache->set("tagmatch$userId",$res,43200);
	} else {
		$res = $memcache->get("tagmatch$userId");
	}

	for (@$res) {
		my ($handle,$cos) = @$_;
		next unless $cos > $cosTh;

		$idLookup->execute($handle);
		my $id = $idLookup->fetchrow;

		$$recommended{$id}{interests} += int($cos * 100);
	}
}

sub normalizeAttraction {
	my $self = shift;
	my $recommended = shift;

	my $max;
	foreach my $uid (sort {$$recommended{$b}{attraction} <=> $$recommended{$a}{attraction}} keys %$recommended) {
		$max = $$recommended{$uid}{attraction};
		last;
	}

	foreach my $uid (keys %$recommended) {
		$$recommended{$uid}{attraction} = int(($$recommended{$uid}{attraction} / $max) * 100);
	}
}

sub ageDistanceDiff {
	my $self = shift;
	my ($birthDate,$localQuery,$recommended) = @_;

	# localQuery is SLOWWWWWW!!!
	#my $ageloc = $dbh->prepare("SELECT ABS(DATEDIFF($birthDate,users.birthDate) / 365) as yearspan,$localQuery as islocal FROM users WHERE id=?");
	my $ageloc = $dbh->prepare("SELECT ABS(DATEDIFF(?,users.birthDate) / 365) as yearspan  FROM users WHERE id=?");

	for (keys %$recommended) {
		$ageloc->execute($birthDate,$_);
		$$recommended{$_}{agediff} = $ageloc->fetchrow;

	#	($$recommended{$_}{agediff},$$recommended{$_}{islocal}) = $ageloc->fetchrow;
	}
	$ageloc->finish;
}

sub calcWeights {
	my $self = shift;
	my ($rec,$ilike,$reject) = @_;

	my ($succ,$fail);

	for (keys %$rec) {
		$$rec{$_}{weight} = ($$rec{$_}{interests} * $imult) + ($$rec{$_}{humor} * $hmult) + ($$rec{$_}{attraction} * $amult);

		if ($$rec{$_}{weight} < 10) { delete $$rec{$_};next; }

		$$rec{$_}{weight} += 15 if $$rec{$_}{islocal} == 1;

		$$rec{$_}{weight} -= (3 * $$rec{$_}{agediff});

		$succ++ if $$ilike{$_};
		$fail++ if $$reject{$_};
	}

	my %stats = (
		totalpool 	=> scalar(keys %$rec),
		meter		=> $succ,
		success		=> ($succ/scalar(keys %$rec))*100,
		failmeter	=> $fail,
		fail		=> ($fail/scalar(keys %$rec))*100,
	);
		
	return \%stats;
}
			
sub loadPeople {
	my $self = shift;
	my ($rec,$ilike,$rejects) = @_;

	my $count = 0;
	my %ret;

	for (sort { $$rec{$b}{weight} <=> $$rec{$a}{weight} } keys %$rec) {
		next if $$ilike{$_} || $$rejects{$_};

		$userLookup->execute($_);
		next unless $userLookup->rows;

		my $u = $userLookup->fetchrow_hashref;
		$u->{interests} = $$rec{$_}{interests};
		$u->{humor} = $$rec{$_}{humor};
		$u->{attraction} = $$rec{$_}{attraction};
		$u->{weight} = $$rec{$_}{weight};

		$ret{$count++}{profile} = $u;

		last if $count > 40;
	}

	return \%ret;
}






sub senseOfHumorPoints {
	my $self = shift;
	my ($total,$matches,$usertot) = @_;

	my $percent;

	if ($matches < 5) { return 0; }
	if ($usertot) {
		$percent = (($matches / $usertot) * 100);
		#warn "$matches / $usertot = $percent";
	} else {
		$percent = (($matches / $total) * 100);
	}
	if ($percent == 100) {
		return 0;
	}
	return int($percent);

}

sub tastePoints {
	my $self = shift;
	my ($total,$matches,$usertotal) = @_;
# assign authority based on # of people you like in common
# however, factor in the % of votes this actually is for each user...

	if ($matches < 5) { return 0; }

	# THIS IS PROBLEMATIC BECAUSE PEOPLE WITH ONLY 1 OR 2 VOTES GET HUGE MATCHES.
	# NEED  TO TWEAK SO LOW # OF $usertotal DOESN'T SKEW EVERYTHING
	#if ($usertotal < $total) {
	#	$total = $usertotal;
	#}

	# if my percentage is way higher, then the recommendations might be too broad
        # if my total dataset is very low, broader recommendations are useful for training and increasing data set

	# if their percentage is way higher, they are a subset of me and are probably useful
	
	my $percent = $matches / $usertotal;
#	if ($percent < 0.5) { return 0; }
	if ($percent > 0.8) { $percent += 0.25; }
        warn "$matches matches vs $usertotal = $percent";

	return $percent;


}

sub linkify {
	my ($word) = @_;
	$word =~ s/_/\_us\_/gsm;
	$word =~ s/\s/\_/gsm;
	$word =~ s/&/\_amp\_/gsm;
	$word =~ s/\//\_fs\_/gsm;
	$word =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
	return $word;
}

sub getHandle {
	my $userId = shift;

	my $handle = $memcache->get("handleById$userId");
	unless ($handle) {
		unless ($handleLookupSTH) {
			$handleLookupSTH = $dbh->prepare("SELECT handle FROM profiles WHERE userId = ?");
		}
		$handleLookupSTH->execute($userId);
		$handle = $handleLookupSTH->fetchrow;
		$memcache->set("handleById$userId",$handle);
	}
	return $handle;
}

1;
