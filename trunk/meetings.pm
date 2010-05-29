package meetings;


use strict;
 
use Data::Dumper;
use Date::Calc qw(Delta_DHMS Today_and_Now);
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use CGI;
use POSIX qw(strftime);
use Date::ICal;
use Net::ICal::Attendee;
use Net::ICal::Calendar;
use Net::ICal::Event;
use Digest::SHA1 qw(sha1_hex);


use lib "lib";
use template2;
use Profiles;
use cache;
use bbDates;
use sphere;

our (%db_sth,$guserid,$handle,$dbh);
our $cache = new Cache;
our $postsPerPage = 100;

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $dbActive = ref $dbh && $dbh->ping;

	my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
	unless (ref $P) {
		return 0;
	}
	$P->{user}{system}{tab} = "Meetings";


	warn "MEETINGS PID: $$: $P->{command}";
	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> CGI->new($r),
	};
	bless $self, $class;

	$self->{command} = $P->{command};

	%db_sth = $self->prepareQueries unless ($dbActive);

	$self->{user}{user}{feedkey} = sha1_hex($self->{user}{user}{username}.'m0reeeeeee*cowbell');

	my $id = $self->{query}->param('id');
	if ($id && $self->{command} eq '/changeSponsor') {
		my $handle = $self->{query}->param('sponsorName');
		my $uid = $self->{dbh}->selectrow_array("SELECT userId FROM profiles WHERE handle = ?",undef,$handle);
warn "HANDLE $handle, UID $uid";
		if ($uid) {
			$self->{dbh}->do("UPDATE events SET sponsorId = $uid WHERE id = $id AND sponsorId = $self->{user}{user}{id}");
			$r->headers_out->set(Location => '/meetings');
			return (REDIRECT);
		} else {
			return $self->edit($id);
		}
	} elsif ($self->{command} eq '/edit') {
		if ($self->{user}{user}{id}) {
			return $self->edit($id);
		} else {
			$r->headers_out->set(Location=>'/register.pl');
			return (REDIRECT);
		}
	} elsif ($id) {
		return $self->topics($id);
	} elsif ($self->{command} eq '/ical') {
		return $self->ical();
	} else {
		# get all meetings
		$db_sth{list}->execute;
		my %tags;
		while (my $m = $db_sth{list}->fetchrow_hashref) {
			
			if ($m->{minutes} < 0) {
				$m->{minutes} *= -1;
				$m->{daysuntil} = $self->{util}->timesince($m->{minutes});
				$m->{daysuntil} .= ' ago';
				$m->{datesort} = -1;
			} elsif (!$m->{minutes}) {
				$m->{daysuntil} = 'TBD';
				$m->{datesort} = 0;
			} else {
				$m->{daysuntil} = $self->{util}->timesince($m->{minutes});
				$m->{datesort} = 1;
			}

			my @attendees = $self->getAttendees($m->{tag});
			$m->{attendees} = scalar @attendees;
			my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $m->{sponsorId}) or next;
			$tags{lc($m->{tag}).'_rsvp'} = [$m,$U->profile];
			$m->{name} = ucfirst($m->{name});
			$U->{profile}{eschandle} = lc($U->{profile}{eschandle});
			push @{$self->{user}{allmeetings}}, {meeting => $m, user => $U->profile};

			if ($self->attending($m->{tag}) || $m->{sponsorId} == $self->{user}{user}{id}) {
				push @{$self->{user}{mymeetings}}, {meeting => $m, user => $U->profile};
			}
		}
		#$db_sth{recent}->execute;
		#while (my $m = $db_sth{recent}->fetchrow_hashref) {
			#push @{$self->{user}{recentmeetings}}, {meeting => $m};
		#}

		# get peeps meetings
		if ($self->{user}{user}{id}) {
			my %sphere = sphere::getSphere($self->{dbh},$self->{user});
			# get their event tags
			my @tags = map {$self->{dbh}->quote($_)} keys %tags;
			my $sth = $self->{dbh}->prepare("SELECT value FROM tagRef r INNER JOIN tag t ON t.id=r.tagId WHERE r.profileId=? AND t.value IN (".join(",",@tags).")");
			my %pevents;
			for my $userid (keys %sphere) {
				$sth->execute($userid);
				while (my $v = $sth->fetchrow) {
					$pevents{lc $v} = $tags{lc $v};
				}
				last if scalar keys %pevents == scalar keys %tags;
			}
			if (scalar keys %pevents) {
				@{$self->{user}{peepsmeetings}} = 
					map {
						meeting => $_->[0], 
						user => $_->[1]
					} 
					=> sort {
						$a->[0]{date} cmp $b->[0]{date}
					} 
					values %pevents
				;
			}
		}

		print processTemplate($self->{user},'meetings/index.html');
	}
		



	return 0;
}


sub topics {
    my $P = shift;
	my $id = shift;


	$db_sth{meeting}->execute($id);
	$P->{user}{meeting} = $db_sth{meeting}->fetchrow_hashref;
	$P->{user}{meeting}{mymeeting} = 1 if $P->{user}{user}{id} == $P->{user}{meeting}{sponsorId};
	$P->{user}{meeting}{coming} = $P->attending($P->{user}{meeting}{tag});
	my @attendees = $P->getAttendees($P->{user}{meeting}{tag});
	for (@attendees) {
		my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $_) or next;
		push @{$P->{user}{attendees}}, { profile => $U->profile };
	}
	$P->{user}{meeting}{attendees} = ref $P->{user}{attendees} ? scalar @{$P->{user}{attendees}} : 0;
		

	my $guserid = $P->{user}{meeting}{sponsorId};


	my $offset = $P->{query}->param('offset') || 0;

	my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $guserid, meeting => 1);
	$P->{user}{profile} = $User->profile;
	if ($P->{user}{profile}{userid} == $P->{user}{user}{id}) {
		$P->{user}{profile}{myprofile} = 1;
	}

	if ($guserid eq $P->{user}{user}{id}) {
		$P->{user}{page}{myprofile} = 1;
	}

	my $sth = $db_sth{topicbyId};
	$sth->execute($id);

	if (my $topic = $sth->fetchrow_hashref) {


        if ($P->{user}{user}{id}) {
			# does this person have this conversation watched?
			my $iswatched = $P->{dbh}->prepare("SELECT count(1) FROM topicwatch WHERE topicId=? AND userId=?");
			$iswatched->execute($topic->{id},$P->{user}{user}{id});
            $P->{user}{page}{watch} = $iswatched->fetchrow;
            $iswatched->finish;
		}


		$topic->{timesinceposted} = $P->{util}->timesince($topic->{minutes});

		$topic->{enabled} = 1;

		%{$P->{user}{topic}} = %{$topic};

		$db_sth{responseCount}->execute($topic->{id});
		$P->{user}{topic}{responseCount} = $db_sth{responseCount}->fetchrow;

		$db_sth{responseUsers}->execute($topic->{id},$guserid);
		while (my $uid = $db_sth{responseUsers}->fetchrow) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or next;
			push(@{ $P->{user}{responders} },{profile => $User->profile});
		}



		my $responseoffset = $P->{user}{topic}{offset} = 
			defined $P->{query}->param('responseoffset') 
			? $P->{query}->param('responseoffset')
			: $P->{user}{topic}{responseCount} - $postsPerPage <= 0 
				? 0 
				: $P->{user}{topic}{responseCount} % $postsPerPage == 0 
					? $P->{user}{topic}{responseCount} - $postsPerPage
					: (int($P->{user}{topic}{responseCount}/$postsPerPage) * $postsPerPage)
				#? int(($P->{user}{topic}{responseCount} - $postsPerPage)/$P->{user}{topic}{responseCount})*$postsPerPage + ($P->{user}{topic}{responseCount} % $postsPerPage > 0
		;

warn "OFFSET $responseoffset (".$P->{query}->param('responseoffset')."; $P->{user}{topic}{responseCount});  ".($P->{user}{topic}{responseCount} - $postsPerPage)."; ".($P->{user}{topic}{responseCount}%$postsPerPage)."; ";

		my $i = 0;
		my $firstCurrent = 0;
		while ($i++ * $postsPerPage < $P->{user}{topic}{responseCount}) {
			my $current = 0;
			if ($firstCurrent == 0) {
				if ($responseoffset < $i*$postsPerPage && $responseoffset != $P->{user}{topic}{responseCount} - $postsPerPage) {
					$current = 1;
					$P->{user}{topic}{currentPage} = $i;
					$firstCurrent++;
				} elsif ($i * $postsPerPage >= $P->{user}{topic}{responseCount}) {
					$current = 1;
					$P->{user}{topic}{currentPage} = $i;
					$firstCurrent++;
				}
			}
			push @{$P->{user}{topicPages}}, { pager => { 
				number => $i,
				current => $current,
			}};
		}
		$P->{user}{topic}{currentPage} ||= 0;
		$P->{user}{topic}{lastPage} = $i-1;
		$P->{user}{topic}{onLastPage} = 1 if $P->{user}{topic}{currentPage} == $P->{user}{topic}{lastPage};
#warn Dumper($P->{user}{topic});
#warn "AUTO TOPIC? ".$P->{user}{user}{auto_topics};

		$db_sth{responseBody}->bind_param(1,$topic->{id});
		$db_sth{responseBody}->bind_param(2,$responseoffset, {TYPE => DBI::SQL_INTEGER});
		$db_sth{responseBody}->execute();
		while (my ($response,$id,$date,$minutes,$rid) = $db_sth{responseBody}->fetchrow) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;

			$User->{profile}->{timesince} = $P->{util}->timesince($minutes);
			$User->{profile}->{response} = $response;
			$User->{profile}->{responseId} = $rid;
			$User->{profile}->{date} = $date;
			$User->{profile}->{myprofile} = $P->{user}{profile}{myprofile};

			if ($id == $guserid) {
				$User->{profile}->{currentuser} = 1;
			}

			if ($P->{user}{user}{id} == $P->{user}{profile}{userid}) { $User->{profile}->{myprofile} = 1; }

			util::cleanHtml($User->{profile}->{response});

			push(@{ $P->{user}{responses} },{response => $User->profile,topic=> $P->{user}{topic} });
			$P->{user}{lastresponse} = $User->profile;
		}
	} else {
		$P->{user}{page}{watch} = 0;
	}
	$db_sth{topicCount}->execute($guserid);
	my $total = $db_sth{topicCount}->fetchrow;
	if ($offset + 10 <= $total) {
		if ($offset == 0) {
			$P->{user}{previoustopics}{more} = 11;
		} else {
			$P->{user}{previoustopics}{more} = $offset + 10;
		}
	}
	if ($offset > 0) {
		if ($offset == 11) {
			$P->{user}{previoustopics}{prev} = 0;
		} else {
			$P->{user}{previoustopics}{prev} = $offset - 10;
		}
	}

	if ($P->{user}{meeting}{street}) {
		$P->{user}{prebody}{data} = <<__HTML__;
<script src="http://maps.google.com/maps?file=api&amp;v=2&amp;key=$P->{user}{global}{mapsapikey}" type="text/javascript"></script>
__HTML__
		$P->{user}{postbody}{javascript} = <<__JS__;
map = load();
lookupAddress();
document.body.onunload = function() { GUnload(); };
__JS__
	}


	print processTemplate($P->{user},"meetings/meeting.html");
	return 0;
}

sub edit {
	my $self = shift;
	my $id = shift;


	$self->{user}{date}{today} = strftime("%F",localtime);


	if ($id) {
		$self->{user}{page}{edit} = 1;
		my $sth = $self->{dbh}->prepare("SELECT * FROM events WHERE sponsorId = $self->{user}{user}{id} AND id = $id");
		$sth->execute;
		$self->{user}{meeting} = $sth->fetchrow_hashref;
		#for (values %{$self->{user}{meeting}}) {
		#	$_ = 'N/A' unless length $_;
		#}
		for (qw(name description tag street city state zipcode date)) {
			push @{$self->{user}{fields}}, { field => {name => $_.$id}};
		}
	} else {
		for (qw(name description tag street city state zipcode date)) {
			push @{$self->{user}{fields}}, { field => {name => $_}};
		}
	}

		(undef,$self->{user}{meeting}{time}) = split(" ",$self->{user}{meeting}{date});

	print processTemplate($self->{user},"meetings/edit.html");
	return 0;
}

sub getAttendees {
	my $self = shift;
	my $tag = shift;

	$tag .= '_rsvp';
	# find all users with this event tag
	my $sql = "SELECT r.profileId FROM tagRef r INNER JOIN tag t ON t.id = r.tagId WHERE t.value=?";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute($tag);
	my ($id,@ids);
	$sth->bind_columns(\$id);
	while ($sth->fetchrow_arrayref) {
		push @ids, $id;
	}

	return @ids;
}

sub attending {
	my $self = shift;
	my $tag = shift;
	my $userid = shift || $self->{user}{user}{id};

	$db_sth{attending}->execute($userid,lc($tag).'_rsvp');
	return $db_sth{attending}->rows;
}

sub ical {
	my $self = shift;

	my $myfeed = 0;
	my ($key,$uid);
	if (($key = $self->{query}->param('key')) && ($uid = $self->{query}->param('uid'))) {
		if (my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid)) {
			$self->{user}{user} = $U->profile;
			my $hash = sha1_hex($U->{profile}{username}.'m0reeeeeee*cowbell');
			$myfeed = 1 if ($key eq $hash);

			$myfeed = 2 if $self->{query}->param('peeps');
		}
	}
	$db_sth{list}->execute;
	my %tags;
	while (my $m = $db_sth{list}->fetchrow_hashref) {
		next if $myfeed == 1 && !($self->attending($m->{tag}) || $m->{sponsorId} == $self->{user}{user}{id});

		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $m->{sponsorId}) or next;
		my ($date,$time) = split / /,$m->{date};
		my @date = split /-/,$date;
		my @time = split /:/,$time;
		my $icalDate = Date::ICal->new(
			year => $date[0], month => $date[1], day => $date[2],
			hour => $time[0], min => $time[1], sec => $time[2]
		);
		my $e = Net::ICal::Event->new(
			organizer 	=> Net::ICal::Attendee->new('mailto:events@consumating.com'),
			dtstart		=> Net::ICal::Time->new(ical => $icalDate->ical),
			summary		=> "$m->{name}",
			url			=> "http://www.consumating.com/meetings?id=$m->{id}",
			description	=> $m->{description},
			location	=> "$m->{street} $m->{city}, $m->{state} $m->{zipcode}",

		);
		$tags{lc($m->{tag}).'_rsvp'} = [$m,$U->profile,$e];
	}
	my @finalevents;
	if ($myfeed == 2) {
		# get peeps meetings
		my %sphere = sphere::getSphere($self->{dbh},$self->{user});
		# get their event tags
		my @tags = map {$self->{dbh}->quote($_)} keys %tags;
		my $sth = $self->{dbh}->prepare("SELECT value FROM tagRef r INNER JOIN tag t ON t.id=r.tagId WHERE r.profileId=? AND t.value IN (".join(",",@tags).")");
		my %pevents;
		for my $userid (keys %sphere) {
			$sth->execute($userid);
			while (my $v = $sth->fetchrow) {
				$pevents{lc $v} = $tags{lc $v};
			}
			last if scalar keys %pevents == scalar keys %tags;
		}
		if (scalar keys %pevents) {
			@finalevents = map {$_->[2]} values %pevents;
		}

	} else {
		@finalevents = map {$_->[2]} values %tags;
	}


	my $cal = Net::ICal::Calendar->new(events => \@finalevents);
	print $cal->as_ical;
	return 0;
}

sub prepareQueries {
	my $self = shift;

	%db_sth = (
		attending			=> $self->{dbh}->prepare("SELECT * FROM tagRef r INNER JOIN tag t ON t.id=r.tagId WHERE r.profileId=? AND t.value = ?"),
		list 				=> $self->{dbh}->prepare("SELECT *,(TIME_TO_SEC(TIMEDIFF(events.date,NOW())) / 60) as minutes FROM events WHERE (date IS NULL OR DATE(date) >= DATE_SUB(DATE(NOW()),INTERVAL 7 DAY) OR DATE(date) = '0000-00-00') AND approved=1 ORDER BY date"),
		recent 				=> $self->{dbh}->prepare("SELECT * FROM events WHERE DATE(date) < DATE(NOW()) AND DATE(date) >= DATE_SUB(NOW(),INTERVAL 7 DAY) AND approved=1 ORDER BY date DESC"),

		meeting 			=> $self->{dbh}->prepare("SELECT * FROM events WHERE id = ?"),
		topicbyId			=> $self->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId FROM profileTopic WHERE userId=? AND type='meeting'"),
		lastTopic			=> $self->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId FROM profileTopic WHERE userId=? AND type='meeting' ORDER BY date DESC limit 1"),
		lastEnabledTopic	=> $self->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId FROM profileTopic WHERE userId=? AND type='meeting' AND enabled = 1 ORDER BY date DESC limit 1"),
		getResponses        => $self->{dbh}->prepare("SELECT count(1) as count,max(date) as endDate,(TIME_TO_SEC(TIMEDIFF(NOW(),max(date))) / 60) as minutes FROM profileResponse WHERE profileTopicId=?"),
		responseCount       => $self->{dbh}->prepare("SELECT COUNT(*) FROM profileResponse WHERE profileTopicId=?"),
		responseUsers       => $self->{dbh}->prepare("SELECT DISTINCT userId FROM profileResponse WHERE profileTopicId=? AND userId != ? ORDER BY RAND() LIMIT 8"),
		responseBody        => $self->{dbh}->prepare("SELECT response,userId,date,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes, id AS responseId FROM profileResponse WHERE profileTopicId = ? ORDER BY date ASC LIMIT ?,$postsPerPage"),
		topicCount          => $self->{dbh}->prepare("SELECT COUNT(*) FROM profileTopic WHERE userId = ? AND type='meeting' "),
		oldertopicCount     => $self->{dbh}->prepare("SELECT COUNT(*) FROM profileTopic WHERE userId = ? AND type='meeting' AND id != ?"),
		responses           => $self->{dbh}->prepare("SELECT id AS responseId,response,userId FROM profileResponse WHERE profileTopicId=? ORDER BY date DESC LIMIT 3"),


	);
}
1;
