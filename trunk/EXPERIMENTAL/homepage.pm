package portalize::homepage;


use strict;
 
use Data::Dumper;
use Date::Calc qw(Delta_DHMS Today_and_Now);
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use CGI;
use DBI qw(:sql_types);
use POSIX qw(strftime);


use lib "../lib";
use template2;
use Profiles;
use cache;
use faDates;
use sphere;

our (%db_sth,$guserid,$handle,$dbh);
our $cache = new Cache;

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $dbActive = ref $dbh && $dbh->ping;

	my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
	$P->{user}{global}{imgserver} = "img.consumating.com";
	unless (ref $P) {
		return 0;
	}
    $P->{user}{global}{section} = 'homepage';


	warn "HOMEPAGE PID: $$: $P->{command}";
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

	if ($self->{command} eq "") {
		$self->displayHomepage()
	}


	return 0;
}


sub displayHomepage() {
	my $self = shift;


	# includes:
	# qow, photo contest
	# highlights from channels
	# teaser of my peeps 
	# teaser of my convos


	if ($self->{user}{user}{id}) {

	
	# get new convos, questions, 
	my %sphere = getSphere($self->{dbh},$self->{user});

	my $sql = "(select answer as text,userId,'qow' as type,date from questionresponse where userId in (" . join(",",keys(%sphere)) . "))  union (select question as text,userId,'topic' as type,date from profileTopic where enabled=1 AND userID in (" . join(",",keys(%sphere)) . ")) order by date desc limit 5";

	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	while (my $newstuff = $sth->fetchrow_hashref) {
		$newstuff->{text} =~ s/<.*?>//gsm;
		$newstuff->{text} = util::shortenString($newstuff->{text},100);
		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $newstuff->{userId}) or next;
		push(@{$self->{user}{newstuff}},{content=>$newstuff,user=>$U->profile});
	}

	my $sql = "SELECT topicId FROM topicwatch WHERE userId=?";
	$sth = $self->{dbh}->prepare($sql);
	$sth->execute($self->{user}{user}{id});
	my @watchlist;
	while (my $tid = $sth->fetchrow) {
		push(@watchlist,$tid);
	}

	my $sql = qq|select question,max(profileResponse.date) as latest,count(profileResponse.id) as responses,profileTopic.userId,profileTopic.id FROM profileTopic inner join profileResponse on profileTopic.id=profileResponse.profileTopicId WHERE profileTopic.id in (| . join(",",@watchlist) . qq|) group by profileTopic.id order by latest desc limit 5|;


    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute;
    while (my $newstuff = $sth->fetchrow_hashref) {
        my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $newstuff->{userId}) or next;
		$newstuff->{question} = util::shortenString($newstuff->{question},100);
        $newstuff->{question} =~ s/<.*?>//gsm;
        push(@{$self->{user}{topics}},{topic=>$newstuff,user=>$U->profile});
    }
	
	}


	my $sql = "SELECT * FROM profileChannels WHERE id <= 10 ORDER BY id";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	$sql = "SELECT question,userId,id FROM profileTopic WHERE channelId=? and enabled=1 ORDER BY date DESC limit 1";
	my $getTopic = $self->{dbh}->prepare($sql);
	$sql = "SELECT count(1) FROM profileResponse WHERE profileTopicId=?";
	my $getResponses = $self->{dbh}->prepare($sql);
	
	while (my $channel = $sth->fetchrow_hashref) {

		# get the newest topic
		$getTopic->execute($channel->{id});
		my $topic = $getTopic->fetchrow_hashref;
		$getResponses->execute($topic->{id});
		$topic->{responses} = $getResponses->fetchrow;	
		$topic->{question} =~ s/<.*?>//gsm;
		$topic->{question} = util::shortenString($topic->{question},100);
        my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $topic->{userId}) or next;
		push(@{$self->{user}{channels}},{channel => $channel,topic=>$topic,user=>$U->profile});

	}


	# get contests

	my $sql = "SELECT question,id FROM questionoftheweek ORDER BY date DESC limit 1";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	$self->{user}{question} = $sth->fetchrow_hashref;
	$sth->finish;

    $sql = "SELECT description,id FROM photo_contest WHERE itson=1 ORDER BY startDate DESC  limit 1";  
    $sth = $self->{dbh}->prepare($sql);
    $sth->execute;
    $self->{user}{contest} = $sth->fetchrow_hashref;
    $sth->finish;
	



	print processTemplate($self->{user},"portalize/homepage.html",0,"portalize/outside.html");

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

	my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $guserid);
	%{$P->{user}{profile}} = %{ $User->{profile} };
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
			: $P->{user}{topic}{responseCount} - 25 <= 0 
				? 0 
				: $P->{user}{topic}{responseCount} % 25 == 0 
					? $P->{user}{topic}{responseCount} - 25
					: (int($P->{user}{topic}{responseCount}/25) * 25)
				#? int(($P->{user}{topic}{responseCount} - 25)/$P->{user}{topic}{responseCount})*25 + ($P->{user}{topic}{responseCount} % 25 > 0
		;

warn "OFFSET $responseoffset (".$P->{query}->param('responseoffset')."; $P->{user}{topic}{responseCount});  ".($P->{user}{topic}{responseCount} - 25)."; ".($P->{user}{topic}{responseCount}%25)."; ";

		my $i = 0;
		my $firstCurrent = 0;
		while ($i++ * 25 < $P->{user}{topic}{responseCount}) {
			my $current = 0;
			if ($firstCurrent == 0) {
				if ($responseoffset < $i*25 && $responseoffset != $P->{user}{topic}{responseCount} - 25) {
					$current = 1;
					$P->{user}{topic}{currentPage} = $i;
					$firstCurrent++;
				} elsif ($i * 25 >= $P->{user}{topic}{responseCount}) {
					$current = 1;
					$P->{user}{topic}{currentPage} = $i;
					$firstCurrent++;
				}
			}
			push @{$P->{user}{topicPages}}, { page => { 
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
		$db_sth{responseBody}->bind_param(2,$responseoffset, SQL_INTEGER);
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




			push(@{ $P->{user}{responses} },{response => $User->profile });
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



	print processTemplate($P->{user},"meetings/topics.html");
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
	my $sql = "SELECT r.profileId FROM tagRef r INNER JOIN tag t ON t.id = r.tagId WHERE t.value='$tag'";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
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

	$db_sth{attending}->execute($self->{user}{user}{id},lc($tag).'_rsvp');
	return $db_sth{attending}->rows;
}

sub prepareQueries {
	my $self = shift;

	%db_sth = (
		attending			=> $self->{dbh}->prepare("SELECT * FROM tagRef r INNER JOIN tag t ON t.id=r.tagId WHERE r.profileId=? AND t.value = ?"),
		list 				=> $self->{dbh}->prepare("SELECT *,(TIME_TO_SEC(TIMEDIFF(events.date,NOW())) / 60) as minutes FROM events WHERE DATE(date) >= DATE(NOW()) AND approved=1 ORDER BY date"),
		recent 				=> $self->{dbh}->prepare("SELECT * FROM events WHERE DATE(date) < DATE(NOW()) AND DATE(date) >= DATE_SUB(NOW(),INTERVAL 7 DAY) AND approved=1 ORDER BY date DESC"),

		meeting 			=> $self->{dbh}->prepare("SELECT * FROM events WHERE id = ?"),
		topicbyId			=> $self->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId FROM profileTopic WHERE userId=? AND type='meeting'"),
		lastTopic			=> $self->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId FROM profileTopic WHERE userId=? AND type='meeting' ORDER BY date DESC limit 1"),
		lastEnabledTopic	=> $self->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId FROM profileTopic WHERE userId=? AND type='meeting' AND enabled = 1 ORDER BY date DESC limit 1"),
		getResponses        => $self->{dbh}->prepare("SELECT count(1) as count,max(date) as endDate,(TIME_TO_SEC(TIMEDIFF(NOW(),max(date))) / 60) as minutes FROM profileResponse WHERE profileTopicId=?"),
		responseCount       => $self->{dbh}->prepare("SELECT COUNT(*) FROM profileResponse WHERE profileTopicId=?"),
		responseUsers       => $self->{dbh}->prepare("SELECT DISTINCT userId FROM profileResponse WHERE profileTopicId=? AND userId != ? ORDER BY RAND() LIMIT 8"),
		responseBody        => $self->{dbh}->prepare("SELECT response,userId,date,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes, id AS responseId FROM profileResponse WHERE profileTopicId = ? ORDER BY date ASC LIMIT ?,25"),
		topicCount          => $self->{dbh}->prepare("SELECT COUNT(*) FROM profileTopic WHERE userId = ? AND type='meeting' "),
		oldertopicCount     => $self->{dbh}->prepare("SELECT COUNT(*) FROM profileTopic WHERE userId = ? AND type='meeting' AND id != ?"),
		responses           => $self->{dbh}->prepare("SELECT id AS responseId,response,userId FROM profileResponse WHERE profileTopicId=? ORDER BY date DESC LIMIT 3"),


	);
}
1;
