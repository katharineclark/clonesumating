package homepage;
use strict;
 
use Data::Dumper;
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use CGI;
use DBI qw(:sql_types);

use lib "lib";
use Profiles;
use util;
use template2;
use sphere;
use List::Util qw(shuffle);
use video::videoEgg;

our ($dbh);
our $cache = new Cache;

# these are db_sth type things. # too lazy to do it the right way right now.
our ($getTopic, $getTopicById , $watchList, $getResponses, $getContest ,
$getEntry, $getBlings, $getQuestion, $getQuestionById, $getAnswer,
$getQBlings, $getThumbs, $getTags, $getHotTags, $getPhotoDims, $getDowns,
$getMyBling, $getWatchlist);

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $dbActive = ref $dbh && $dbh->ping;

	my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
	unless (ref $P) {
		return (OK);
	}
	$P->{user}{system}{tab} = 'Home';

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

	$self->prepareQueries unless ($dbActive);

	$self->default;
}


sub randomtags {
	my @tagsets = shuffle(['zombies','videogames','comics','music'],['books','glasses','blogging','geeks'],['fashion','apple','sushi','sarcasm']);
	
	return @{$tagsets[0]};
}

sub default {
	my ($P) = shift;


	$P->{user}{page}{dashtab} = $P->{query}->cookie('dashtab') || "featuredpeople";

# GET HOT TOPICS / TAGS / CONVERSATIONS

	foreach my $tag (randomtags()) {
	
		push(@{$P->{user}{randomtags}},{tag => {value => $tag}});

	}
	my @ignore;
	push(@ignore,0);
	$getDowns->execute($P->{user}{user}{id});
	while (my $uid = $getDowns->fetchrow) {
		push(@ignore,$uid);
	}



    my $getHotAnswers = $P->{dbh}->prepare("SELECT r.id,answer,videoId,photoId,r.userId,questionId,count(b.userId) AS count FROM bling b "
			."INNER JOIN questionresponse r ON r.id=b.questionResponseId WHERE r.nsfw = 0 AND b.type='U' AND "
			."b.insertDate >= DATE_SUB(NOW(),INTERVAL 4 HOUR) AND r.userId NOT IN (" . join(",",@ignore) . ") GROUP BY r.id ORDER BY count DESC LIMIT 10");

	$getHotTags->execute;
	while (my $tag = $getHotTags->fetchrow_hashref) {	
		push(@{ $P->{user}{hottags} },{tag => $tag});
	}

	my %hotpeeps;
	$getHotAnswers->execute;
	while (my $answer = $getHotAnswers->fetchrow_hashref) {
		next if $hotpeeps{$answer->{userId}};
		$hotpeeps{$answer->{userId}} = 1;
  		my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $answer->{userId}) or next;
		$getQuestionById->execute($answer->{questionId});
		my $question = $getQuestionById->fetchrow_hashref;
		if (0 && $answer->{photoId} > 0) {
			$getPhotoDims->execute($question->{photoId});
			my ($width,$height) = $getPhotoDims->fetchrow;
			if ($width == 400) {
				$answer->{answer} =  qq|<a href='/picture.pl?id=$answer->{photoId}'><div style="background: url('http://img.consumating.com/photos/$User->{profile}{userid}/large/$$answer{photoId}.jpg') 0% 5% repeat;height:150px;border:2px solid #666;cursor:hand;cursor:pointer;" /></div></a><br clear="all" />| . $answer->{answer};
			} else {
				$answer->{answer} =  qq|<a href='/picture.pl?id=$answer->{photoId}'><img src="http://img.consumating.com/photos/$User->{profile}{userid}/large/$$answer{photoId}.jpg" class="qow_illustration" height='$height' width='$width'/></a><br clear="all" />| . $answer->{answer};
			}
		}
		if ($answer->{videoId} > 0) {
			my $ve = video::videoEgg->new(dbh => $P->{dbh},user => $P->{user});
			my $path = $ve->video($answer->{videoId});
			$answer->{answer} = qq|<div style="float: left; background: #333; color: #FFF; text-align: center; font-weight: bold; margin-right: 10px;" class="small"><a href="/profiles/$User->{profile}{linkhandle}#$answer->{id}"><script language="javascript">videoEgg.drawThumb("$path");</script></a><br />video</div>$answer->{answer}|;
			$P->{user}{page}{videoEgg} ||= 1;
		}
		$getMyBling->execute($answer->{id},$P->{user}{user}{id});
		$answer->{bling} = $getMyBling->fetchrow;
		$User->{profile}{type} ='question';
		push(@ignore,$User->{profile}{userId});
		push(@{ $P->{user}{hotpeeps} },{profile =>$User->profile,answer=>$answer,question=>$question});
		push(@{ $P->{user}{hotanswers} },{answer=>$answer,question=>$question,profile=>$User->profile});
		last if scalar @{$P->{user}{hotanswers}} == 5;
	}


	# hot topics
	{
			
		my $sql = qq|select distinct(profileTopicId) as profileTopicId, (TIME_TO_SEC(TIMEDIFF(NOW(),max(r.date))) / 60) as minutes,count(*) as responses from profileResponse r inner join profileTopic t on r.profileTopicId=t.id WHERE t.nsfw = 0 && r.date > DATE_SUB(NOW(),INTERVAL 4 HOUR) AND t.type='profile' and t.enabled=1 AND t.channelId not in (2,10) AND t.userId NOT IN (| . join(",",@ignore) . qq|) group by r.profileTopicId order by responses desc limit 10;|;
		
		my $chk = $P->{dbh}->prepare("SELECT DISTINCT userId FROM profileResponse WHERE profileTopicId = ?");
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $responses = $sth->fetchrow_hashref) {
			$getTopicById->execute($responses->{profileTopicId});
			my $topic = $getTopicById->fetchrow_hashref;
			next if $hotpeeps{$topic->{userId}};


			# check the number of users in the topic compared to the total number of responses
			# if total users in conv < 1/3 total responses, then it's not so hot.
			$chk->execute($topic->{id});
			my $rows = $chk->rows;
			next if ($rows < $responses->{responses}/3);



			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $topic->{userId}) or next;
			$topic->{question} =~ s/<.*?>//gsm;
			$topic->{responses} = $responses->{responses};
			$topic->{minutes} = $responses->{minutes};
			$topic->{timesince} = $P->{util}->timesince($responses->{minutes});
			$User->{profile}{type}='topic';
			if ($P->{user}{user}{id}) {
				$getWatchlist->execute($topic->{id},$P->{user}{user}{id});
				$topic->{watched} = $getWatchlist->fetchrow;
			} else {
				$topic->{watched} = 0;
			}
			push(@{ $P->{user}{hotpeeps} },{profile=>$User->profile,topic=>$topic});
			push(@{ $P->{user}{hottopics} },{profile => $User->profile,topic=>$topic});
			last if scalar @{$P->{user}{hottopics}} == 5;
		}
	}

	@{$P->{user}{hotpeeps}} = 
	map $_->[0] =>
	sort {$b->[1] <=> $a->[1] }
	map [ $_, $_->{profile}{popularity}] => @{$P->{user}{hotpeeps}};





   # get contest entrants
    {
            my $sql = qq|SELECT userId,photoId FROM photo_contest_entry WHERE contestId = (SELECT MAX(id) FROM photo_contest WHERE itson=1 AND startDate <= NOW() ORDER BY startDate DESC LIMIT 1) ORDER BY RAND() LIMIT 8|;
            my $entries = $P->{dbh}->prepare($sql);
        	$entries->execute;
        while (my ($uid,$pid) = $entries->fetchrow_array) {

            my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or next;
            $User->{profile}->{photoId} = $pid;
            push(@{ $P->{user}{photocontestentries} },{profile => $User->profile});

        }
    }












# conversations

	$getTopic->execute($P->{user}{user}{id});
	if ($P->{user}{topic} = $getTopic->fetchrow_hashref) {

		$P->{user}{topic}{question} = util::shortenString($P->{user}{topic}{question},70);
		$getResponses->execute($P->{user}{topic}{id});
		$P->{user}{topic}{responses} = $getResponses->fetchrow;

	}


# profile thumbs
	$getThumbs->execute($P->{user}{user}{id},'U');
	$P->{user}{thumbs}{up} = $getThumbs->fetchrow;
	$getThumbs->execute($P->{user}{user}{id},'D');
	$P->{user}{thumbs}{down} = $getThumbs->fetchrow;


# tags

	$getTags->execute($P->{user}{user}{id});
	while (my $tag = $getTags->fetchrow_hashref) {
	    my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $tag->{addedById}) or next;
		($User->{profile}{jshandle} = $User->{profile}{eschandle}) =~ s/'/\\'/g;
		push(@{$P->{user}{newtags}},{tag => $tag,profile=>$User->profile});
	}
	

# photo contest
	$getContest->execute;
	$P->{user}{contest} = $getContest->fetchrow_hashref;
	$getEntry->execute($P->{user}{user}{id},$P->{user}{contest}{id});
	if ($P->{user}{entry} = $getEntry->fetchrow_hashref) {
		$getBlings->execute($P->{user}{entry}{id},'U');
		$P->{user}{entry}{ups} = $getBlings->fetchrow;
		$getBlings->execute($P->{user}{entry}{id},'D');
		$P->{user}{entry}{downs} = $getBlings->fetchrow;
	}


# QOW
	
	$getQuestion->execute;
	$P->{user}{question} = $getQuestion->fetchrow_hashref;
    #$P->{user}{question}{question} = util::shortenString($P->{user}{question}{question},70);
	$getAnswer->execute($P->{user}{user}{id},$P->{user}{question}{id});
	if ($P->{user}{answer} = $getAnswer->fetchrow_hashref) {
		$getQBlings->execute($P->{user}{answer}{id},'U');
		$P->{user}{answer}{ups} = $getQBlings->fetchrow;
        $getQBlings->execute($P->{user}{answer}{id},'D');
        $P->{user}{answer}{downs} = $getQBlings->fetchrow;
	}

# peeps history

    my %sphere = getSphere($P->{dbh},$P->{user});
	my $count = 0;
    foreach my $uid (sort {$sphere{$b}{'actionTime'} cmp $sphere{$a}{'actionTime'}} keys %sphere) {
            if ($sphere{$uid}{reason} eq "hotlist" || $sphere{$uid}{reason} eq 'newmessages') {
                #this person is in the hotlist or something, so we don't need to show them
                next;
            }
            my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or next;
			push(@{ $P->{user}{peeps} },{profile => $User->profile});
			$count++;
			if ($count == 8) { last; }
	}

    my $onlinenow = getMinisphere(join(",",keys(%sphere)),$P);


# get 5 most recent questions from peeps

	if (scalar keys %sphere) {

		my $getPeepsQows = $P->{dbh}->prepare("SELECT * from questionresponse WHERE userID in (" . join(",",keys(%sphere)) . ") ORDER BY date DESC limit 5;");
		$getPeepsQows->execute;
		while (my $peepq = $getPeepsQows->fetchrow_hashref) {
				my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $peepq->{userId}) or next;
				$User->{profile}{type} = "question";
				$User->{profile}{date} = $peepq->{date};
				$getQuestionById->execute($peepq->{questionId});
				my $question = $getQuestionById->fetchrow_hashref;

				$getMyBling->execute($peepq->{id},$P->{user}{user}{id});
				$peepq->{bling} = $getMyBling->fetchrow;

				if ($peepq->{videoId} > 0) {
					my $ve = video::videoEgg->new(dbh => $P->{dbh},user => $P->{user});
					my $path = $ve->video($peepq->{videoId});
					#$peepq->{answer} = qq|<a href="/profiles/$User->{profile}{linkhandle}#$peepq->{id}"><script language="javascript">videoEgg.drawThumb("$path");</script></a><br clear="left"/>$peepq->{answer}|;
                    $peepq->{answer} = qq|<div style="float: left; background: #333; color: #FFF; text-align: center; font-weight: bold; margin-right: 10px;" class="small"><a href="/profiles/$User->{profile}{linkhandle}#$peepq->{id}"><script language="javascript">videoEgg.drawThumb("$path");</script></a><br>video&nbsp;&#187;&nbsp;</div>$peepq->{answer}|;
					$P->{user}{page}{videoEgg} ||= 1;
				}


				push(@{$P->{user}{peepsquestions}},{answer => $peepq, profile => $User->profile, question => $question});
		}
		$getPeepsQows->finish;

		my $getPeepsTopics =$P->{dbh}->prepare("SELECT * FROM profileTopic WHERE userId in (" . join(",",keys(%sphere)) . ") and enabled=1 and type='profile'  ORDER BY date DESC limit 5;");
		my $getResponses = $P->{dbh}->prepare("SELECT (TIME_TO_SEC(TIMEDIFF(NOW(),max(profileResponse.date))) / 60) as minutes,count(profileResponse.id) as responses FROM profileResponse WHERE profileTopicId=?");
		$getPeepsTopics->execute;
		while (my $topic = $getPeepsTopics->fetchrow_hashref) {
			

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
				push(@{$P->{user}{peepsquestions}},{topic => $topic,profile=>$User->profile});

		}

		if (ref $P->{user}{peepsquestions} eq 'ARRAY') {
			@{$P->{user}{peepsquestions}} = sort {$b->{profile}{date} cmp $a->{profile}{date}} @{$P->{user}{peepsquestions}};
		}
	}


# consumeetings
	{
		my $sql = "SELECT * FROM events WHERE DATE(date) >= DATE(NOW()) ORDER BY date ASC";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $m = $sth->fetchrow_hashref) {
			($m->{handle},$m->{linkhandle}) = $P->{util}->getHandle($m->{sponsorId});
			push @{$P->{user}{meetings}}, {meeting => $m};
		}
		my $sql = "SELECT * FROM events WHERE DATE(date) IS NULL ORDER BY date ASC";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $m = $sth->fetchrow_hashref) {
			($m->{handle},$m->{linkhandle}) = $P->{util}->getHandle($m->{sponsorId});
			push @{$P->{user}{meetings}}, {meeting => $m};
		}
	}

# news
	{
		my $sql = "SELECT id,title,teaser FROM newsblog WHERE pubStatus='published' ORDER BY date DESC limit 3;";
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		while (my $entry = $sth->fetchrow_hashref) {
				push(@{ $P->{user}{blog} },{entry => $entry});
		}
	}

	print processTemplate($P->{user},"dashboard.html");

	return 0;
}

sub prepareQueries {
	my $P = shift;

	$getTopic = $P->{dbh}->prepare("SELECT * FROM profileTopic WHERE userId=? and type='profile' and enabled=1;");	
    $getTopicById = $P->{dbh}->prepare("SELECT * FROM profileTopic WHERE id=?;");
	$watchList = $P->{dbh}->prepare("SELECT count(1) FROM topicwatch WHERE userId=?");
	$getResponses = $P->{dbh}->prepare("SELECT count(1) FROM profileResponse WHERE profileTopicId=?");
    $getContest = $P->{dbh}->prepare("SELECT * FROM photo_contest WHERE itson=1 order by startDate desc limit 1;");
	$getEntry = $P->{dbh}->prepare("SELECT * FROM photo_contest_entry WHERE userId=? and contestId=?");
	$getBlings = $P->{dbh}->prepare("SELECT count(1) FROM photo_contest_bling WHERE entryId=? AND type=?");
	$getQuestion = $P->{dbh}->prepare("SELECT * FROM questionoftheweek ORDER BY date DESC limit 1");
	$getQuestionById = $P->{dbh}->prepare("SELECT * FROM questionoftheweek WHERE id=?");
	$getAnswer =$P->{dbh}->prepare("SELECT * FROM questionresponse WHERE userId=? and questionId=?");
	$getQBlings = $P->{dbh}->prepare("SELECT count(1) FROM bling WHERE questionResponseId=? AND type=?");
	$getThumbs = $P->{dbh}->prepare("SELECT count(1) FROM thumb WHERE profileId=? AND type=? AND insertDate >= DATE_SUB(NOW(),INTERVAL 24 HOUR);");
	$getTags = $P->{dbh}->prepare("SELECT tag.value,tagRef.addedById,tagRef.anonymous FROM tagRef inner join tag ON tagRef.tagId = tag.id WHERE source='U' and tagRef.profileId=? ORDER BY dateAdded desc limit 5");
	$getHotTags = $P->{dbh}->prepare("select value,count(tagRef.profileId) as count,tag.insertDate FROM tag inner join tagRef on tag.id=tagRef.tagId WHERE insertDate > DATE_SUB(NOW(),INTERVAL 7 DAY) GROUP BY tag.id order by count desc limit 10");
	$getPhotoDims = $P->{dbh}->prepare("SELECT width,height FROM photos WHERE id=?");
	$getDowns = $P->{dbh}->prepare("SELECT profileId FROM thumb WHERE userId=? and type='D';");
	$getMyBling = $P->{dbh}->prepare("SELECT type FROM bling WHERE questionResponseId=? AND userId=?");
	$getWatchlist = $P->{dbh}->prepare("SELECT count(1) FROM topicwatch WHERE topicId=? and userId=?");
}

1;
