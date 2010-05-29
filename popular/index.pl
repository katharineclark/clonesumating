#!/usr/bin/perl

use strict;
 
use Time::HiRes qw(gettimeofday tv_interval);
use Date::Calc qw(Today);

use lib "../lib";
use template2;
use Profiles;
use CM_Tags;
use Users;
use teams;
use util;

my $P = Profiles->new();


$P->{user}{system}{tab} = "Popularity";


if ($P->{command} eq "") {

	if ($P->{user}{user}{id}) {

		$P->{user}{user}{zipcode} = $P->{user}{user}{country} unless ($P->{user}{user}{zipcode});

	# get user trend	

		my $sql = "SELECT * FROM popularityTrend WHERE userId=$P->{user}{user}{id} ORDER BY date DESC limit 1;";	
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;

		if (my $trend = $sth->fetchrow_hashref) {
			
			if ($trend->{popularity} < $P->{user}{user}{popularity}) {
				$P->{user}{trend}{type} = "up";
			} else {
				$P->{user}{trend}{type} = "down";
			}
		}
		$sth->finish;	

		# how many people above,
		# how many people below,
		# and how many people at the same level

		$sql = "SELECT count(1) FROM users WHERE popularity > $P->{user}{user}{popularity};";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$P->{user}{popularity}{higher} = $sth->fetchrow;
		$sth->finish;

		$sql = "SELECT count(1) FROM users WHERE popularity < $P->{user}{user}{popularity};";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$P->{user}{popularity}{lower} = $sth->fetchrow;
		$sth->finish;

		$sql = "SELECT count(1) FROM users WHERE popularity = $P->{user}{user}{popularity};";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$P->{user}{popularity}{same} = $sth->fetchrow;
		$sth->finish;


		$P->{user}{popularity}{total} =     $P->{user}{popularity}{higher} +     $P->{user}{popularity}{lower};
		$P->{user}{popularity}{belowpercent} = int(($P->{user}{popularity}{lower} / $P->{user}{popularity}{total}) * 588);
		$P->{user}{popularity}{abovepercent} = int(($P->{user}{popularity}{higher} / $P->{user}{popularity}{total}) * 588);


		$P->{user}{today}{range} =  sprintf("%04d%02d%02dT00:00:00",Today);

	}

	{
		my @tags;
		my $cmd = `cat /var/opt/httpd/8000/logs/prod_access_log|grep search.pl?tags=|cut -d\\  -f 7|cut -d= -f2|cut -d\\& -f1|tail`;
		for (split /\n/,$cmd) {
			chomp;
			push @tags, cleanTag($_);
		}
		my $sql = "SELECT profileId FROM tagRef r, tag t WHERE r.tagId = t.id AND t.value IN ('".join("','",@tags)."')";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		my $ids = $sth->fetchall_arrayref;
		$sth->finish;

		$sql = "SELECT id FROM users WHERE id IN (".join(',',map{$_->[0]}@$ids).") AND popularity < 1000 ORDER BY popularity DESC LIMIT 2";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		my $cnt=0;
		while (my $id = $sth->fetchrow) {
			my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
			$P->{user}{"searchedprofile".($cnt++)} = $U->profile;
			push @{$P->{user}{searched}}, {profile => $U->profile};
		}
		$P->{user}{searchedtags}{tags} = join(', ',map{qq|<a href="/tags/$_">$_</a>|}@tags);
		$sth->finish;
	}




	if (0) {
		# Load heart leaders
		my $sth = $P->{dbh}->prepare("SELECT i.ownerid,u.popularity,count(*) AS count FROM user_items i,users u WHERE u.id=i.ownerid AND i.ownerid!=i.creatorId AND u.sex=? AND i.previousOwnerId != 9656 AND i.ownerid NOT IN (2447,1) GROUP BY 1,2 ORDER BY 3 DESC,2 DESC LIMIT 5");
		for my $sex (qw(m f)) {  
			$sth->execute($sex);
			while (my $user = $sth->fetchrow_hashref) {
				my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $user->{ownerid}) or next;

				for (qw(handle photoId)) {
					$user->{$_} = $User->{profile}->{$_};
				}

				push @{$P->{user}{"heart$sex"}}, {profile => $user};
			}
		}
		$sth->finish;
	}


	# unused
	if (0) {
		# popular cities
		my $sql = "select city,state,country,sum(popularity) as citypop from users group by city order by citypop desc limit 10;";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $city = $sth->fetchrow_hashref) {

			push @{$P->{user}{popularCities}}, {city => $city};
		}
		$sth->finish;
	}

	# the IT boy / IT girl
	# most attention since they joined over the first week
	{
		my $sql = "SELECT id FROM users WHERE status=1 AND createDate > DATE_SUB(NOW(),INTERVAL 7 DAY) AND sex=? AND norank=0 ORDER BY popularity DESC LIMIT 1";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute('M');
		my $id = $sth->fetchrow;
		my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id);

		$P->{user}{itboy} = $User->profile;

		$sth->execute('F');
		$id = $sth->fetchrow;
		$User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id);

		$P->{user}{itgirl} = $User->profile;
		$sth->finish;
	}


	# most popular right now
	{
		my $sql = "SELECT id FROM users WHERE status=1 AND id NOT IN (1,2447) AND sex = ? and norank=0 ORDER BY todaypopularity DESC, popularity DESC LIMIT 10";

		my $sth = $P->{dbh}->prepare($sql);
		for my $sex (qw(m f)) {
			$sth->execute($sex);
			my $count = 0;
			while (my $id = $sth->fetchrow) {
				my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
				$count++;
				$User->{profile}->{place} = ($count) . Users::wordize($count);
				push @{$P->{user}{"popularnow$sex"}}, {profile => $User->profile};
			}
		}
		$sth->finish;
	}

	# most popular overall 
	{
		my $sql = "SELECT id FROM users WHERE status=1 AND sex=? AND id NOT IN (1,2447) and norank=0 ORDER BY popularity DESC LIMIT 10";

		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute('M');
		my $count = 0;
		while (my $id = $sth->fetchrow) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
			$count++;
			$User->{profile}->{place} = ($count) . Users::wordize($count);
			push @{$P->{user}{popularm}}, {profile => $User->profile};
		}
		$sth->execute('F');
		$count = 0;
		while (my $id = $sth->fetchrow) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
			$count++;
			$User->{profile}->{place} = ($count) . Users::wordize($count);
			push @{$P->{user}{popularf}}, {profile => $User->profile};
		}
		$sth->finish;
	}

	# most popular question answerers
	{
		my $sql = "SELECT id FROM users WHERE status=1 AND sex = ? AND norank=0 AND id NOT IN (1,2447) ORDER BY questionPopularity DESC, popularity DESC LIMIT 10";

		my $sth = $P->{dbh}->prepare($sql);
		for my $sex (qw(m f)) {
			$sth->execute($sex);
			my $count = 0;
			while (my $id = $sth->fetchrow) {
				my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
				$count++;
				$User->{profile}->{place} = ($count) . Users::wordize($count);
				push @{$P->{user}{"popularq$sex"}}, {profile => $User->profile};
			}
		}
		$sth->finish;
	}



	# most popular locally, boy/girl
	if ($P->{user}{user}{localQuery}) {

		# top 10 local
		my $sql = "SELECT id FROM users WHERE status=1 AND $P->{user}{user}{localQuery} AND norank=0 AND sex = ? AND id NOT IN (1,2447) ORDER BY popularity DESC LIMIT 15";

		my $sth = $P->{dbh}->prepare($sql);
		for my $sex (qw(m f)) {
			$sth->execute($sex);
			my $count = 0;
			while (my $id = $sth->fetchrow) {
				my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
				$count++;
				$User->{profile}->{place} = ($count) . Users::wordize($count);
				push @{$P->{user}{"popularlocal$sex"}}, {profile => $User->profile};
				last if $count == 10;
			}
		}
		$sth->finish;


		# unused right now
		if(0){ 
			# top local girl and boy
			$sql = "SELECT id FROM users WHERE status=1 AND sex=? AND $P->{user}{user}{localQuery} and norank=0 ORDER BY popularity DESC LIMIT 1";

			$sth = $P->{dbh}->prepare($sql);
			$sth->execute('M');
			my $id = $sth->fetchrow;
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id);
			$P->{user}{localboy} = $User->profile;

			$sth->execute('F');
			$id = $sth->fetchrow;
			$User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id);
			$P->{user}{localgirl} = $User->profile;

			$sth->finish;
		}

	}

	# popular teams, by team category/size
	{
		my $t0 = [gettimeofday];
		my $teams = teams->new(dbh => $P->{dbh}, cache => $P->{cache});
		
		my %types;
		my $lastsize = 0;
		my %seen = (0 => 1);

		for my $size (sort {$b <=> $a} keys %teams::sizes) {
			for ($teams->getTeams({where => "memberCount >= $size AND id NOT IN (".join(',',keys(%seen)).")", limit => 3}) ) {
				push @{$types{$size}}, { team => $_->data };
				$seen{$_->data('id')}=1;
				if ($_->data('ownerId') == $P->{user}{user}{id}) {
					push @{$P->{user}{ownedteams}}, { team => $_->data };
				} elsif ($_->isMember($P->{user}{user}{id})) {
					push @{$P->{user}{memberteams}}, { team => $_->data };
				}
			}
			$lastsize = $size;
		}
		$P->{user}{teamtypes} = [ map { teamtypes => { sizename => util::pluralize(undef,$teams::sizes{$_}) }, teams => $types{$_}  } => sort {$b <=> $a} keys %types ];

	}

	print $P->Header();
	print processTemplate($P->{user},"scoreboard/popular.html");
	$P->{dbh}->disconnect();

} elsif ($P->{command} eq "/by") { 

	my $s = $P->{query}->param('s');
	my $t = $P->{query}->param('tag');
	my $z = $P->{query}->param('zip');
	my $f = $P->{query}->param('field');
	my $d = $P->{query}->param('d') || 0;
	my $nf = $P->{query}->param('nf'); # nearer or further

	my @dists = qw(five ten twentyfive fifty);
	my %dists = qw(0 5 1 10 2 25 3 50);

	if ($t =~ /\d\d\d\d\d/) {
		$z = $t;
		$t = "";
		$P->{user}{form}{zip} = $z;
		$P->{user}{form}{tag} = "";
	}

	my $sth;
	if ($t ne "") {
		my $sql = "SELECT u.id FROM users u,tagRef r,tag t WHERE status=1 AND u.norank=0 AND u.id=r.profileId AND t.id = r.tagId AND t.value = ? ORDER BY popularity DESC LIMIT 10";

		$sth = $P->{dbh}->prepare($sql);
		$sth->execute($t);
		my $ids = $sth->fetchall_arrayref;


		my $sth = $P->{dbh}->prepare("SELECT popularity FROM users WHERE id = ?");
		my $count = 0;
		for my $id (map{$_->[1]} sort {$b->[0] <=> $a->[0]} map {[getPopularity->($_,$sth),$_->[0]]} @$ids) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
			$count++;
			$User->{profile}->{place} = ($count) . Users::wordize($count);
			push @{$P->{user}{popular}}, {profile => $User->profile};
			last if $count == 10;
		}
	} else {
		my $squery;
		if ($s ne '') {
			$squery = "AND sex = '$s'";
			$P->{user}{form}{sex} = $s eq 'm' ? 'boys' : 'girls';
		}
		if ($z ne "") {
			if ($z !~ /\d{5}/) {
				$sth = $P->{dbh}->prepare("SELECT id FROM users WHERE status=1 AND norank=0 and country = ? AND city = ? $squery ORDER BY popularity DESC LIMIT 10");
				$sth->execute($z,$P->{user}{user}{city});
				if ($sth->rows < 10) {
					$sth = $P->{dbh}->prepare("SELECT id FROM users WHERE status=1 AND norank=0 and country = ? $squery ORDER BY popularity DESC LIMIT 10");
					$sth->execute($z);
				}
			} else {
				do {
					$P->{user}{form}{pdist} = $d-1 > 0 ? $d-1 : 0;
					$P->{user}{form}{ndist} = $d+1 < $#dists ? $d+1 : $#dists;
					if ($nf eq 'n' && $d > 0) {
						$d--;
					} elsif ($nf eq 'f' && $d < $#dists) {
						$d++;
					}

					my $zips = $P->{cache}->get("zips$P->{user}{user}{zipcode}-$dists{$d}");
					unless ($zips) {
						my $sql = "SELECT $dists[$d] FROM zips where zip=?";
						my $getzips = $P->{dbh}->prepare($sql);
						$getzips->execute($z);
						$zips = $getzips->fetchrow;
						$getzips->finish;
						$P->{cache}->set("zips$P->{user}{user}{zipcode}-$dists{$d}",$zips);
					}

					my $sql = "SELECT id FROM users WHERE status=1 AND zipcode IN ($zips) $squery ORDER BY popularity DESC LIMIT 10";

					$sth = $P->{dbh}->prepare($sql);
					$sth->execute();

				} while ($sth->rows < 10 && $d++ < $#dists); 
			}

			for (0..$#dists) {
				%{$P->{user}{dists}{$_}{dist}} = (value => $_, word => $dists[$_], highlight => $d == $_ ? 1 : 0, zip => $P->{user}{form}{zip});
			}

		} elsif ($f ne "") {
			my $sql;
			if ($f eq "q") {
				$sql = "SELECT id FROM users WHERE status=1 $squery ORDER BY questionPopularity DESC LIMIT 10";
			} elsif ($f eq "t") {
				$sql = "SELECT id FROM users WHERE status=1 $squery ORDER BY todayPopularity DESC,popularity DESC LIMIT 10";
			}

			$sth = $P->{dbh}->prepare($sql);
			$sth->execute();
		}

		my $count = 0;
		while (my $id = $sth->fetchrow) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
			$count++;
			$User->{profile}->{place} = ($count) . Users::wordize($count);
			push @{$P->{user}{popular}}, {profile => $User->profile};
		}
		$sth->finish;
	}

	print $P->Header();
	print processTemplate($P->{user},"scoreboard/popularBy.html");

	$P->{dbh}->disconnect();
}

sub getPopularity {
	my $uid = shift;
	my $sth = shift;

	my $pop = $P->{cache}->get("Popularity$uid");
	unless ($pop) {
		$sth->execute($uid);
		$pop = $sth->fetchrow;
		$P->{cache}->set("Popularity$uid",$pop,3600);
	}
	return $pop;
}

