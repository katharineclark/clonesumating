#!/usr/bin/perl

use strict;
 
use POSIX qw(strftime);
use Data::Dumper;

use lib qw(. ../lib lib);
use template2;
use Profiles;

my $P = Profiles->new();

$P->{user}{form}{date} = strftime("%F",localtime);

if ($P->{command} eq '/edit') {
	edit($P);
} elsif ($P->{command} eq '/save') {
	save($P);
}
list($P);

print $P->Header;
print processTemplate($P->{user},"admin/admin.qow.html");

sub list {
	my $P = shift;

	my $sth = $P->{dbh}->prepare("SELECT * FROM questionoftheweek ORDER BY id DESC LIMIT 10");
	$sth->execute;
	while (my $q = $sth->fetchrow_hashref) {
		push @{$P->{user}{qows}}, {question => $q};
	}

}

sub edit {
	my $P = shift;
	my $sth = $P->{dbh}->prepare("SELECT * FROM questionoftheweek WHERE id = ?");
	$sth->execute($P->{query}->param('id'));
	$P->{user}{form} = $sth->fetchrow_hashref;
}

sub save {
	my $P = shift;

	my %args = map {$_ => $P->{query}->param($_)||undef} qw(date question);
	if ($args{date} && $args{question}) {
		$P->{dbh}->do("INSERT INTO questionoftheweek (date,question) VALUES (?,?)",undef,$args{date},$args{question});
	}
}

exit;

