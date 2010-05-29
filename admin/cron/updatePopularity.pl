#!/usr/bin/perl
$|++;

use strict;

 
use DBI;
use lib "../../lib";
use CONFIG;

my $datasource = "DBI:mysql:$dbName:$dbServer";



my $dbh = DBI->connect($datasource, $dbUser, $dbPass) || die "$!";


my $sql = "UPDATE users SET todayPopularity=0,oldPopularity=popularity;";
$dbh->do($sql);
	

$sql = "SELECT users.id,popularity FROM users,profiles WHERE users.id=profiles.userId order by users.id";

my $sth = $dbh->prepare($sql);
$sth->execute;

my $thumbs = $dbh->prepare("SELECT COUNT(*) FROM thumb WHERE type=? AND profileId=?");
my $blings = $dbh->prepare("SELECT COUNT(*) FROM bling b,questionresponse r WHERE b.questionresponseId=r.id AND b.type=? AND r.userId=?");
my $photos = $dbh->prepare("SELECT COUNT(*) FROM photo_contest_bling b, photo_contest_entry e WHERE b.entryId=e.id AND b.type=? AND e.userId=?");

my $today = $dbh->prepare("SELECT COUNT(*) FROM thumb WHERE type=? AND profileId=? AND insertDate BETWEEN DATE_SUB(NOW(),INTERVAL 1 DAY) AND NOW()");
my $penalty = $dbh->prepare("SELECT (DATEDIFF(lastLogin,DATE_SUB(NOW(),INTERVAL 1 MONTH))/7) AS penalty FROM users WHERE id=?");

my $update = $dbh->prepare("UPDATE users SET popularity=?,todayPopularity=? WHERE id=?");
my $trend = $dbh->prepare("INSERT INTO popularityTrend (userId,popularity,date) VALUES (?,?,NOW())");

while (my ($userId,$oldpop) = $sth->fetchrow_array) {
	#warn "doing $userId";

	# get thumbs up count

	$thumbs->execute('U',$userId);
	my $up = $thumbs->fetchrow;
	
	$thumbs->execute('D',$userId);
	my $down = $thumbs->fetchrow;

	$blings->execute('U',$userId);
	my $bling = $blings->fetchrow;

	$blings->execute('D',$userId);
	my $blingd = $blings->fetchrow;

	$photos->execute('U',$userId);
	my $photobling = $photos->fetchrow;

	$photos->execute('D',$userId);
	my $photoblingd = $photos->fetchrow || 0;

	my ($reviewU,$reviewD);
	if (0) {
			my $sql = "select count(1) from rating where userId=$userId and  type='Y';";
			my $stx = $dbh->prepare($sql);
			$stx->execute;
			$reviewU = $stx->fetchrow || 0;
			$stx->finish;

			$sql = "select count(1) from rating where userId=$userId and  type='N';";
			$stx = $dbh->prepare($sql);
			$stx->execute;
			$reviewD = $stx->fetchrow || 0;
			$stx->finish;
	} else {
		$reviewU = $reviewD = 0;
	}



	my $popularity = (($up+$bling+$photobling+$reviewU) * 2) - ($down + $blingd + $photoblingd + $reviewD);
	if ($userId == 2447) {
		print "UP $up, BLING $bling, PHBLING $photobling, REV $reviewU ".(($up+$bling+$photobling+$reviewU) * 2)."\n";
		print "DN $down, BLING $blingd, PHBLING $photoblingd, REV $reviewD ".($down + $blingd + $photoblingd + $reviewD)."\n";
		print "POP $popularity\n";
	}


	$today->execute('U',$userId);
	my $todayUp = $today->fetchrow;
	$today->execute('D',$userId);
	my $todayDown = $today->fetchrow;

	my $todayPop = ($todayUp * 2) - $todayDown;

	if ($userId == 8) {
		$todayPop = 0;
		$popularity -= 100;
	}
	if ($userId == 616) {
		$todayPop = 0;
		$popularity -= 100;
	}
	if ($userId == 5841) {
		$popularity += 50;
	}
	if ($userId == 12304) {
		$popularity = 250;
	}



# penalize those who have not logged into the site in ages.
	$penalty->execute($userId);
	my $inactivityPenalty = $penalty->fetchrow;

	if ($inactivityPenalty < 0) {
		$popularity = $popularity + $inactivityPenalty;
	}

	$update->execute($popularity,$todayPop,$userId);

	if ($popularity != $oldpop && $oldpop != "") {
		$trend->execute($userId,$oldpop);
	}


}




