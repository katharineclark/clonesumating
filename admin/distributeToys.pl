#!/usr/bin/perl
$|++;

use strict;
 
use DBI;
use lib qw(. .. lib ../lib);
use Profiles;
use Cache;
use items;
use Users;

my $P = new Profiles(cache => new Cache);
my $dbh = $P->{dbh};

#my $sth = $dbh->prepare("SELECT id FROM users where id > 21937 and lastActive > date_sub(now(),interval 3 month)");
my $sth = $dbh->prepare("SELECT id FROM user_items WHERE createDate > '2006-12-21 12:40'");
$sth->execute;
my $uid;
$sth->bind_columns(\$uid);

my $I = items->new($P->{cache}, $P->{dbh}, 1);

my $ins = $dbh->prepare("INSERT INTO alertSubscriptions (userId,alertId,target) VALUES (?,6,'email')");
my $upd = $dbh->prepare("UPDATE user_items SET type = 'system' WHERE id = ?");

while ($sth->fetchrow_arrayref) {
	# add toys
	print "Clean for user $uid\n";
	$upd->execute($uid);
	
	`rm -f /var/opt/content-8001/img/items/user/$uid.gif`;
}
$ins->finish;
$dbh->disconnect;
