#!/usr/bin/perl

use strict;
 
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;
use CGI;

use lib "lib";
use template2;
use Profiles;
use Users;
use tags;
use teams;

my $P = Profiles->new(query => new CGI);

$P->{user}{system}{tab} = "Tags";

# IF there are cookies, set the params via cookies

my $sex = $P->{query}->cookie('sex');
my $low_age = $P->{query}->cookie('low_age');
my $close = $P->{query}->cookie('distance');
my $team = $P->{query}->cookie('team');

# If no cookie, grab form param

if ($P->{query}->param('sex')) {
        $sex= $P->{query}->param('sex');
}

if ($P->{query}->param('low_age')) {
        $low_age = $P->{query}->param('low_age');
}

if ($P->{query}->param('distance')) {
        $close = $P->{query}->param('distance');
}

if (defined $P->{query}->param('team')) {
	$team = $P->{query}->param('team');
}


# if no form param, any default value
if ($P->{query}->param('reset')) {
	$sex = 'any';
	$low_age='any';
	$close ='anywhere';
	$team = 0;
}


$P->{user}{form}{sex} = $sex;
$P->{user}{form}{low_age} = $low_age;
$P->{user}{form}{distance} = $close;
$P->{user}{form}{team} = $team;




if ($ENV{REQUEST_URI} ne '/browse/') {
	# just add all the parameters together

	my $offset = $P->{query}->param('offset') || 0;
	my $toffset = $P->{query}->param('toffset') || 0;

	my @params;
	if ($sex =~ /m/ || $sex =~ /f/) {
		push(@params,"(sex='$sex')");
	}


	my $high_age;
	if ($low_age =~ /\d+/) {
		$high_age =  $low_age + 9;
		push(@params,"YEAR(NOW()) - YEAR(birthDate) between $low_age and $high_age");
	}

	if ($close =~ /^\d+$/) {
		if ($P->{user}{user}{country} ne 'US') {
			push @params, "country = '$P->{user}{user}{country}'";
			if ($close <= 10) {
				push @params, "city = ".$P->{dbh}->quote($P->{user}{user}{city});
			}
		} else {
			# generate distance query
			my $zips = $P->{cache}->get("zips".$P->{user}{user}{zipcode}."-".$close);
			unless ($zips) {
				my %dists = qw(5 five 10 ten 25 twentyfive 50 fifty);
				my $sql = "SELECT $dists{$close} FROM zips WHERE zip = ?";
				my $sth = $P->{dbh}->prepare($sql);
				$sth->execute($P->{user}{user}{zipcode});
				$zips = $sth->fetchrow;
				$sth->finish;
				$P->{cache}->set("zips".$P->{user}{user}{zipcode}."-".$close,$zips);
			}
			push @params,"zipcode IN ($zips)";
		}
	}

	if ($P->{query}->param('createDate')) {

		if ($P->{query}->param('createDate') eq "today") {
			push(@params,"(createDate > DATE_SUB(NOW(),INTERVAL 1 DAY))");
		} elsif ($P->{query}->param('createDate') eq "week") {
			push(@params,"(createDate > DATE_SUB(NOW(),INTERVAL 7 DAY))");
		} elsif ($P->{query}->param('createDate') eq "2weeks") {			
			push(@params,"(createDate > DATE_SUB(NOW(),INTERVAL 14 DAY))");
		}

	}

	my $usedtags;
	if ($P->{query}->param('tags')) {
		my $t = $P->{query}->param('tags');
		$t =~ s/\s+/ /gsm;
		$t =~ s/^\s+//gsm;
		$t =~ s/\s+$//gsm;
		my @tags = split(/\s+/,$P->{query}->param('tags'));

		if (scalar(@tags) > 0) {
			my @taglist;
			for my $i (0 .. $#tags) {
				if ($tags[$i] !~ /^\s+$/ && $tags[$i] ne "") {
					push @{$P->{user}{usedtags}}, { tag => { value => $tags[$i] } };
					$tags[$i] = $P->{dbh}->quote($tags[$i]);
					push(@taglist,$tags[$i]);
				}
				$usedtags =~ s/^\,//gsm;
			}
			$usedtags = join(',',@taglist);

			my $sql = "SELECT distinct tagRef.profileId,count(tagRef.tagId) as count FROM tag,tagRef where tagRef.tagId=tag.id AND tag.value in (" . join(",",@taglist) . ") GROUP BY tagRef.profileId HAVING count=" . scalar(@taglist) . ";";
			my $sth = $P->{dbh}->prepare($sql);
			$sth->execute;
			my @uids;
			while (my ($uid,$count) = $sth->fetchrow) {
				push(@uids,$uid);
			}
			$sth->finish;
			if (scalar(@uids) > 0) {
				push(@params,"(u.id in (" . join(",",@uids) . "))");
			} else {
				push(@params,"(1=2)");
			}

		}

	}

	if (0 && $team > 0) {
		my $sql = "SELECT userId FROM team_members WHERE teamId = ?";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute($team);
		if ($sth->rows) {
			my $str = "u.id IN (".join(',',map{$_->[0]}@{$sth->fetchall_arrayref}).")";
			push @params, $str;
		} else {
			push @params, "u.id = 0";
		}
	}


	generateResults($P->{dbh},$P->{user},$offset,$toffset,$usedtags,@params);

	if ($P->{user}{search}{resultCount} > $P->{user}{search}{offset}) {
		$P->{user}{search}{next} = 1;
	}
	if ($P->{user}{search}{offset} > 24) {
		$P->{user}{search}{previous} = 1;
		$P->{user}{search}{previousoffset} = $P->{user}{search}{offset} - $P->{user}{search}{shown} - 24;
	}

	my $start = ($P->{user}{search}{offset} - $P->{user}{search}{shown}) + 1;
	my $end = $P->{user}{search}{offset};
	$P->{user}{search}{viewing} = "Viewing result $start - $end ";

	$P->{user}{search}{searchresults} = processTemplate($P->{user},"tags/browser/searchResults.html",1);
	$P->{user}{search}{usedtags} = processTemplate($P->{user},"tags/browser/usedTags.html",1);
	$P->{user}{search}{availabletags} = processTemplate($P->{user},"tags/browser/availableTags.html",1);
} elsif(0) {
	my $teams = teams->new(dbh => $P->{dbh}, cache => $P->{cache});
	for (grep {$_->isMember($P->{user}{user}{id}) || $_->data('id') == $team} $teams->getTeams()) {
		if ($team eq $_->data('id')) {
			$_->data(selected => 'selected',1);
		} else {
			$_->data(selected => '',1);
		}
		push @{$P->{user}{teams}},{team => $_->data};
	}
}


# generate cookies      
my @cookies = (
	$P->{query}->cookie(-name=>'sex',-value=>$sex,-domain=>'.consumating.com'),
	$P->{query}->cookie(-name=>'distance',-value=>$close,-domain=>'.consumating.com'),
	$P->{query}->cookie(-name=>'low_age',-value=>$low_age,-domain=>'.consumating.com'),
	$P->{query}->cookie(-name=>'team',-value=>$team,-domain=>'.consumating.com'),
);

if ($P->{query}->param('quick')) {
	print $P->{query}->header(-cookie=>[@cookies]);
	print "|||$P->{user}{search}{searchresults}|||$P->{user}{search}{usedtags}|||$P->{user}{search}{availabletags}|||$P->{user}{search}{resultCount}";
} elsif ($ENV{PATH_INFO} eq "/rss") {
	print "Content-type: text/xml\n\n";
	print processTemplate($P->{user},"tags/browser/rss.html",1);
} else {
	print $P->{query}->header(-cookie=>[@cookies]);
	print processTemplate($P->{user},"tags/browser/index.html");
}




sub generateResults {
	($P->{dbh},$P->{user},my $offset,my $toffset,my $usedtags,my @params) = @_;

	my ($sql,$profile,$sth);

	$sql = "SELECT u.id FROM users u,profiles p WHERE u.status != -2 AND p.userid=u.id ";

	if (scalar(@params) > 0) {
		$sql .= " AND " . join(" AND ",@params);
	}

	$sql .= " ORDER BY lastLogin DESC";

	$sth = $P->{dbh}->prepare($sql);

	$sth->execute;

	my @uids = map {$_->[0]} @{$sth->fetchall_arrayref};
	$sth->finish;
	my $realcount = scalar @uids;

	$sql .= " LIMIT $offset,24";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	delete $P->{user}->{results};
	delete $P->{user}->{search};
	
	if ($sth->rows) {
		while (my $id = $sth->fetchrow) {
				my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
				push @{$P->{user}{results}}, {user => $User->profile};
		}
		$P->{user}->{search}{offset} = $offset + scalar @{$P->{user}{results}};
		$P->{user}->{search}{shown} = scalar @{$P->{user}{results}};
	}
	$sth->finish;

	if (scalar(@params) > 0) {
		# taking an integer is MUCH faster than assigning a scalar.
		#$P->{user}->{search}{resultCount} = scalar(@uids);
		$P->{user}->{search}{resultCount} = $realcount;
	} else {
		my $sql = "SELECT count(1) FROM profiles";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$P->{user}->{search}{resultCount} = $sth->fetchrow;
		$sth->finish;
	}
		

	# load all available tags for users in the search results
	if(scalar(@uids) > 0) {
		$sql = "SELECT distinct value,count(tagRef.profileId) as count FROM tag,tagRef WHERE tag.id=tagRef.tagId ";

		if (scalar(@params) && scalar @uids) {
			# we only need to limit what tags we show if there is a limit on the users.
			$sql .= " and tagRef.profileId in (" . join(",",@uids) . ")";
		}

		if ($usedtags ne "") {
			$sql .= " and value not in ($usedtags) ";
		}



		$sql .=  " group by tag.id having count < $P->{user}{search}{resultCount} order by count desc limit $toffset,100;"; 


		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$P->{user}{availabletags} = [map {tag => { value => $_->[0], count => $_->[1] }} => @{$sth->fetchall_arrayref}];
	} else {
		my $tags = tags->new($P->{cache}, $P->{dbh});

		my %tagList;
		my @ps = $tags->getProfiles(\@uids);

		for my $p (@ps) {
			for (@$p) {
				$tagList{$_}++;
			}
		}

		my %usedtags = map {$_ => 1} grep {length} split /\s+/,$P->{query}->param('tags'); 
		# sort by the tag count, excluding tags common to all users
		my $count=0;
		for (sort {$tagList{$b} <=> $tagList{$a}} grep {$tagList{$_} < scalar keys %tagList && !$usedtags{$_}} keys %tagList) {
			push @{$P->{user}{availabletags}}, { tag => { value => $_, count => $tagList{$_} }};
			last if $count++ == 200;
		}
	}
}

$P->{dbh}->disconnect();
