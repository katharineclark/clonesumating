#!/usr/bin/perl

use strict;
 
use Data::Dumper;
use threads;
use threads::shared;
use DBI;
use Cache::Memcached;
use lib qw(. lib ../lib);
use Users;
use Cache;
use mail;
use template2;
use CONFIG;

my %commands = ( 
	newquestion => \&newquestion,
	newcontest  => \&newcontest
);

my $cache = new Cache;

my $mailers = 10;

my $name = $ARGV[0];
die "Missing parameters!" unless ($name);

my $datasource = "DBI:mysql:$dbName:$dbServer";
my $dbh = DBI->connect($datasource, $dbUser,$dbPass) ||  die "Uh oh!  We're having trouble connecting to the database. Please try again in a few moments.";

# verify alert type
my ($cnt,$alertType) = $dbh->selectrow_array("SELECT id,type FROM alertTypes WHERE name = ?",undef,$name);
die "alert type not found" unless ($cnt > 0);
die "This is not a mass alert" unless $alertType eq 'mass';

print "ALERT ID $cnt: $name\n";

# get all userIds with this alert type
my @users :shared;
my %users :shared;
my $sth = $dbh->prepare("SELECT userId FROM alertSubscriptions WHERE alertId = $cnt");
#my $sth = $dbh->prepare("SELECT 2447");
#my $sth = $dbh->prepare("SELECT userId FROM alertTest WHERE alertId = $cnt ORDER BY userId");
my $uid;
$sth->execute;
$sth->bind_columns(\$uid);
while ($sth->fetchrow_arrayref) {
	my $U = Users->new(dbh => $dbh, cache => $cache, userId => $uid) or next;

	push @users, &share([]);
	$users{$uid} = 0;
	$users[$#users][0] = $uid;
	$users[$#users][1] = &share({});
	for (keys %{$U->{profile}}) {
		$users[$#users][1]{$_} = $U->{profile}{$_};
	}

	my $f = $users[$#users];
}

# prepare email template
my $hash = $commands{$name}->();
my $subject:shared;
my $textbody:shared;
my $htmlbody:shared;


$subject = processTemplate($hash,"alerts/$name.subject.txt",1);
$textbody = processTemplate($hash,"alerts/$name.txt",1);
$htmlbody = processTemplate($hash,"alerts/$name.html",1);

print "Mailing ".scalar(@users)." over $mailers threads.\n";
my $total = scalar @users;
my $threadcount :shared;
my $sent :shared;
if (scalar(@users) > $mailers) {
	print "MANY USERS\n";
	for (0 .. $mailers) {
		my $th = threads->new(\&sender);
		$th->detach;
	}
} else {
	print "FEW USERS\n";
	while (scalar @users) {
		threads->new(\&sender)->detach;
	}
}
while ($threadcount && scalar @users) {
	print scalar(@users)." Users left to mail, $sent sent.\n";
	sleep(1);
}
sleep(8);
print "Done: $sent sent out of $total\n";

sub sender {
	$threadcount++;

	my $separator = '--__-------------=_'.time().rand(time());
	my $textlength = length $textbody;
	my $htmllength = length $htmlbody;
	my $msg = new mail;
	$msg->set("From",'notepasser@notepasser.consumating.com');
	$msg->set("subject",$subject);
	$msg->set("Content-Type",qq|multipart/alternative; boundary="$separator"|);
	my $body = <<MIME;
This is a multi-part message in MIME format.

--$separator
Content-Disposition: inline
Content-Length: $textlength
Content-Transfer-Encoding: binary
Content-Type: text/plain

$textbody

--$separator
ontent-Disposition: inline
Content-Length: $htmllength
Content-Transfer-Encoding: binary
Content-Type: text/html

$htmlbody

--$separator--
MIME
	$msg->set("body",$body);

	while (scalar @users) {
		lock @users;
		my $user = shift @users;
		cond_signal(@users);
		next unless ref $user eq 'ARRAY' && $user->[0] > 0;

		$sent++;
		$users{$user->[0]}++;
		$msg->set("to",$user->[1]{username});
		my $r = $msg->send;
		print "SENT TO $user->[0]: $user->[1]{username}; ($r) $sent\n";
	}
	$threadcount--;
}


sub newquestion {
	# get latest question
	return {question => $dbh->selectrow_hashref("SELECT * FROM questionoftheweek ORDER BY id DESC LIMIT 1") };
}

sub newcontest {
	# get latest contest
	return {contest => $dbh->selectrow_hashref("SELECT * FROM photo_contest WHERE itson=1 ORDER BY id DESC LIMIT 1") };
}
