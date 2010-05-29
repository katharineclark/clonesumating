#!/usr/bin/perl

use strict;
 
use lib qw(/var/opt/content-8000/lib);
use Users;
use Profiles;

my $P = Profiles->new;

my ($mail,$number);
while (<>) {
	if (/From: (.+)/) {
		$mail = $1;
	}
	if (/^(\d+)$/) {
		$number = $1;
	}
	if ($mail && $number) {
		updateUser($mail,$number);
		$mail = $number = '';
	}
}

sub updateUser {
	my $mail = shift;
	my $number = shift;

warn "GOT $mail,$number";
	my $sth = $P->{dbh}->prepare("SELECT id FROM users WHERE cell = ?");
	$sth->execute($number);
	return unless $sth->rows;
	my $uid = $sth->fetchrow;

	my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or return;
	$U->updateField(cell => $mail);
}
