package talk;

use strict;

use lib qw(. ../lib ../../lib lib);
use template2;
use Profiles;
use CM_Tags;
use sphere;
use Users;
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use Data::Dumper;


my ($dbh);
my $appcount = 0;

our ($getResponses,$getTopic);

my $cache = new Cache;

sub handler :method {
	my $class = shift;
	my $r = shift;
	$r->content_type('text/html');

	my $P = Profiles->new(request => $r, cache => $cache);

	return (OK) unless defined $P;

	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> query->new($r),
	};
	bless $self, $class;

	$self->{command} = $P->{command};



	$self->{user}{system}{tab} = 'Conversations';

	$getResponses = $self->{dbh}->prepare("SELECT count(1) FROM profileResponse WHERE profileTopicId=?");
	$getTopic = $self->{dbh}->prepare("SELECT profileTopic.* from profileTopic  WHERE profileTopic.id=?");

	if ($self->{command} eq "" || $self->{command} eq "/mine") {
		showMyConversations($self);
	} elsif ($self->{command} eq "/all") {
		showAllConversations($self);
	} elsif ($self->{command} eq '/search') {
		showSearch($self);
	} elsif ($self->{command} eq "/channel") {
		showChannel($self);
	} elsif ($self->{command} eq "/history") {
		showHistory($self);
	}


}



sub showChannel {
	my ($P) = @_;
	
	my $page  = $P->{query}->param('page') || 0;
	my $offset = $page * 20;
	my $channelId = $P->{query}->param('id');
	my $getTopics = $P->{dbh}->prepare("SELECT * FROM profileTopic WHERE channelId=? AND enabled=1 and type='profile' ORDER BY date DESC limit $offset,20;");
	$getTopics->execute($channelId);
    my $getResponses = $P->{dbh}->prepare("SELECT (TIME_TO_SEC(TIMEDIFF(NOW(),max(profileResponse.date))) / 60) as minutes,count(profileResponse.id) as responses FROM profileResponse WHERE profileTopicId=?");
    my $getWatchlist = $P->{dbh}->prepare("SELECT count(1) FROM topicwatch WHERE topicId=? and userId=?");
            
	my $getCount = $P->{dbh}->prepare("SELECT count(1) FROM profileTopic WHERE channelId=? AND enabled=1 and type='profile'");
	$getCount->execute($channelId);
	my $totalTopics = $getCount->fetchrow;
	my $pages = int($totalTopics / 20);
	if ($totalTopics % 20 > 0) {
		$pages++;
	}


	warn "There are $pages pages of topics ($totalTopics total)";
	$pages--;
	if ($pages > 0) {
	foreach (0 .. $pages) {

		my $thispage;
		$thispage->{page} = $_ + 1;
		$thispage->{offset} = $_;
		$thispage->{channelId} = $channelId;
		if ($page == $_) {
			$thispage->{current} = 1;
		}
		push(@{$P->{user}{pages}},{thispage =>$thispage});
	
	}
	}


	while (my $topic = $getTopics->fetchrow_hashref) {

                $getResponses->execute($topic->{id});
                my $response = $getResponses->fetchrow_hashref;
                my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;
                $topic->{question} =~ s/<.*?>//gsm;
                $topic->{responses} = $response->{responses};
                $topic->{minutes} = $response->{minutes};
                $topic->{timesince} = $P->{util}->timesince($response->{minutes});
                $User->{profile}{type}='topic';
                $User->{profile}{date} = $topic->{date};
                if ($P->{user}{user}{id}) {
                    $getWatchlist->execute($topic->{id},$P->{user}{user}{id});
                    $topic->{watched} = $getWatchlist->fetchrow;
                } else {
                    $topic->{watched} = 0;
                }
				util::cleanHtml($topic->{question},'everything');
                push(@{$P->{user}{topics}},{topic => $topic,profile=>$User->profile});
	}


    # load topic channels
        {   
			my $getChannels = $P->{dbh}->prepare("SELECT name,promo,id FROM profileChannels ORDER BY id");
			$getChannels->execute;
            while (my $channel = $getChannels->fetchrow_hashref) {
				if ($channel->{id} == $channelId) {	
					$channel->{current} = 1;
					$P->{user}{thischannel} = $channel;
				}

                push(@{$P->{user}{profileChannels}},{channel => $channel});
            }
        }


	print processTemplate($P->{user},"talk/channels.html");

	return (OK);

}



sub showMyConversations {

	my ($P) = @_;

	$P->{user}{page}{title} = qq|Talk To People Who Don't Suck|;
	if ($P->{command} eq "" && !$P->{user}{user}{id}) {
		$P->{req}->headers_out->set(Location => "/talk/all");
		return (REDIRECT);
	}


	my %shown;
	$shown{0} = 1;
	$shown{1} = 1;

	my $now = time();
	my $cutoff;

	if ($P->{user}{user}{id}) {

		if ($P->{query}->cookie('conversationslastvisit')) {
			$cutoff = $P->{query}->cookie('conversationslastvisit');
		} else {
			$cutoff = $now - (30 * 60);
		}

		$P->{user}{page}{minutessincelastvisit} = sprintf("%d",(int($now - $cutoff) / 60) + 5);
		if ($P->{user}{page}{minutessincelastvisit} > 720) {
				$P->{user}{page}{minutessincelastvisit} = 720;
		} 

		my %convos;
		my $getMyLatestComment = $P->{dbh}->prepare("SELECT date FROM profileResponse WHERE profileTopicId=? AND userId=? ORDER BY id DESC LIMIT 1");
		my $sth = $P->{dbh}->prepare("SELECT topicId,date FROM topicwatch WHERE userId=?");
		$sth->execute($P->{user}{user}{id});
		while (my ($id,$date) = $sth->fetchrow_array) {
			
			$getMyLatestComment->execute($id,$P->{user}{user}{id});
			my $cdate = $getMyLatestComment->fetchrow;
			$convos{$id}{date} = $date;
			$convos{$id}{date} = $cdate if ($cdate gt $date);
			if (!$cdate) {
				$convos{$id}{watchonly} = 1;
			}
			$shown{$id} = 1;

		}
		$sth->finish;

		my $sql;
		if(0){
		$sql = "SELECT id FROM profileTopic WHERE userId=$P->{user}{user}{id} AND enabled=1 and type='profile' ORDER BY date DESC limit 1";
		$sth=$P->{dbh}->prepare($sql);
		$sth->execute;
		if (my $id = $sth->fetchrow) {
			$convos{$id}{date} = 1;
		}
		$sth->finish;
		}

		my $getNewComments = $P->{dbh}->prepare("SELECT COUNT(*),(TIME_TO_SEC(TIMEDIFF(NOW(),MAX(date))) / 60) AS minutes FROM profileResponse WHERE profileTopicId=? AND date > ?");
		my $getMostRecent = $P->{dbh}->prepare("SELECT (TIME_TO_SEC(TIMEDIFF(NOW(),max(date))) /60) as minutes FROM profileResponse WHERE profileTopicId=?");
		my $getNewCommentsSinceVisit = $P->{dbh}->prepare("SELECT * FROM profileResponse WHERE profileTopicId=? AND date > DATE_SUB(NOW(),INTERVAL $P->{user}{page}{minutessincelastvisit} MINUTE) ORDER BY date");
		my $expireWatch = $P->{dbh}->prepare("DELETE FROM topicwatch WHERE topicId=? AND userId=?");
		my %userObjects;
		foreach my $cid (sort keys %convos) {
			$getTopic->execute($cid);
			my $topic = $getTopic->fetchrow_hashref;
			next unless $topic->{id};
			$topic->{question} =~ s/<.*?>//gsm;

			$getNewComments->execute($cid,$convos{$cid}{date});
			my ($cc,$minutes) = $getNewComments->fetchrow;
			$topic->{watchonly} = $convos{$cid}{watchonly};
			$topic->{responses} = $cc;

			$getResponses->execute($cid);
			$topic->{totalresponses} = $getResponses->fetchrow;
			$topic->{timesince} = $P->{util}->timesince($minutes);
			$topic->{minutes} = $minutes;
		
			if ($cc == 0) {
				$getMostRecent->execute($cid);
				$minutes = $getMostRecent->fetchrow || 0;
				$topic->{timesince} = $P->{util}->timesince($minutes);
				$topic->{minutes} = $minutes;
				
			}


	# expire closed topics from the watchlist after a day or two...
			if ($topic->{enabled} == 0) {
				#if ($topic->{minutes} > 2880) {
					$topic->{expired} = 1;
					#$expireWatch->execute($topic->{id},$P->{user}{user}{id});
				#}
			}

			my $recentReply = 0;
			if ($cc > 0) {
				$getNewCommentsSinceVisit->execute($cid);
				my $ccount = 0;
				while (my $comment = $getNewCommentsSinceVisit->fetchrow_hashref)  {
					my $User;
					unless ($userObjects{$comment->{userId}}) {
						$User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $comment->{userId}) or next;
						$userObjects{$comment->{userId}} = $User;
					} else {
						$User = $userObjects{$comment->{userId}};
					}
					if ($comment->{response} =~ /\@$P->{user}{user}{handle}/) {
						$recentReply++;
					}
					push @{$topic->{comments}}, {comment => $comment,profile=>$User->profile};
				}
			}
			
			$shown{$topic->{id}} = 1;
			if ($recentReply) {
				push(@{ $P->{user}{repliesunsorted} },{topic =>$topic});
			} else {
				push(@{ $P->{user}{mytopicsunsorted} },{topic =>$topic});
			}
		}
		$getNewComments->finish;
		
		if(!$P->{user}{mytopicsunsorted}) {
			$P->{user}{mytopicsunsorted} = [];
		}
		if(!$P->{user}{repliesunsorted}) {
			$P->{user}{repliesunsorted} = [];
		}

		my $getMeeting = $P->{dbh}->prepare("SELECT * FROM events WHERE id=?");

		if (scalar(@{$P->{user}{repliesunsorted}}) > 0) {
			foreach my $cid (sort { $a->{topic}{minutes} <=> $b->{topic}{minutes} } @{ $P->{user}{repliesunsorted} }) {

					my ($User,$meeting);
					if ($cid->{topic}{type} eq "profile") {
						$User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $cid->{topic}{userId}) or next;
					} elsif ($cid->{topic}{type} eq "meeting") {
						$getMeeting->execute($cid->{topic}{userId});
						$meeting = $getMeeting->fetchrow_hashref;
						$User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $meeting->{sponsorId}) or next;	
					}
		
					util::cleanHtml($cid->{topic}{question},'everything');
					push(@{ $P->{user}{replies} },{profile => $User->profile, topic => $cid->{topic},comments=>$cid->{topic}{comments},meeting=>$meeting});
					$shown{$cid->{topic}{id}} = 1;

			}
		}
		if (scalar(@{$P->{user}{mytopicsunsorted}}) > 0) {
			foreach my $cid (sort { $a->{topic}{minutes} <=> $b->{topic}{minutes} } @{ $P->{user}{mytopicsunsorted} }) {

					my ($User,$meeting);
					if ($cid->{topic}{type} eq "profile") {
						$User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $cid->{topic}{userId}) or next;
					} elsif ($cid->{topic}{type} eq "meeting") {
						$getMeeting->execute($cid->{topic}{userId});
						$meeting = $getMeeting->fetchrow_hashref;
						$User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $meeting->{sponsorId}) or next;	
					}
		
					util::cleanHtml($cid->{topic}{question},'everything');
					push(@{ $P->{user}{mytopics} },{profile => $User->profile, topic => $cid->{topic},comments=>$cid->{topic}{comments},meeting=>$meeting});
					$shown{$cid->{topic}{id}} = 1;

			}
		}

		my %sphere = getSphere($P->{dbh},$P->{user});

		if (scalar(%sphere) > 0) {
			$sql = qq|SELECT * FROM profileTopic WHERE enabled=1 and type='profile' AND profileTopic.userId IN (| . join(",",keys(%sphere)) . qq|) |
					. qq|AND profileTopic.id NOT IN (| .  join(",",keys(%shown)) . qq|) ORDER BY date DESC LIMIT 10|;
			$sth = $P->{dbh}->prepare($sql);
			$sth->execute;
			while (my $topic = $sth->fetchrow_hashref) {
				my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;
				$getResponses->execute($topic->{id});
				$topic->{responses} = $getResponses->fetchrow;
				util::cleanHtml($topic->{question},'everything');
				push(@{ $P->{user}{peepstopics} },{ profile => $User->profile, topic=>$topic});
				$shown{$topic->{id}} = 1;
			}
			$sth->finish;
		}


	}


	hotTopics($P,\%shown,$getTopic);

	mostRecent($P,\%shown,$getResponses);

    # load topic channels
        {   
            my $getChannels = $P->{dbh}->prepare("SELECT name,id FROM profileChannels ORDER BY id");
            $getChannels->execute;
            while (my $channel = $getChannels->fetchrow_hashref) {
                push(@{$P->{user}{profileChannels}},{channel => $channel});
            }
        }



	my $lastvisit = $P->{query}->cookie(-name=>'conversationslastvisit',-value=>$now);

	$P->{req}->headers_out->add('Set-Cookie' => "conversationslastvisit=$now; path=/; domain=.consumating.com;");
	print processTemplate($P->{user},'talk/index.html');

	return (OK);
}

sub showAllConversations {
	my ($P) = @_;

	$P->{user}{page}{title} = qq|Talk To People Who Don't Suck|;
warn "PAGE TITLE: ".$P->{user}{page}{title};

	my %shown = ();

	# load new / hot / interesting conversations



    # load topic channels
        {   
            my $getChannels = $P->{dbh}->prepare("SELECT name,id FROM profileChannels ORDER BY id");
            $getChannels->execute;
            while (my $channel = $getChannels->fetchrow_hashref) {
                push(@{$P->{user}{profileChannels}},{channel => $channel});
            }
        }



	# get this persons active conversations so we don't show them.
	if ($P->{user}{user}{id}) {
		my $sql = "SELECT distinct(profileTopicId) from profileResponse WHERE userId=$P->{user}{user}{id}";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		my $cid;
		$sth->bind_columns(\$cid);
		while ($sth->fetchrow_arrayref) {
			$shown{$cid} = 1;
		}
	} else {
		$shown{1} = 1;
	}

	if (keys(%shown) == 0) {
		$shown{1} = 1;
	}

	hotTopics($P,\%shown,$getTopic);


	# hot posters
	{
		my $sql = "SELECT userId,COUNT(*) FROM profileResponse WHERE date >= DATE_SUB(NOW(),INTERVAL 3 DAY) GROUP BY userId ORDER BY 2 DESC";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		my %s;
		while (my ($id,$count) = $sth->fetchrow) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $id) or next;
			next if $s{$User->{profile}->{sex}};
			$s{$User->{profile}->{sex}}=1;
			$User->{profile}->{responseCount} = $count;
			push(@{ $P->{user}{hotTalkers}},{profile => $User->profile});
			last if scalar keys %s == 2;
		}
	}


	my $newlimit = 10;

	if ($P->{user}{user}{id}) {
		my %sphere = getSphere($P->{dbh},$P->{user});

		my $sql = qq|SELECT * FROM profileTopic WHERE enabled=1 AND type='profile' AND profileTopic.userId IN (| . join(",",keys(%sphere)) . qq|) AND profileTopic.id NOT IN (| .  join(",",keys(%shown)) . qq|) ORDER BY date DESC LIMIT 5|;
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $topic = $sth->fetchrow_hashref) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;
			$getResponses->execute($topic->{id});
			$topic->{responses} = $getResponses->fetchrow;
			$topic->{question} = shortenHeadline($topic->{question});
			util::cleanHtml($topic->{question},'everything');
			push(@{ $P->{user}{peepstopics}},{profile => $User->profile,topic=>$topic});
			$shown{$topic->{id}} = 1;
		}
		$sth->finish;
		if (ref $P->{user}{peepstopics}) {
			$newlimit = $newlimit - scalar @{ $P->{user}{peepstopics}};
		}
	}



	# get most recent user topics

	{   

		my $sql = qq|select * from profileTopic WHERE enabled=1 AND type='profile' AND profileTopic.id NOT IN (| . join(",",keys(%shown)) . qq|) and enabled=1 ORDER BY date DESC limit $newlimit;|;
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $topic = $sth->fetchrow_hashref) {
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;
			$getResponses->execute($topic->{id});
			$topic->{responses} = $getResponses->fetchrow;
			$topic->{question} = shortenHeadline($topic->{question});
			$shown{$topic->{id}} = 1;
			util::cleanHtml($topic->{question},'everything');
			push(@{ $P->{user}{topics}},{profile=>$User->profile,topic => $topic});
		}    $sth->finish;
	}

	print processTemplate($P->{user},'talk/all.html');
	return (OK);
}

sub showSearch {
	my ($P) = @_;

	my @terms = @{$P->{util}->parseSearchString($P->{query}->param('query'))};

	$P->{user}{page}{title} = 'Search conversations for '.join(', ',@terms);

    foreach my $term (@terms) {
		my %term;
		$term{tag} = $term;
		$term{term} = $term;
		$term{tag} =~ s/\s//g;
		push(@{ $P->{user}{terms}},{term=>\%term});
	}
	my $q = $P->{query}->param('query');
	$q =~ s/\"/&quot;/g;
	$P->{user}{page}{query} = $q; 


	my $params = join ' AND ', map{"LIKE '%$_%'"}@{$P->{util}->parseSearchString($P->{query}->param('query'))};

	(my $qparams = $params) =~ s/LIKE/question LIKE/g;
	(my $rparams = $params) =~ s/LIKE/response LIKE/g;
	
	my $sql;

	unless ($P->{query}->param('tagonly')) {
		$sql = "SELECT id,userId,question,NULL AS response,enabled,date,'question' AS type FROM profileTopic WHERE $qparams ";
		$sql   .= "UNION SELECT profileTopicId AS id,t.userId,t.question,r.response,t.enabled,t.date,'response' AS type FROM profileResponse r INNER JOIN profileTopic t ON t.id=r.profileTopicId WHERE $rparams UNION ";
	}
	$sql   .= "SELECT p.id, p.userId, question, NULL AS response, enabled, p.date,'tag' AS type FROM tag t INNER JOIN topicTagRef tt ON t.id=tt.tagId INNER JOIN profileTopic p ON tt.topicId=p.id WHERE t.value IN ('".join("','",@terms)."')";
warn "$sql;";

	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	my %convos = map {$_->{id} => $_} @{$sth->fetchall_arrayref({})};

	$sth->finish;


	my $offset = $P->{query}->param('offset') || 0;


	my $totalresults = 0;


	my %shown;
	$shown{0} = 1;
	my $count=0;
	my $acount = 0; # for the archived conversations
	my $i=0;

	my $taglookup = $P->{dbh}->prepare("SELECT t.value FROM tag t INNER JOIN topicTagRef r ON r.tagId=t.id WHERE r.topicId=? AND t.value IN ('".join("','",@terms)."')");

	foreach my $cid (sort {$convos{$b}->{enabled} <=> $convos{$a}->{enabled} || $convos{$b}->{type} <=> $convos{$a}->{type} || $convos{$b}->{date} cmp $convos{$a}->{date} } keys %convos) {
		next if $i++ < $offset;
		$totalresults++;
		my $topic = $convos{$cid};
		$getResponses->execute($cid);
		$topic->{totalresponses} = $getResponses->fetchrow;

		$topic->{question} = shortenHeadline($topic->{question});
		foreach my $term (@terms) {
			$topic->{question} =~ s/($term)/<span class="highlight">$1<\/span>/gism;
			$topic->{response} =~ s/($term)/<span class="highlight">$1<\/span>/gism;
		}

		util::cleanHtml($topic->{question},'everything');

		if ($topic->{type} eq 'tag') {
			$taglookup->execute($topic->{id});
			$topic->{tag} = join(', ',map{$_->{value}} @{$taglookup->fetchall_arrayref({})});
		}

		
		my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;

		if ($topic->{enabled} == 1) {
			$count++;
			push(@{ $P->{user}{livetopics} } ,{profile => $User->profile,topic=>$topic});
		} else {
			$acount++;
			push(@{ $P->{user}{archivedtopics}},{profile=>$User->profile,topic=>$topic});
		}
		$shown{$topic->{id}} = 1;
		last if ($count+$acount) == 10;
	}

	if (scalar keys %convos > 20) {
		$P->{user}{search}{more} = $offset == 0 ? 11 : $offset+10;
	}
	$P->{user}{search}{query} = $P->{query}->param('query');
	
	if ($totalresults == 0) {
		$P->{user}{page}{noresults} = 1;
	}

	hotTopics($P,\%shown,$getTopic);
	mostRecent($P,\%shown,$getResponses);
	

	print processTemplate($P->{user},'talk/search.html');
	return (OK);
}


sub showHistory {
	my ($P) = @_;

	# load up every conversation this person has participated in, one day at a time.
	my $offset = $P->{user}{page}{offset} = $P->{query}->param('offset') || 1;

	my $mode = $P->{query}->param('mode') || 'participate';

	if ($offset == 1) {
		$P->{user}{conversations}{day} = 'TODAY';
	} else {
		if ($offset == 2) {
			$P->{user}{conversations}{day} = "YESTERDAY";
		} else {
			$P->{user}{conversations}{day} = ($offset-1).' DAYS AGO';
			if ($offset == 5 || $offset == 6) {
				$P->{user}{page}{old} = 1;
			} elsif ($offset > 6) {
				$P->{user}{page}{older} = 1;
				$P->{user}{page}{prevday2} = $offset-2;
				$P->{user}{page}{nextday2} = $offset+2;
			}
		}
		$P->{user}{page}{prevday} = $offset-1;
	}
	$P->{user}{page}{nextday} = $offset+1;

	$P->{user}{page}{mode} = $mode;


	my $where;
	if ($mode eq 'peeps') {
		my %sphere = getSphere($P->{dbh},$P->{user});
		$where = "userId IN (".join(',',keys %sphere).")";
	} elsif ($mode eq 'participate') {
		$where = "userId=$P->{user}{user}{id}";
	} else { # mode eq 'all'
		$where = "1=1";
	}

	my $sql = "SELECT profileTopicId,date FROM profileResponse WHERE $where AND date > DATE_SUB(NOW(),INTERVAL $offset DAY) "
		 . ($offset > 1 ? "AND date < DATE_SUB(NOW(),INTERVAL ".($offset-1)." DAY) " : '')
		 . "UNION SELECT topicId,date FROM topicwatch WHERE $where AND date > DATE_SUB(NOW(),INTERVAL $offset DAY) " 
		 . ($offset > 1 ? "AND date < DATE_SUB(NOW(),INTERVAL ".($offset-1)." DAY) " : ''). " ORDER BY date ASC";


	my %convos = map {$_->[0] => $_->[1]} @{$P->{dbh}->selectall_arrayref($sql)};

# ok, now we have all the info for this week.  we need to break them down into day pots and load the profile info, etc.

	my $loadConvo = $P->{dbh}->prepare("SELECT * FROM profileTopic WHERE id=?");

	my %shown;
	my $watch = $P->{dbh}->prepare("SELECT * FROM topicwatch WHERE topicId=?");
	foreach my $cid (sort {$convos{$b} cmp $convos{$a}} keys %convos) {

		$loadConvo->execute($cid);
		my $convo = $loadConvo->fetchrow_hashref;
		$convo->{question} = shortenHeadline($convo->{question});
		my $User  = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $convo->{userId}) or next;

		$watch->execute($cid);
		$convo->{watched} = $watch->rows;

		push(@{$P->{user}{day}},{topic => $convo,profile=>$User->profile});
		$shown{$cid}=1;

	}
	$watch->finish;
	
	hotTopics($P,\%shown,$getTopic);

	mostRecent($P,\%shown,$getResponses);

	print processTemplate($P->{user},"talk/history.html");
	return (OK);
}


sub shortenHeadline {
	my ($headline) = @_;


	$headline =~ s/<.*?>//gsm;
	if (length($headline) > 128) {
		$headline =~ /(.{100,125}.+?\b).*/s;
		return $1."...";
	} else {
		return $headline;
	}
}

sub hotTopics {
	my $P = shift;
	my $shown = shift;
	my $getTopic = shift;

    my $sql = qq|SELECT DISTINCT(profileTopicId) AS profileTopicId, (TIME_TO_SEC(TIMEDIFF(NOW(),max(profileResponse.date))) / 60) AS minutes,COUNT(profileResponse.id) AS responses |
			. qq|FROM profileResponse inner join profileTopic on profileResponse.profileTopicId=profileTopic.id  WHERE profileResponse.date > DATE_SUB(NOW(),INTERVAL 4 HOUR) AND profileTopic.type='profile' AND  profileTopic.enabled = 1 AND profileTopicId NOT IN (| . join(",",keys(%$shown)) . qq|) |
			. qq|GROUP BY profileTopicId ORDER BY responses DESC LIMIT 20;|;

    my $sth = $P->{dbh}->prepare($sql);
    $sth->execute;

	my $chk = $P->{dbh}->prepare("SELECT DISTINCT userId FROM profileResponse WHERE profileTopicId = ?");

    while (my $responses = $sth->fetchrow_hashref) {
		$getTopic->execute($responses->{profileTopicId});
		my $topic = $getTopic->fetchrow_hashref;
		next unless $topic->{id};

		# check the number of users in the topic compared to the total number of responses
		# if total users in conv < 1/3 total responses, then it's not so hot.
		$chk->execute($topic->{id});
		my $rows = $chk->rows;
		next if ($rows < $responses->{responses}/3);


		my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;
	    $topic->{responses} = $responses->{responses};
		$topic->{question} = shortenHeadline($topic->{question});
		$topic->{minutes} = $responses->{minutes};
		$topic->{timesince} = $P->{util}->timesince($responses->{minutes});
		$shown->{$topic->{id}} = 1;
		util::cleanHtml($topic->{question},'everything');
		push(@{ $P->{user}{hottopics}},{profile => $User->profile,topic=>$topic});
		last if $#{$P->{user}{hottopics}} == 10;
    }
	$sth->finish;
}

sub mostRecent {
	my $P = shift;
	my $shown = shift;
	my $getResponses = shift;

	my $sql = qq|SELECT * FROM profileTopic WHERE type='profile' AND enabled=1 AND profileTopic.id NOT IN (| . join(",",keys(%$shown)) . qq|) |
			. qq|AND enabled=1 ORDER BY date DESC limit 5|;
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	while (my $topic = $sth->fetchrow_hashref) {
		my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;
		$getResponses->execute($topic->{id});
		$topic->{responses} = $getResponses->fetchrow;
		$topic->{question} = shortenHeadline($topic->{question});
		util::cleanHtml($topic->{question},'everything');
		push(@{ $P->{user}{topics}},{profile => $User->profile,topic=>$topic});
	}
	$sth->finish;
}
