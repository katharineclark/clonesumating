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
		for my $field (@primaryFields) {
			push @{$P->{user}{primaryprofiledata}}, {data => {field => $field, value => $P->{user}{profile}{$field}}};
		}
		for my $field (grep {!$primaryFields{$_}} sort keys %{$P->{user}{profile}}) {
			push @{$P->{user}{profiledata}}, {data => {field => $field, value => $P->{user}{profile}{$field}}};
		}
	}
}

print $P->Header;
print processTemplate($P->{user},"admin/admin.users.html");

