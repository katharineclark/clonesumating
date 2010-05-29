#!/usr/bin/perl

use strict;

use lib "../lib";
use template;
use profilesmodperl qw($q $command %user $memcache $dbh loadUser Header);
use QuestionResponse;
use Users;
use Time::HiRes qw(gettimeofday tv_interval);
use Date::Calc qw(Today Add_Delta_Days);

%user = loadUser();

$user{system}{tab} = "Popularity";


if ($command eq "") {
	print Header();
	print processTemplate(\%user,"scoreboard/popularityHistory.html");
} elsif ($command eq "/data") {
	if ($user{user}{id}) {

		print qq|Content-type: text/xml\n\n|;
		print qq|<?xml version="1.0"?>
		<rsp status_code="0" status_message="Success">
		<daily_counts>|;
		my $sql = "SELECT MAX(popularity),LEFT(date,10) AS sdate FROM popularityTrend WHERE userId=$user{user}{id} AND date > DATE_SUB(NOW(),INTERVAL 120 DAY) GROUP BY sdate ORDER BY date";
		my $sth = $dbh->prepare($sql);	
		$sth->execute;
		my %pops;
		while (my ($pop,$date) = $sth->fetchrow_array) {
			$pops{$date} = $pop;
		}
		my @dates;
		my $today = sprintf("%04d-%02d-%02d",Today);
		if ($sth->rows) {
			@dates = sort keys %pops;
		} else {
			my @today = split /-/,$today;
			@dates = reverse map {sprintf("%04d-%02d-%02d",Add_Delta_Days(@today,-$_))}0..30;
			$pops{$dates[$#dates]} = $dbh->selectrow_array("SELECT popularity FROM users WHERE id = ?",undef,$user{user}{id});
		}
		$sth->finish;
		my $date = $dates[0];
		my $current;
		while ($date lt $today) {
			if ($pops{$date}) {
				$current = $pops{$date};
			} else {
				$pops{$date} = $current;
			}
			$date = sprintf("%04d-%02d-%02d",Add_Delta_Days(split(/-/,$date),1));
		}
		my $cnt = scalar keys %pops || 0;
		my $lim = $cnt < 30
			? 30 
			: $cnt < 60 
				? 60 
				: $cnt < 120
					? 120
					: do {
						while (scalar keys %pops > 120) {
							delete $pops{shift @dates};
						}
					};
		my $d = $dates[0];
		for (1 .. ($lim-$cnt)) {
			$d = sprintf("%04d-%02d-%02d",Add_Delta_Days(split(/-/,$d),-1));
			$pops{$d} = $pops{$dates[0]};
		}

		foreach (sort keys %pops) {
			my $date = $_;
			$date =~ s/\-//g;
			$date .= "T00:00:00";
			print qq|<count date="$date">|.($pops{$_}||0).qq|</count>\n|;
		}

		print qq|  </daily_counts>
		</rsp>|;
	}
} elsif ($command eq '/query') {
	my $range = $q->param('range');


	my @d = split /-/,$range;
	my $start = sprintf("%04d-%02d-%02d",unpack('A4A2A2A*',$range));
	my $end = sprintf("%04d-%02d-%02d",unpack('A4A2A2A*',$d[1]));

	my $datestr = $end eq '0000-00-00'
		? "DATE(insertDate) = '$start'"
		: "DATE(insertDate) between '$start' and '$end'";


	my %totalpoints;

	# get blings
	{
		my $QR = QuestionResponse->new(dbh => $dbh, cache => $memcache);
		my $entries = $QR->getUserEntries($user{user}{id});
		if (ref $entries eq 'HASH' && scalar keys %$entries) {
			my $sth = $dbh->prepare("SELECT DISTINCT questionresponseid AS qrid, type, COUNT(*) AS count FROM bling WHERE questionresponseid IN (".join(',',keys %$entries).") AND $datestr GROUP BY 1,2");
			$sth->execute;
			my $qsth = $dbh->prepare("SELECT question FROM questionoftheweek WHERE id = ?");
			my %questions;
			while (my $b = $sth->fetchrow_hashref) {
				if (!defined $questions{$b->{qrid}}) {
					$QR->loadFromId($b->{qrid});
					my $response = $QR->response;
					$response->{linkhandle} = $user{user}{linkhandle};
					$response->{points} = 0;
					if ($b->{type} eq 'U') {
						$response->{points} += ($b->{count} * 2);
					} else {
						$response->{points} -= $b->{count};
					}
					$qsth->execute($response->{questionId});
					$response->{question} = $qsth->fetchrow;
					$questions{$b->{qrid}} = $response;
				} else {
					if ($b->{type} eq 'U') {
						$questions{$b->{qrid}}->{points} += ($b->{count} * 2);
					} else {
						$questions{$b->{qrid}}->{points} -= $b->{count};
					}
				}
			}
			$sth->finish;
			my $count = 0;
			my $lcount = 0;

			my @tmp = sort {$questions{$b}->{points} <=> $questions{$a}->{points} } keys %questions;
			for my $c (0 .. $#tmp) {
				my $id =$tmp[$c];
				$totalpoints{'Question Answers'} += $questions{$id}->{points};
				if ($questions{$id}->{points} > 0) { 
					$questions{$id}->{positive} = 1; 
				} else { 
					$questions{$id}->{points} *= -1; 
				}
                $questions{$id}->{question} = shortenHeadline($questions{$id}->{question},30);
				next if $questions{$id}->{points} == 0;

				if ($lcount < 5 && $questions{$id}->{positive}) {
                	$user{questions}{$lcount++}{question} = $questions{$id};
				}
				if ($count < 5 && !$questions{$id}->{positive}) {
				$user{questionslosers}{$count++}{question} = $questions{$id};
				}
			}
			if ($#tmp == -1) {
				$user{noquestions}{message} = 'You got nothin!';
			}

		}
	}

	# get thumbs
	{
		my $sth = $dbh->prepare("SELECT COUNT(*) FROM thumb WHERE profileId = $user{user}{id} AND type = ? AND $datestr");
		$sth->execute('U');
		my $pts = ($sth->fetchrow * 2);
		$sth->execute('D');
		$pts -= $sth->fetchrow;
		$sth->finish;
		
		if ($pts >= 0) {
			$user{thumbs}{positive} = 1;
		} else {
			$pts *= -1;
		}
		$user{thumbs}{points} = $pts;
		$totalpoints{'Profile Thumbs'} = $pts;
	}

	# get contest blings
	{
		$datestr =~ s/insertDate/b.insertDate/g;
		my $sql = "SELECT DISTINCT c.name,e.photoId,b.contestId,c.itson,e.userId,b.type,COUNT(*) AS count FROM photo_contest_bling b,photo_contest_entry e,photo_contest c WHERE e.id = b.entryId AND c.id = e.contestId AND e.userId = $user{user}{id} AND $datestr GROUP BY 1,2,3,4,5,6";
		my $sth = $dbh->prepare($sql);
		$sth->execute;
		my %contests;
		while (my $b = $sth->fetchrow_hashref) {
			if (!defined $contests{$b->{name}}) {
				$b->{points} = 0;
				if ($b->{type} eq 'U') {
					$b->{points} += ($b->{count} * 2);
				} else {
					$b->{points} -= $b->{count};
				}
				$contests{$b->{name}} = $b;
			} else {
				if ($b->{type} eq 'U') {
					$contests{$b->{qrid}}->{points} += ($b->{count} * 2);
				} else {
					$contests{$b->{qrid}}->{points} -= $b->{count};
				}
			}
		}
		$sth->finish;
		my $count = 0;
		for my $id (keys %contests) {
			next unless $contests{$id}->{contestId};
			$totalpoints{'Photo Contests'} += $contests{$id}->{points};
			if ($contests{$id}->{points} > 0) { 
				$contests{$id}->{positive} = 1; 
			} else { 
				$contests{$id}->{points} *= -1; 
			}
			next if $contests{$id}->{points} == 0;
			if ($contests{$id}->{itson}) {
				delete $contests{$id}->{contestId};
			}
			$user{contests}{$count++}{contest} = $contests{$id};
		}
	}
	
	$user{date}{start} = $start;
	$user{date}{end} = $end;
	if ($user{date}{end} eq '0000-00-00') { $user{date}{singleday} = 1 }
	my $count = 0;
	$user{points}{total} = 0;
	$user{points}{questions} = $totalpoints{'Question Answers'};
	$user{points}{questionspositive} = $totalpoints{'Question Answers'} >= 0;
	for (keys %totalpoints) {
		$user{points}{total} += $totalpoints{$_};
		$user{breakdown}{$count++}{points} = { name => $_ , points => $totalpoints{$_} };
	}
	if ($user{points}{total} >= 0) { 
		$user{points}{positive} = 1;
	} else {
		$user{points}{total} *= -1;
	}


	print Header();
	print processTemplate(\%user,'scoreboard/pophistory.data.html',1);
}




sub shortenHeadline() {
    my ($headline,$len) = @_;

    if (length($headline) > $len) {
        my @words = split(/\s+/,$headline);
        my $newstr = '';
        my $count = 0;
        do {
            $newstr .= " " . $words[$count++];
            $newstr =~ s/^\s//gsm;
        } while (length($newstr) < $len);        $newstr .= "...";
        return $newstr;    } else {
        return $headline;
    }
}

