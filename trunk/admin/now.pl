#!/usr/bin/perl

use lib qw(../lib lib);
 
use template;
use profilesmodperl qw($q $memcache $dbh %user loadUser);
use CGI;
use DBI;
use CONFIG;


$datasource = "DBI:mysql:$dbName:$dbServer";

%user = loadUser();

sub OpenDB() {

    $dbh = DBI->connect($datasource, $dbUser, $dbPass) ||  ErrorOut("Uh oh!  We're having trouble connecting to the database. Please
 try again in a few moments.");

    return( $dbh );
};

sub linkify {
        my ($word) = @_;
        $word =~ s/\s/\_/gsm;
        $word =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
        return $word;
}



$dbh = OpenDB();

$user{global}{pagetitle} = "Recently Active People";

#$sql = "select distinct users.id as id,handle,city,state,country,photos.id as photoId,TIMEDIFF(NOW(),lastLogin) as lastLogin,TIMEDIFF(NOW(),userSessions.lastAction) as lastActive,userSessions.pageCount from users left join photos on users.id=photos.userId and photos.rank=1,profiles,userSessions where users.id=profiles.userId and profiles.userId=userSessions.userId and lastAction > DATE_SUB(NOW(),interval 15 minute) order by lastActive;";
$sql = "SELECT DISTINCT(id) AS id FROM users WHERE lastActive > DATE_SUB(NOW(),INTERVAL 15 MINUTE) ORDER BY lastActive DESC";
my $timediff = $dbh->prepare("SELECT TIMEDIFF(NOW(),lastActive) AS lastActive FROM users WHERE id = ? ORDER BY id DESC LIMIT 1");

$sth = $dbh->prepare($sql);
$sth->execute;
$count = 0;
while (my $id = $sth->fetchrow) {
	my $User = Users->new(dbh => $dbh, cache => $memcache, userId => $id) or next;
	my $profile = $User->profile;

	$timediff->execute($id);
	$profile->{lastActive} = $timediff->fetchrow;

	%{$user{profiles}{$count++}{profile}} = %{$profile};

}
$timediff->finish;

$sth->finish;

$user{stats}{usersnow} = $count;
$sql = "SELECT count(1) from users where createDate >= DATE(NOW())";
$sth = $dbh->prepare($sql);
$sth->execute;
$user{stats}{conversions} = $sth->fetchrow;
$sth->finish;

$sql = "SELECT sum(pageCount) from userSessions where startDate >= DATE(NOW())";
$sth = $dbh->prepare($sql);
$sth->execute;
$user{stats}{impressions} = $sth->fetchrow;
$sth->finish;

$sql = "SELECT count(id) from messages where date >= DATE(NOW())";
$sth = $dbh->prepare($sql);
$sth->execute;
$user{stats}{msgcount} = $sth->fetchrow;
$sth->finish;

$sql = "SELECT count(distinct(id)) from users where lastActive >= DATE(NOW())";
$sth = $dbh->prepare($sql);
$sth->execute;
$user{stats}{users} = $sth->fetchrow;
$sth->finish;

$sql = "SELECT count(1) from users where lastActive >= DATE(NOW())";
$sth = $dbh->prepare($sql);
$sth->execute;
$user{stats}{userVisits} = $sth->fetchrow;
$sth->finish;

$sql = "SELECT count(1) from userSessions where userId is null and  startDate >= DATE(NOW())";
$sth = $dbh->prepare($sql);
$sth->execute;
$user{stats}{randomVisits} = $sth->fetchrow;
$sth->finish;



$sql = "select TIMEDIFF(NOW(),max(date)) from messages;";

$sth = $dbh->prepare($sql);
$sth->execute;

$user{stats}{lastMessage} = $sth->fetchrow;
$sth->finish;

$sql = "select TIMEDIFF(NOW(),max(createDate)) from users;";

$sth = $dbh->prepare($sql);
$sth->execute;

$user{stats}{lastRegister} = $sth->fetchrow;
$sth->finish;

$sql = "select TIMEDIFF(NOW(),max(insertDate)) from thumb;";

$sth = $dbh->prepare($sql);
$sth->execute;

$user{stats}{lastThumb} = $sth->fetchrow;
$sth->finish;


print $q->header();
print processTemplate(\%user,"admin/admin.now.html");
