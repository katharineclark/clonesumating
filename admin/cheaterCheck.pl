#!/usr/bin/perl

use lib qw(../lib lib);
 
use template2;
use Profiles;
use Users;
use util;

my @primaryFields = qw(userId handle linkhandle username password firstName lastName city birthDate createDate lastActive popularity tagline);

my %primaryFields = map {$_ => 1}@primaryFields;

my $P = Profiles->new();

if ($P->{query}->param('submit')) {
	my $handle = $P->{query}->param('handle');

	my $id = $P->{dbh}->selectrow_array("SELECT userid FROM profiles WHERE handle = ?",undef,$handle);
	unless ($id) {
		$id = $P->{dbh}->selectrow_array("SELECT id FROM users WHERE username=?",undef,$handle);
	}

	my $u = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id, force => 1);
	unless ($u) {
		$P->{user}{profile}{handle} = $handle;
		$P->{user}{page}{error} = 1;
	} else {
		$P->{user}{profile} = $u->profile;
		$P->{user}{profile}{localQuery} =~ s/,/ ,/g;


		my $sql = "SELECT b.userId,COUNT(*) FROM bling b INNER JOIN questionresponse r ON r.id = b.questionresponseid WHERE r.id IN (SELECT id FROM questionresponse WHERE userId = $u->{profile}{userId}) AND b.type='U' GROUP BY 1 HAVING COUNT(*) > 5 ORDER BY 2 DESC LIMIT 20";
warn "SQL $sql;";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $r = $sth->fetchrow_arrayref) {
			my $u = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $r->[0]) or next;
warn "ADDING $r->[0]: $r->[1]";
			push @{$P->{user}{blingUsers}}, { profile => $u->profile, blings => {count => $r->[1]}};
		}
			
	}
}

print $P->Header;
print processTemplate($P->{user},"admin/admin.cheaterCheck.html");

