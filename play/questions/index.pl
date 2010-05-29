#!/usr/bin/perl
use strict;

use lib "../../lib";
use Profiles;
use template2;
use peopleFinder;


my $getresponsecount;

{ 
	my $P = Profiles->new();
	$P->{user}{system}{tab} = "Questions";

	$getresponsecount = $P->{dbh}->prepare("SELECT count(1) FROM questionresponse WHERE questionId=?");

	# get most recent question
	my $sql = "SELECT * FROM questionoftheweek WHERE questionoftheweek.date < NOW() ORDER BY questionoftheweek.date desc limit 1;";
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	$P->{user}{question} = $sth->fetchrow_hashref;
	$getresponsecount->execute($P->{user}{question}{id});
	$P->{user}{question}{responses} = $getresponsecount->fetchrow;
	$sth->finish;

	my $totalCount = $P->{dbh}->selectrow_array("SELECT COUNT(*) FROM questionoftheweek WHERE id != $P->{user}{question}{id} AND date <= NOW()");
	$P->{user}{page}{questioncount} = $totalCount+1;

	unless ($P->{query}->param('query')) {
		if ($P->{user}{user}{id}) {
			my $sth = $P->{dbh}->prepare("SELECT COUNT(*) FROM questionresponse WHERE questionId = $P->{user}{question}{id} AND userId = $P->{user}{user}{id}");
			$sth->execute;
			$P->{user}{question}{answered} = $sth->fetchrow;
			$sth->finish;
		}

		# get a few questions
		$P->{user}{questions} = getQuestions($P,0);

		$P->{user}{pager}{next} = 11;
		

		# and that's it! pass it off to the template parser.
		print $P->Header();
		print processTemplate($P->{user},"play/questions/index.html");
	} else {
		my $offset = $P->{query}->param('offset');

		$P->{user}{questions} = getQuestions($P,$offset);

		if ($offset+10 < $totalCount) {
			$P->{user}{pager}{next} = $offset+10;
		}
		if ($offset > 10) {
			$P->{user}{pager}{prev} = $offset-10 == 1 ? 0 : $offset-10;
		} else {
			$P->{user}{pager}{prev} = -1;
		}
	
		my $d = processTemplate($P->{user},'play/questions/pager.html',1);
		print "Cache-Control: no-cache, must-revalidate\n";
		print "Pragma: no-cache\n";
		print "Content-type: text/xml\n\n";
		print qq|<rsp stat="ok" version="1.0">$d</rsp>|;
	}
}

sub getQuestions {
	my $P = shift;
	my $offset = shift || 0;

	my $getmyresponse = $P->{dbh}->prepare("SELECT COUNT(*) FROM questionresponse WHERE userId=$P->{user}{user}{id} AND questionId=?") if $P->{user}{user}{id};
	

	my $sql = "SELECT * FROM questionoftheweek WHERE date <= NOW() AND id != $P->{user}{question}{id} ORDER BY date DESC LIMIT $offset,10";
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	my @q;
	while (my $q = $sth->fetchrow_hashref) {
		if ($P->{user}{user}{id}) {
			$getmyresponse->execute($q->{id});
			$q->{answered} = $getmyresponse->fetchrow;
		}
		$getresponsecount->execute($q->{id});
		$q->{responses} = $getresponsecount->fetchrow;

		push (@q,{question => $q});
	}
	$sth->finish;
	$getmyresponse->finish if $P->{user}{user}{id};

	return \@q;
}
#fin
