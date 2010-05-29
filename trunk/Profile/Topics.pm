package Profile::Topics;

use strict;
use Page;
use Profile;

our @ISA = qw(Page Profile);

our $postsPerPage = 100;

sub display {
	my $self = shift;

	$self->prepare;
	$self->displayDefault;

	$self->loadTopic;

	print $self->{P}->process('Profile/topics.html');

	return (0);
}

sub loadTopic {
	my $self = shift;

	my $offset = $self->{query}->param('offset') || 0;

	my $sth;
	if (my $tid = $self->{query}->param('id')) {
		$sth = $self->{sth}->{topicbyId};
		$sth->execute($self->{user}{profile}{id},$tid);
	} else {
		$sth = $self->{sth}->{getActiveTopic};
		$sth->execute($self->{user}{profile}{id});
	}

	if (my $topic = $sth->fetchrow_hashref) {
		$topic->{timesinceposted} = $self->{util}->timesince($topic->{minutes});
		$topic->{linkhandle} = $self->{user}{profile}{linkhandle};
		$self->{user}{topic} = $topic;

		if ($self->{user}{user}{id}) {
			# check watchlist
			$self->{sth}{watchlist}->execute($topic->{id},$self->{user}{user}{id});
			$self->{user}{page}{watch} = $self->{sth}{watchlist}->fetchrow;
		}

		# load topic tags
		$self->{sth}{topictags}->execute($topic->{id});
		while (my $tag = $self->{sth}{topictags}->fetchrow_hashref) {
			my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{userId}) or next;
			if ($self->{user}{user}{id} == $topic->{userId}) {
				$tag->{mine} = 1;
			}
			push @{$self->{user}{tags}}, {tag => $tag, profile => $User->profile};
		}

		$self->{sth}{responseCount}->execute($topic->{id});
		$self->{user}{topic}{responseCount} = $self->{sth}{responseCount}->fetchrow;

		$self->{sth}{responseUsers}->execute($topic->{id}, $self->{user}{profile}{id});
		while (my $uid = $self->{sth}{responseUsers}->fetchrow) {
			my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid) or next;
			push @{$self->{user}{responders}}, {profile => $User->profile};
		}

		my $responseoffset = $self->{user}{topic}{offset} = 
			defined $self->{query}->param('responseoffset')
				? $self->{query}->param('responseoffset')
				: $self->{user}{topic}{responseCount} - $postsPerPage <= 0
					? 0
					: $self->{user}{topic}{responseCount} % $postsPerPage == 0
						? $self->{user}{topic}{responseCount} - $postsPerPage
						: int($self->{user}{topic}{responseCount}/$postsPerPage) * $postsPerPage
		;

		my $i = 0;
		my $firstCurrent = 0;
		while ($i++ * $postsPerPage < $self->{user}{topic}{responseCount}) {
			my $current = 0;
			if ($firstCurrent == 0) {
				if ($responseoffset < $i*$postsPerPage && $responseoffset != $self->{user}{topic}{responseCount} - $postsPerPage) {
					$current = 1;
					$self->{user}{topic}{currentPage} = $i;
					$firstCurrent++;
				} elsif ($i * $postsPerPage >= $self->{user}{topic}{responseCount}) {
					$current = 1;
					$self->{user}{topic}{currentPage} = $i;
					$firstCurrent++;
				}
			}
			push @{$self->{user}{topicPages}}, { pager => { number => $i, current => $current } };
		}
		$self->{user}{topic}{lastPage} = $i-1;
		$self->{user}{topic}{currentPage} ||= 1;
		$self->{user}{topic}{onLastPage} = 1 if $self->{user}{topic}{currentPage} == $self->{user}{topic}{lastPage};

		$self->{sth}{responseBody}->bind_param(1,$topic->{id});
		$self->{sth}{responseBody}->bind_param(2,$responseoffset, {TYPE => DBI::SQL_INTEGER});
		$self->{sth}{responseBody}->bind_param(3,$postsPerPage, {TYPE => DBI::SQL_INTEGER});
		$self->{sth}{responseBody}->execute();
		while (my ($response, $id, $date, $minutes, $rid) = $self->{sth}{responseBody}->fetchrow) {
			my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $id) or next;

			$User->{profile}->{timesince} = $self->{util}->timesince($minutes);
			$User->{profile}->{response} = $response;
			$User->{profile}->{responseId} = $rid;
			$User->{profile}->{date} = $date;
			$User->{profile}->{myprofile} = $self->{user}{profile}{myprofile};

			if ($id == $self->{user}{profile}{id}) {
				$User->{profile}{currentuser} = 1;
			}
	
			$User->{profile}{myprofile} = 1 if ($self->{user}{user}{id} == $self->{user}{profile}{userid});

			util::cleanHtml($User->{profile}{response});

			push @{$self->{user}{responses}}, { response => $User->profile, topic => $self->{user}{topic} };
			$self->{user}{lastresponse} = $User->profile;
		}

		$self->{sth}{watchcount}->execute($topic->{id});
		$self->{user}{topic}{watchCount} = $self->{sth}{watchcount}->fetchrow;
	} else {
		# no ID supplied and no currently active topic
warn "NO TOPIC FOUND";
		delete $self->{user}{topic};
	}

	$self->{sth}{topicCount}->execute($self->{user}{profile}{id});
	my $total = $self->{sth}{topicCount}->fetchrow;
	if ($offset + 10 <= $total) {
		if ($offset == 0) {
			$self->{user}{previoustopics}{more} = 11;
		} else {
			$self->{user}{previoustopics}{more} = $offset + 10;
		}
	}
	if ($offset > 0) {
		if ($offset == 11) {
			$self->{user}{previoustopics}{prev} = 0;
		} else {
			$self->{user}{previoustopics}{prev} = $offset - 10;
		}
	}

	$self->{user}{page}{topicPage} = 1;
	$self->{sth}{channels}->execute;
	while (my $r = $self->{sth}{channels}->fetchrow_hashref) {
		if ($r->{id} == $self->{user}{topic}{channelId}) {
			$self->{user}{topic}{channelName} = $r->{name};
			$r->{selected} = 1;
		}
		push @{$self->{user}{channels}}, { channel => $r };
	}

	# get older topics
	$self->{sth}{oldtopics}->bind_param(1,$self->{user}{profile}{userId});
	$self->{sth}{oldtopics}->bind_param(2,$offset, {TYPE => DBI::SQL_INTEGER});
	$self->{sth}{oldtopics}->execute();
	while (my $topic = $self->{sth}{oldtopics}->fetchrow_hashref) {
		$self->{sth}{getResponses}->execute($topic->{id});
		my $extra = $self->{sth}{getResponses}->fetchrow_hashref;
		next if $extra->{count} == 0;

		if ($self->{user}{profile}{userId} == $self->{user}{user}{id} && $topic->{enabled} == 0) {
			$topic->{myclosed} = 1;
		}
		$topic->{timesinceposted} = $self->{util}->timesince($topic->{minutes});
		$topic->{responses} = $extra->{count};
		$topic->{endDate} = $extra->{endDate};
		$topic->{timesinceclosed} = $self->{util}->timesince($extra->{minutes});

		util::cleanHtml($topic->{question},'everything');

		push @{$self->{user}{topics}}, { profile => $self->{user}{profile}, topic => $topic };
	}
		
}

sub prepare {
	my $self = shift;

	for
	(
    	[ topicbyId		=> "SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId,channelId FROM profileTopic WHERE userId=? AND id=? and type='profile'" ],
		[ watchlist		=> "SELECT COUNT(*) FROM topicwatch WHERE topicId = ? AND userId = ?" ],
		[ topictags		=> "SELECT t.value, t.id, r.userId FROM topicTagRef r INNER JOIN tag t ON r.tagId = t.id WHERE r.topicId = ?" ],
		[ responseCount	=> "SELECT COUNT(*) FROM profileResponse WHERE profileTopicId = ?" ],
		[ responseUsers	=> "SELECT DISTINCT userId FROM profileResponse WHERE profileTopicId = ? AND userId != ? ORDER BY RAND() LIMIT 14" ],
    	[ responseBody	=> "SELECT response,userId,date,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes, id AS responseId FROM profileResponse WHERE profileTopicId = ? ORDER BY date ASC LIMIT ?,?" ],
    	[ topicCount	=> "SELECT COUNT(*) FROM profileTopic WHERE userId = ?" ],
		[ channels		=> "SELECT id,name FROM profileChannels ORDER BY id ASC" ],
		[ watchcount	=> "SELECT COUNT(*) FROM topicwatch WHERE topicId = ?" ],
		[ oldtopics		=> "SELECT *,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) AS minutes FROM profileTopic WHERE userId = ? AND type='profile' ORDER BY date DESC LIMIT ?,10" ],
		[ getResponses	=> "SELECT COUNT(*) AS count,MAX(date) AS endDate,(TIME_TO_SEC(TIMEDIFF(NOW(),MAX(date))) / 60) AS minutes FROM profileResponse WHERE profileTopicId = ?" ],
	)
	{
		$self->{sth}->{$_->[0]} = $self->{dbh}->prepare($_->[1]);
	}

	$self->SUPER::prepare();
}

1;
