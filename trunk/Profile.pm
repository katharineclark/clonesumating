package Profile;

use strict;
 
use Class::Inspector;
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
use bbDates;
use sphere;
use video::videoEgg;
use items;

use Profile::Answers;
use Profile::Photos;
use Profile::Inventory;
use Profile::Topics;
use Profile::Messages;
use Profile::Thumbup;
use Profile::Thumbdown;
use Profile::Invite;
use Profile::Rss;
use Profile::Updates;
use Profile::Tags;

our $dbh;
our $cache = new Cache;

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $dbActive = ref $dbh && $dbh->ping;

	my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
	unless (ref $P) {
		return 0;
	}
    $P->{user}{global}{section} = 'peeps';


	$P->{user}{global}{newstyle} = 1;

	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> CGI->new($r),
		P		=> $P,
	};
	bless $self, $class;

	$self->prepare() unless $dbActive;

	(undef,$self->{user}{query}{handle},$self->{command}) = split(/\//,$P->{command});
    #warn "PROFILES PID: $$: $self->{command}";

	if ($self->{command} eq "") {
		$self->displayDefault();
	} else {
		my $subclass = 'Profile::'.ucfirst($self->{command});
		if (Class::Inspector->loaded($subclass)) {
			my $API = $subclass->new(
				req     => $r, 
				user    => $P->{user},
				cache   => $P->{cache},
				dbh     => $P->{dbh},
				util    => util->new(dbh => $P->{dbh}, cache => $P->{cache}),
				query   => CGI->new($r),
				P       => $P,
			);
			return $API->display;
		} else {
			$self->displayDefault();
		}
	} 

# questions
# tags
# invite
# thumb up
# thumb down
# my updates
 

	return 0;
}


sub displayDefault() {
	my $self = shift;

	my $handle = $self->{util}->delinkify($self->{user}{query}{handle});
	my $offset = $self->{query}->param('offset') || 0;

	my $uid = $self->{util}->getUserId($handle);

    unless ($self->{User} = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid)) {
		print $self->{P}->process('Profile/deleted.html');
		return 0;
	}
	$self->{User}->rank;
	$self->{user}{profile} = $self->{User}->profile;

	if ($self->{user}{profile}{userId} eq $self->{user}{user}{id}) {
		$self->{user}{page}{myprofile} = 1;
	}

	# check to see if there is an active topic
	$self->{sth}->{getActiveTopic}->execute($self->{user}{profile}{userId});
	if (my($topic) = $self->{sth}->{getActiveTopic}->fetchrow_hashref) {
		$self->{user}{topic} = $topic;
		$self->{sth}->{getTopicCount}->execute($topic->{id});
		$self->{sth}->{topicWatches}->execute($topic->{id});
		$self->{user}{topic}{responseCount} = $self->{sth}->{getTopicCount}->fetchrow;
		$self->{user}{topic}{watchCount} = $self->{sth}->{topicWatches}->fetchrow;
	}

	$self->loadTags();
	$self->loadContests();
	$self->loadQuestions();
	$self->loadItems();

	$self->{sth}->{profileThumb}->execute($self->{user}{profile}{userId},$self->{user}{user}{id});
	$self->{user}{profile}{thumb} = $self->{sth}->{profileThumb}->fetchrow;

	if ($self->{user}{user}{id}) {
		$self->{sth}->{checkhotlist}->execute($self->{user}{user}{id},$self->{user}{profile}{userId});
		my $hl = $self->{sth}->{checkhotlist}->fetchrow;
		if ($hl > 0) {
			$self->{user}{profile}{hotlist} = 1;
		} 
	} else {
		# not on hotlist	
	}

	#get other photos
	$self->{sth}->{photos}->execute($self->{user}{profile}{userId});
	while (my $photo = $self->{sth}->{photos}->fetchrow_hashref) {
		push(@{$self->{user}{photos}},{photo => $photo});
	}

	# get thumbs
	$self->{sth}{thumbcnt}->execute('U',$self->{user}{profile}{userid});
	$self->{user}{profile}{thumbsUp} = $self->{sth}{thumbcnt}->fetchrow;

	$self->{sth}{thumbcnt}->execute('D',$self->{user}{profile}{userid});
	$self->{user}{profile}{thumbsDown} = $self->{sth}{thumbcnt}->fetchrow;

	# get random tags
	$self->{sth}{tagsincommon}->execute($self->{user}{user}{id},$self->{user}{profile}{userId});
	$self->{user}{personalized}{incommon} = $self->{sth}{tagsincommon}->fetchrow;
	if ($self->{user}{personalized}{incommon} > 3) { 
		$self->{user}{personalized}{description} = " including ";
	} else {
		$self->{user}{personalized}{description} = ":";
	}
	if ($self->{user}{personalized}{incommon} >= 1) {
		$self->{sth}{threecommontags}->execute($self->{user}{user}{id},$self->{user}{profile}{userId});
		my $count = 0;		
		while (my $tag = $self->{sth}{threecommontags}->fetchrow_hashref) {
			push(@{ $self->{user}{personalized_tags} },{tag => $tag});
		}
	} else {
		$self->{sth}{threerandomtags}->execute($self->{user}{profile}{userId});
		while (my $tag = $self->{sth}{threerandomtags}->fetchrow_hashref) {
			push @{$self->{user}{random_tags}},{ tag => $tag };
		}
	}


	print $self->{P}->process("Profile/view.html") if ref($self) eq 'Profile';

}

sub loadTags {
	my $self = shift;
	# get self tags
	$self->{sth}->{selftags}->execute($self->{user}{profile}{userId});
	while (my $tag = $self->{sth}->{selftags}->fetchrow_hashref) {
		push(@{$self->{user}{selftags}},{tag=>$tag,page	=> $self->{user}{page}});
	}

	# get other tags
	my $limit = shift || 50;
	$self->{sth}->{othertags}->bind_param(1,$self->{user}{profile}{userId});
	$self->{sth}->{othertags}->bind_param(2,$limit, {TYPE => DBI::SQL_INTEGER});
	$self->{sth}->{othertags}->execute;
	while (my $tag = $self->{sth}->{othertags}->fetchrow_hashref) {
		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{addedById}) or next;
		$tag->{timesince} = $self->{util}->timesince($tag->{minutes});
		push @{$self->{user}{othertags}},{	
			tag => $tag,	
			page => $self->{user}{page},
			user => $U->profile,
		};
	}
}

sub loadContests {
	my $self = shift;
	my $limit = shift || 10;

	delete $self->{user}{photothemes};

	$self->{sth}->{thisContest}->execute();
	my $currentContest = $self->{sth}->{thisContest}->fetchrow;

	$self->{sth}->{photoContests}->bind_param(1,$self->{user}{profile}{userId});
	$self->{sth}->{photoContests}->bind_param(2,$limit, {TYPE => DBI::SQL_INTEGER});
	$self->{sth}->{photoContests}->execute();
	while (my $c = $self->{sth}{photoContests}->fetchrow_hashref) {
        delete $c->{photoId} if ($c->{photoId} eq "" || $c->{photoId} eq "0");
		

		$self->{sth}->{photoContest}->execute($c->{contestId});
		$self->{sth}->{photoVote}->execute($c->{id},$self->{user}{user}{id});

		my $contest = $self->{sth}->{photoContest}->fetchrow_hashref;
		my $vote = $self->{sth}->{photoVote}->fetchrow_hashref;

		$self->{sth}->{photoBlings}->execute($c->{id},'U');
		$c->{blingups} = $self->{sth}->{photoBlings}->fetchrow || 0;
		$self->{sth}->{photoBlings}->execute($c->{id},'D');
		$c->{blingdowns} = $self->{sth}->{photoBlings}->fetchrow || 0;

		$self->{user}{profile}{pthumbups} += $c->{blingups};
		$self->{user}{profile}{pthumbdowns} += $c->{blingdowns};


		if ($c->{contestId} == $currentContest) {
			$self->{user}{currentContest} = $contest;
			$self->{user}{profile}{currentContestVote} = $vote->{direction};
			$c->{itson} = 1;
		}


		push @{$self->{user}{photothemes}}, { 
			content => $c, 
			user => $self->{User}->profile, 
			contest => $contest,
			vote => $vote,
			page	=> $self->{user}{page},
		};

	}
	$self->{user}{profile}{pthumbups} ||= 0;
	$self->{user}{profile}{pthumbdowns} ||= 0;
	if ($self->{user}{profile}{pthumbups} > 0 || $self->{user}{profile}{pthumbdowns} > 0) {
		$self->{user}{profile}{photothumbs} = 1;
	}
}

sub loadQuestions {
	my $self = shift;
	my $limit = shift || 10;

	delete $self->{user}{qows};

	$self->{sth}->{questionAnswers}->execute($self->{user}{profile}{userId});
	my %questions;
	while (my $q = $self->{sth}->{questionAnswers}->fetchrow_hashref) {
        delete $q->{photoId} if ($q->{photoId} eq "" || $q->{photoId} eq "0");

        delete $q->{videoId} if ($q->{videoId} eq "" || $q->{videoId} eq "0");
		if ($q->{videoId}) {
			$self->{user}{page}{videoEgg} = 1;
			my $ve = video::videoEgg->new(dbh => $self->{dbh}, user => $self->{user});
			$q->{videopath} = $ve->video($q->{videoId});
		}

		$self->{sth}->{question}->execute($q->{questionId});
		$self->{sth}->{questionVote}->execute($q->{id},$self->{user}{user}{id});

		$self->{sth}->{questionBlings}->execute($q->{id},'U');
		$q->{blingups} = $self->{sth}->{questionBlings}->fetchrow || 0;
		$self->{sth}->{questionBlings}->execute($q->{id},'D');
		$q->{blingdowns} = $self->{sth}->{questionBlings}->fetchrow || 0;


		$self->{user}{profile}{qthumbups}    += $q->{blingups};
		$self->{user}{profile}{qthumbdowns} += $q->{blingdowns};


		$questions{$q->{id}} = {
			content => $q,
			user 	=> $self->{User}->profile,
			contest	=> $self->{sth}->{question}->fetchrow_hashref,
			vote	=> $self->{sth}->{questionVote}->fetchrow_hashref,
			page	=> $self->{user}{page},
		};
	}

	$self->{user}{profile}{qthumbups}   ||= 0;
	$self->{user}{profile}{qthumbdowns} ||= 0;
	if ($self->{user}{profile}{qthumbups} > 0 || $self->{user}{profile}{qthumbdowns} > 0) {
		$self->{user}{profile}{questionthumbs} = 1;
	}


	if ($self->{user}{profile}{qowOrder}) {
		my %ids;
		for my $id (split /,/,$self->{user}{profile}{qowOrder}) {
			next unless ($id && $questions{$id});
			$ids{$id}++;
			push @{$self->{user}{qows}}, $questions{$id};
			last if scalar @{$self->{user}{qows}} == $limit;
		}
		if (scalar @{$self->{user}{qows}} < $limit && scalar @{$self->{user}{qows}} != scalar keys %questions) {
			for (sort {$b->{content}{date} cmp $a->{content}{date}} values %questions ) {
				next if $ids{$_->{content}{id}};
				push @{$self->{user}{qows}}, $questions{$_->{content}{id}};
				last if scalar @{$self->{user}{qows}} == $limit;
			}
		}
	} else {
		for (sort {$b->{content}{date} cmp $a->{content}{date}} values %questions) {
			push @{$self->{user}{qows}}, $questions{$_->{content}{id}};
			last if scalar @{$self->{user}{qows}} == $limit;
		}
	}
}

sub loadItems {
	my $self = shift;

	# get your pocket items
	my $items = new items ($self->{cache},$self->{dbh},$self->{user}{user}{userId});
	for ($items->pocketItems) {
		push(@{ $self->{user}{yourItems} },{profile => $self->{user}{profile},item=>$_});
	}


	# get profile items
	$items = new items ($self->{cache},$self->{dbh},$self->{user}{profile}{userId});

	# load dashboard
	my $dashboard = $items->getdashboard;
	$self->{user}{items}{hasDashboard} = 0;
	for my $pos (1 .. 7) {
		my $itemId = $dashboard->{"item$pos"};
#warn "ITEM $itemId";
		unless ($itemId) {
			warn "NO ITEM POS $pos";
			push @{$self->{user}{dashboardItems}}, {
				iter => {position => $pos}, 
				page => $self->{user}{page},
				item => {noitem => 1}
			};
		} else {
			push @{$self->{user}{dashboardItems}}, { 
				iter => {position => $pos}, 
				page => $self->{user}{page},
				item => $items->{allItems}{$itemId} 
			};
			$self->{user}{items}{hasDashboard} = 1;
		}
		#warn "DASH ITEM $itemId ".Dumper($items->{allItems}{$itemId});
	}
	if ($dashboard->{"itemtheme"}) {
		$self->{user}{themeItem} = $items->{allItems}{$dashboard->{"itemtheme"}};
	}

	$self->{user}{items}{count} = scalar keys %{$items->{allItems}};

	my $count = 0;

	$items = new items ($self->{cache},$self->{dbh},$self->{user}{profile}{userId});
	my $count = 0;
	for ($items->drawerItems) {
		push(@{ $self->{user}{profileItems} },{profile => $self->{user}{profile},item=>$_});
	}
	# use enabled behavior items
	my $bsth = $self->{dbh}->prepare("SELECT behavior FROM user_item_info WHERE itemId = ?");
	for my $itemId (grep{$items->{allItems}{$_}->{enabled}} keys %{$items->{allItems}}) {
		$bsth->execute($itemId);
		if ($bsth->rows) {
			my $bh = $bsth->fetchrow;
			push @{$self->{user}{itemBehaviors}}, {item => {id => $itemId, behavior => $bh}};
		}
	}
	return 0;
}


sub prepare {
	my $self = shift;

	for 
	(
		[ getActiveTopic 	=> "SELECT * FROM profileTopic WHERE type='profile' AND enabled = 1 AND userId = ?" ],
		[ getTopicCount		=> "SELECT COUNT(*) FROM profileResponse WHERE profileTopicId = ?" ],
		[ photoContests		=> "SELECT * FROM photo_contest_entry WHERE userId = ? ORDER BY insertDate DESC LIMIT ?" ],
		[ questionAnswers	=> "SELECT * FROM questionresponse WHERE userId = ? ORDER BY date DESC" ],
		[ checkhotlist 		=> "SELECT count(1) FROM hotlist WHERE userId=? and profileId=?;" ],
		[ oldtopics			=> "SELECT * FROM profileTopic WHERE enabled = 0 AND userId = ? ORDER BY date DESC LIMIT 10" ],
		[ question			=> "SELECT id,question FROM questionoftheweek WHERE id = ?" ],
		[ thisContest		=> "SELECT id FROM photo_contest WHERE itsOn=1" ],
		[ photoContest		=> "SELECT * FROM photo_contest WHERE id = ?" ],
		[ questionVote		=> "SELECT type AS direction FROM bling WHERE questionresponseId = ? AND userId = ?" ],
		[ questionBlings	=> "SELECT COUNT(*) FROM bling WHERE questionresponseId = ? AND type = ?" ],
		[ photoVote			=> "SELECT type AS direction FROM photo_contest_bling WHERE entryId = ? AND userId = ?" ],
		[ photoBlings		=> "SELECT COUNT(*) FROM photo_contest_bling WHERE entryId = ? AND type = ?" ],
		[ responseCount		=> "SELECT COUNT(*) FROM profileResponse WHERE profileTopicId = ?" ],
		[ topicWatches		=> "SELECT COUNT(*) FROM topicwatch WHERE topicId = ?" ],
		[ selftags			=> "SELECT t.id,value FROM tag t INNER JOIN tagRef r ON t.id = r.tagId WHERE r.profileId = ? AND source = 'O' ORDER BY value" ],
		[ othertags			=> "SELECT t.id,value,(TIME_TO_SEC(TIMEDIFF(NOW(),r.dateAdded)) / 60) as minutes, r.addedById, r.anonymous FROM tag t INNER JOIN tagRef r ON t.id = r.tagId WHERE r.profileId = ? AND source = 'U' ORDER BY dateAdded DESC LIMIT ?" ],
		[ photos			=> "SELECT * FROM photos WHERE rank > 1 AND rank <= 5 AND userId = ?" ],
		[ profileThumb		=> "SELECT type FROM thumb WHERE profileId = ? AND userId = ?" ],
		[ thumbcnt			=> "SELECT COUNT(*) FROM thumb WHERE type=? AND profileId=?" ],
		[ threerandomtags	=> "SELECT value FROM tag t, tagRef r WHERE t.id=r.tagId AND r.profileId=? AND r.source='O' ORDER BY RAND() LIMIT 3" ],
		[ tagsincommon		=> "SELECT COUNT(t1.tagId) FROM tagRef AS t1, tagRef AS t2 WHERE t1.source=t2.source AND t1.source='O' AND t1.tagId=t2.tagId AND t1.profileId=? AND t2.profileId=?" ],
		[ threecommontags	=> "SELECT value FROM tag t, tagRef t1, tagRef t2 WHERE t1.source=t2.source and t1.source='O' AND  t1.tagId=t2.tagid AND t1.profileId=? AND t2.profileId=? AND t1.tagId=t.id ORDER BY RAND() LIMIT 3" ],
	)
	{
		$self->{sth}->{$_->[0]} = $self->{dbh}->prepare($_->[1]);
	}
}


