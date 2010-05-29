#!/usr/bin/perl

use strict;
 
use DBI;
use lib "../lib";
use CONFIG;

my $dbh = DBI->connect("DBI:mysql:$dbName:$dbServer",$dbUser,$dbPass) or die "cannot connect to database: ".DBI->errstr;

for my $id (41,42) {
	my $path = "/var/opt/content-8001/photos/photoContest/$id";
	`mkdir -p $path/100`;
	`mkdir -p $path/large`;

	my $sth = $dbh->prepare("SELECT * FROM photo_contest_entry WHERE contestId = $id");
	$sth->execute;
	while (my $entry = $sth->fetchrow_hashref) {
	my $sth = $dbh->prepare("SELECT userId,photoId FROM photo_contest_entry WHERE id = ?");
		`cp /var/opt/content-8001/photos/$entry->{userId}/large/$entry->{photoId}.jpg $path/large/`;
		`cp /var/opt/content-8001/photos/$entry->{userId}/100/$entry->{photoId}.jpg $path/100/`;
	}
	$sth->finish;
}
