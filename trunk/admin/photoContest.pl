#!/usr/bin/perl

use lib '../lib';
 
use Data::Dumper;
use template;
use profiles;

my %commands = (
	'' => \&list,
	'/changeState' => \&changeState,
	'/save' => \&save,
);

if ($commands{$command}) {
	$commands{$command}->();
} else {
	$commands{''}->();
}
exit;


sub list {
	my $sth = $dbh->prepare("SELECT * FROM photo_contest ORDER BY startDate DESC LIMIT 10");
	$sth->execute;

	my $getEntries = $dbh->prepare("SELECT COUNT(*) FROM photo_contest_entry WHERE contestId = ?");
	my $getBlings  = $dbh->prepare("SELECT COUNT(*) FROM photo_contest_bling WHERE contestId = ?");

	my $count = 0;
	while (my $c = $sth->fetchrow_hashref) {
		$getEntries->execute($c->{id});
		$c->{entries} = $getEntries->fetchrow;
		$getBlings->execute($c->{id});
		$c->{blings} = $getBlings->fetchrow;

		$c->{changeState} = !$c->{itson} || 0;

		%{$user{contests}{$count++}{contest}} = %{$c};
	}
	$sth->finish;
	$getBlings->finish;
	$getEntries->finish;

	print Header();
	print processTemplate(\%user,'admin/admin.photoContest.html');
}
sub changeState {
	my $cid = $q->param('contestId');
	my $itson = $q->param('itson');

warn "SAVE $cid,$itson";

	if ($itson) {
		# set everything off first so no two contests can be active at once
		$dbh->do("UPDATE photo_contest SET itson=0");
	} else {
		# archive photos
		warn "SAVE: END CONTEST $cid";

		my $path = "../photos/photoContest/$cid";

		`mkdir -p $path/100`;
		`mkdir -p $path/large`;

		$sth = $dbh->prepare("SELECT * from photo_contest_entry WHERE contestId = $cid");
		$sth->execute;
		while (my $entry = $sth->fetchrow_hashref) {
		my $sth = $dbh->prepare("SELECT userId,photoId FROM photo_contest_entry WHERE id = ?");
			`cp ../photos/$entry->{userId}/large/$entry->{photoId}.jpg $path/large/`;
			`cp ../photos/$entry->{userId}/100/$entry->{photoId}.jpg $path/100/`;
		}
		$sth->finish;
		
	}
	$dbh->do("UPDATE photo_contest SET itson=? WHERE id = ?",undef,$itson,$cid);

	print $q->redirect('/admin/photoContest.pl');
}

sub save {
	my $cid = $q->param('contestId');
	my $name = $q->param('name');
	my $shortname = $q->param('shortname');
	my $longname = $q->param('longname');
	my $bensname = $q->param('bensname');
	my $othername = $q->param('othername');
	my $tagname = $q->param('tagname');
	my $desc = $q->param('desc');
	my $date = $q->param('date');

	if ($cid) { 
		$dbh->do("UPDATE photo_contest SET name=?,shortname=?,longname=?,bensname=?,othername=?,tagname=?,description=?,startDate=? WHERE id = ?",undef,$name,$shortname,$longname,$bensname,$othername,$tagname,$desc,$date,$cid);
	} else {
		$dbh->do("INSERT INTO photo_contest (name,shortname,longname,bensname,othername,tagname,description,startDate) VALUES (?,?,?,?,?,?,?,?)",undef,$name,$shortname,$longname,$bensname,$othername,$tagname,$desc,$date);
		$cid = $dbh->selectrow_array("SELECT last_insert_id()");
	}

	print $q->redirect('/admin/photoContest.pl');
}
