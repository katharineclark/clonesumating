#!/usr/bin/perl

use lib qw(../lib lib);
 
use template2;
use Profiles;
use Users;
use util;


my $P = Profiles->new();

if ($P->{query}->param('submit')) {
}

my $sth = $P->{dbh}->prepare("SELECT * FROM spamUser ORDER BY id DESC");
$sth->execute;
while (my $r = $sth->fetchrow_hashref) {
	my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $r->{userId}) or next;

	push @{$P->{user}{spammers}}, { profile => $U->profile, spam => $r };
}

print $P->Header;
print $P->process("admin/admin.spammers.html");

exit;
