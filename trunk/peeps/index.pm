package peeps::index;

use strict;
 
use Data::Dumper;
use Date::Calc qw(Localtime Today_and_Now Delta_DHMS Add_Delta_DHMS);
use Apache2::RequestRec;
use Apache2::Const qw(OK);

use lib qw(../lib);
use Profiles;
use util;
use template2;
use Users;
use tags;
use blings;
use Cache;
use query;
use teams;
use video::videoEgg;

my $cache = new Cache;


sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $P = Profiles->new(request => $r, cache => $cache);

	return OK unless defined $P;
	
	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> query->new($r),
	};
	bless $self, $class;


	$self->{user}{system}{tab} = 'Updates';


	my ($spheretime,$timeframe);
	$spheretime = $self->{user}{page}{timeframe} = $timeframe = $self->{query}->param('timeframe') || $self->{query}->cookie('timeframe') || "1 DAY";
	$self->{query}->param('timeframe',$timeframe) unless $self->{query}->param('timeframe');

	my @delta;
	my @now = Today_and_Now;
	my @past;
	if ($self->{query}->param('timeframe') eq 'lastView' && $self->{query}->cookie('viewedUpdates')) {
		if ($self->{query}->cookie('viewedUpdates')) {
			my @t = split / /,$self->{query}->cookie('viewedUpdates');
			@past = (split(/-/,$t[0]),split(/:/,$t[1]));

			my @delta = Delta_DHMS(@past,@now);

			if ($delta[0] < 1) {
				my $min = $delta[1]*60+$delta[2] || 1;
				$spheretime = $timeframe = $min . ' MINUTE';
			} else {
				$spheretime = $timeframe = "$delta[0] DAY";
			}
		}
	} else {
		$timeframe =~ /(\d+)/;
		my $days = $1;
		@past = Add_Delta_DHMS(@now,-$1,0,0,0);
		@delta = Delta_DHMS(@past,@now);
	}

	$self->{user}{page}{mode} =  my $mode = $self->{query}->param('mode') || $self->{query}->cookie('mode') || "everyone";


	$self->{user}{page}{page} = my $page = $self->{query}->param('page') || $self->{query}->cookie('page') || '';

	my $all;	
	if ($self->{query}->param('refresh')) {
		$self->{user}{form}{all} = $all = $self->{query}->param('all') || '';
	} else {
		$self->{user}{form}{all} = $all = $self->{query}->cookie('all') || '';
	}

	my $tcookie = "timeframe=$timeframe; path=/; domain=.consumating.com;";
	my $mcookie = "mode=$mode; path=/; domain=.consumating.com;";
	my $pcookie = "page=$page; path=/; domain=.consumating.com;";
	my $acookie = "all=$all; path=/; domain=.consumating.com;";

	$self->{req}->headers_out->add('Set-Cookie' => $tcookie);
	$self->{req}->headers_out->add('Set-Cookie' => $mcookie);
	$self->{req}->headers_out->add('Set-Cookie' => $pcookie);
	$self->{req}->headers_out->add('Set-Cookie' => $acookie);

	if ($page eq 'tags') {
		$self->tagsUpdates($mode,$timeframe);
		return OK;
	}

	unless ($self->{user}{user}{id}) {
		$self->{user}{page}{peoplecount} = 0;
		print processTemplate($self->{user},"peeps-classic/index.html");
		return OK;
	}


	my $lastupdate;
	my %sphere;

	# load cache framekwork objects
	my $Blings = new blings (dbh => $self->{dbh}, cache => $self->{cache});
	my $Tags = tags->new($self->{cache}, $self->{dbh});



	# generate sphere of interest

	# Anybody on the hotlist stays forever
	# People who have been thumbed up in any way within the last 8 days

	my $spherepeople = $self->getUsers($mode,\%sphere);


	# BUT WAIT!  There's more.
	# we only want to look at the top 5 most recently active people in this list.  Why? WHY NOT. we're trying something here.
	my %minisphere; # a place where the new people live.

	$self->getMinisphere($all,\%minisphere,$spherepeople);


	my $timeframesql = " > DATE_SUB(NOW(),INTERVAL $timeframe) ";
	if ($timeframe eq "1 DAY") {
		$timeframesql = " >= DATE(NOW()) ";
	}
	#prepare db handles


	my %db_sth = (
		lastonline 	=> $self->{dbh}->prepare("SELECT (TIME_TO_SEC(TIMEDIFF(NOW(),users.lastActive)) / 60) as minutes FROM users WHERE id=?"),

		profileTopic => $self->{dbh}->prepare("SELECT id,question FROM profileTopic WHERE userId=? AND enabled=1 ORDER BY date DESC LIMIT 1"),
		profileTopicResponses => $self->{dbh}->prepare("SELECT COUNT(*) FROM profileResponse WHERE profileTopicId = ? AND date $timeframesql"),

		getanno		=> $self->{dbh}->prepare("SELECT note FROM annotations WHERE userId=$self->{user}{user}{id} AND profileId=?"),

		questions 	=> $self->{dbh}->prepare("SELECT answer,r.userId,r.date,videoId,photoId,question,r.id,(TIME_TO_SEC(TIMEDIFF(NOW(),r.date)) / 60) as minutes "
					. "FROM questionoftheweek q, questionresponse r WHERE r.questionId = q.id AND r.userId = ? AND r.date $timeframesql"
					. "ORDER BY r.date DESC"),
		question	=> $self->{dbh}->prepare("SELECT question FROM questionoftheweek WHERE id = ?"),

		tags		=> $self->{dbh}->prepare("SELECT COUNT(*) FROM tagRef WHERE profileId = ? AND dateAdded $timeframesql"),

		outtags		=> $self->{dbh}->prepare("SELECT COUNT(*) FROM tagRef WHERE addedById = ? AND anonymous = -1 AND dateAdded $timeframesql"),

		myouttags	=> $self->{dbh}->prepare("SELECT COUNT(*) FROM tagRef WHERE addedById = ? AND dateAdded $timeframesql ORDER BY dateAdded DESC"),


		photos_with_profile => $self->{dbh}->prepare("SELECT userId,id,timestamp FROM photos WHERE userId = ? AND timestamp $timeframesql "
							. "AND photos.id != ? AND rank <= 5 ORDER BY timestamp DESC"),

		photos_without_profile => $self->{dbh}->prepare("SELECT userId,id,timestamp FROM photos WHERE userId = ? AND timestamp > $timeframesql AND rank <= 5 ORDER BY timestamp DESC"),

		unreadmail 	=> $self->{dbh}->prepare("SELECT count(1) FROM messages WHERE toId=$self->{user}{user}{id} AND fromId=? and isread=0;"),
		photosize 	=> $self->{dbh}->prepare("SELECT height,width FROM photos WHERE id=?"),
		onmyhotlist => $self->{dbh}->prepare("SELECT count(1) FROM hotlist WHERE userId=$self->{user}{user}{id} AND profileId=?"),
		thumbs		=> $self->{dbh}->prepare("SELECT COUNT(*) FROM thumb WHERE type=? AND profileId=? AND insertDate $timeframesql"), 
	);




	my $lastDays = 0;
	my @people = ();
	$timeframe =~ s/ //g;



	my @miniIds = sort {$minisphere{$b} cmp $minisphere{$a}} keys %minisphere;

	for my $uid (@miniIds) {

		my $maxdate = '2000-01-01 01:00:00';
		my $lastupdate = 999999;


		# get user info and photo
		my $profile = $self->getProfile($uid,\%db_sth,\%sphere) or next;

		# get topic
		$self->getTopic($uid,$profile,\%db_sth);

		# see if there are new messages
		{
			$db_sth{unreadmail}->execute($$profile{userid});
			$profile->{unread} = $db_sth{unreadmail}->fetchrow;
		}

		# get annotation
		{
			$db_sth{getanno}->execute($uid);
			$profile->{annotation} = $db_sth{getanno}->fetchrow;
		}


		# IF THIS PERSON IS ABOUT TO DISAPPEAR, SHOW THEM AND ALLOW HOTLIST


		# get new questions
		my $outgoingQuery = ($profile->{userid} == $self->{user}{user}{id}) 
			? 'myouttags'
			: 'outtags';


		push @people, {
			questions	=> [$self->getQuestions($uid,\%db_sth,$Blings,$maxdate,$lastupdate)] || undef,
			profile		=> $profile,
			updatedate	=> $maxdate,
			activedate	=> $profile->{userid} == $self->{user}{user}{id} ? -1 : $profile->{minutes},
		};
		if ($lastupdate != 999999) {
			$people[$#people]->{profile}->{lastupdate} = $self->{util}->timesince($lastupdate);
		}

	} # for each user


	my $sort = $self->{query}->param('sort') || $self->{query}->cookie('sort') || "activedate";


	if ($sort eq "activedate") {
		for my $person (sort { $a->{$sort} <=> $b->{$sort} } @people) {
			if ($person->{profile}{userid} != $self->{user}{user}{id}) {
				push @{$self->{user}{hotlist}}, { profile => $person->{profile}};
			} else {
				$person->{profile}{mine} = 1;
				$db_sth{thumbs}->execute('U',$self->{user}{user}{id});
				$person->{profile}{thumbups} = $db_sth{thumbs}->fetchrow || 0;
				$db_sth{thumbs}->execute('D',$self->{user}{user}{id});
				$person->{profile}{thumbdns} = $db_sth{thumbs}->fetchrow || 0;
			}

			push @{$self->{user}{updates}}, {
				profile => $person->{profile},
				update	=> {
					itag		=> $person->{itag},
					otag		=> $person->{otag},
					noactivity 	=> $person->{qcount} || $person->{itag} || $person->{otag} ? undef : 1,
				},
				questions	=> $person->{questions},
			};
		}
	} else {
		for my $person (sort {$b->{updatedate} cmp $a->{updatedate}} @people) {
			if ($person->{profile}{userid} != $self->{user}{user}{id}) {
				push @{$self->{user}{hotlist}}, { profile => $person->{profile} };
			} else {
				$person->{profile}{mine} = 1;
				$db_sth{thumbs}->execute('U',$self->{user}{user}{id});
				$person->{profile}{thumbups} = $db_sth{thumbs}->fetchrow || 0;
				$db_sth{thumbs}->execute('D',$self->{user}{user}{id});
				$person->{profile}{thumbdns} = $db_sth{thumbs}->fetchrow || 0;
			}
			push @{$self->{user}{updates}}, {
				profile => $person->{profile},
				update	=> {
					qcount 	=> $person->{qcount},
					itag	=> $person->{itag},
					otag	=> $person->{otag},
					noactivity => $person->{qcount} || $person->{itag} || $person->{otag} ? undef : 1,
				},
			};
		}
	
	}

	if ($self->{user}{updates}) {
	$self->{user}{page}{peoplecount} = scalar @{$self->{user}{updates}};
	if ($self->{user}{page}{peoplecount} < 0) {
			$self->{user}{page}{peoplecount} = 0;
	}
	} else {
		$self->{user}{page}{peoplecount} = 0;
	}

	# get a list of my teams
	my $teams = teams->new(dbh => $self->{dbh}, cache => $self->{cache});
	$self->{user}{teamlist} = [map {team => $_->data} => grep {$_->isMember($self->{user}{user}{id})}  $teams->getTeams];


	print processTemplate($self->{user},"peeps-classic/index.html");
	return OK;
}

sub tagsUpdates {
	my $self = shift;
	my $mode = shift;
	my $timeframe = shift;

	unless ($self->{user}{user}{id}) {
		$self->{user}{page}{peoplecount} = 0;
		print processTemplate($self->{user},"peeps-classic/index.html");
		return OK;
	}

	my %sphere;

	# generate sphere of interest

	# Anybody on the hotlist stays forever
	# People who have been thumbed up in any way within the last 8 days

	my $spherepeople = $self->getUsers($mode,\%sphere);


	# this is a comma list of the userIds to put on the updates page
	$spherepeople = join(",",keys(%sphere));

	# build hotlist
	my $unreadmail = $self->{dbh}->prepare("SELECT count(1) FROM messages WHERE toId=$self->{user}{user}{id} AND fromId=? and isread=0;");
	my $lastonline = $self->{dbh}->prepare("SELECT (TIME_TO_SEC(TIMEDIFF(NOW(),users.lastActive)) / 60) FROM users WHERE id=?");
	my $tmp;
	my $count=0;
	my $onnow=0;
	my $getlaston = sub {
		$lastonline->execute($_[0]);
		return $lastonline->fetchrow;
	};
	for my $uid (sort {$a->[1] <=> $b->[1]} map [$_,$getlaston->($_)] => keys %sphere) {
		my $u = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid->[0]) or next;
		$unreadmail->execute($uid->[0]);

		$u->{profile}{unread} = $unreadmail->fetchrow;

		$u->{profile}{timesince} = $self->{util}->timesince($uid->[1]);
		if ($uid->[1] < 15) {
			$u->{profile}{onlinenow} = 1;
			$onnow++;
		} else {
			next if $count > 5;
			$count++;
		}
		push @{$self->{user}{hotlist}}, {profile => $u->profile};
	}
	$unreadmail->finish;

	$self->{user}{page}{onlinenow} = $onnow;


	my $timeframesql = " > DATE_SUB(NOW(),INTERVAL $timeframe) ";
	if ($timeframe eq "1 DAY") {
		$timeframesql = " >= DATE(NOW()) ";
	}
	#prepare db handles


	my $sql = "SELECT DISTINCT t.value AS value, r.profileId, r.addedById FROM tag t, tagRef r WHERE r.tagId=t.id AND r.anonymous = -1 "
			. "AND (r.profileId IN ($spherepeople) OR r.addedById IN ($spherepeople)) AND dateAdded $timeframesql ORDER BY dateAdded DESC";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	while (my $tag = $sth->fetchrow_hashref) {
		my $taggee = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{profileId}) or next;
		my $tagger = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{addedById}) or next;

		($tag->{short} = $tag->{value}) =~ s/(.{20,30}).*/$1/;
		$tag->{short} .= "..." if length $tag->{short} != length $tag->{value};

		push(@{ $self->{user}{publictags} },{tag => $tag,taggee=>$taggee->profile,tagger=>$tagger->profile});
	}
	$sth->finish;

	print processTemplate($self->{user},"peeps-classic/tags.html");
	return OK;
}

sub protectXML {
        my ($str) = @_;

        if ($str =~ /</ || $str =~ />/ || $str =~ /&/) {
                $str = "<![CDATA[$str]]>";
        }
        return $str;
}




sub newMessageUsers {
	my $self = shift;
	my $sphere = shift;

	unless ($self->{newmessageSTH}) {
		$self->{newmessageSTH} = $self->{dbh}->prepare("SELECT fromId FROM messages WHERE toId=? AND isRead = 0");
	}
	$self->{newmessageSTH}->execute($self->{user}{user}{id});
	while (my($uid) = $self->{newmessageSTH}->fetchrow) {
		$sphere->{$uid} = 999999;
	}
}

sub hotlistUsers {
	my $self = shift;
	my $sphere = shift;
	# hot list
	unless ($self->{hotlistSTH}) {
		$self->{hotlistSTH} = $self->{dbh}->prepare("SELECT profileId FROM hotlist WHERE hotlist.userId=?");
	}
	$self->{hotlistSTH}->execute($self->{user}{user}{id});
	while (my($uid) = $self->{hotlistSTH}->fetchrow) {
			$sphere->{$uid} = 999999;
	}
}

sub teammates {
	my $self = shift;
	my $sphere = shift;
	unless ($self->{teammatesSTH}) {
		$self->{teammatesSTH} = $self->{dbh}->prepare("SELECT DISTINCT userId FROM team_members WHERE userId != ? AND teamId = ?");
	}
	my $mode = $self->{query}->param('mode');
	$mode =~ y/a-z_//d;
	$self->{teammatesSTH}->execute($self->{user}{user}{id},$mode);
	while (my $uid = $self->{teammatesSTH}->fetchrow) {
		$sphere->{$uid} = 999999;
	}
}

sub thumbUsers {
	my $self = shift;
	my $sphere = shift;
	my $TU = {};
	if ($TU = $self->{cache}->get("thumbusers$self->{user}{user}{id}")) {
		for my $id (keys %$TU) {
			if ($TU->{$id} > $sphere->{$id}) {
				$sphere->{$id} = $TU->{$id};
			}
		}
	} else {
		my $sql = "SELECT profileId,DATEDIFF(NOW(),insertDate) as days FROM thumb "
				. "WHERE thumb.userId=$self->{user}{user}{id} and type='U' and insertDate > DATE_SUB(NOW(),INTERVAL 8 DAY)";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		while (my($uid,$days) = $sth->fetchrow) {
			if (!$TU->{$uid} || ($TU->{$uid} != 999999 && $TU->{$uid} > $days)) {
				$days *= 1;
				$TU->{$uid} = $days;
			}
		}
		$sth->finish;

		# question thumbs
		$sql = "SELECT distinct(questionresponse.userId),DATEDIFF(NOW(),bling.insertDate) as days "
			 . "FROM bling inner join questionresponse on bling.questionresponseId=questionresponse.id "
			 . "WHERE bling.userId=$self->{user}{user}{id} and type='U' and bling.insertDate > DATE_SUB(NOW(),INTERVAL 8 DAY)";
		$sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		while (my($uid,$days) = $sth->fetchrow) {
			$days *= 1;
			if (!$TU->{$uid} || ($TU->{$uid} != 999999 && $TU->{$uid} > $days)) {
				$TU->{$uid} = $days;
			}
		}
		$sth->finish;

		# contest thumbs
		$sql = "SELECT DISTINCT(e.userId),DATEDIFF(NOW(),b.insertDate) AS days FROM photo_contest_bling b, photo_contest_entry e "
			 . "WHERE b.userId=$self->{user}{user}{id} AND b.entryId=e.id AND type='U' AND b.insertDate > DATE_SUB(NOW(),INTERVAL 8 DAY)";
		$sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		while (my($uid,$days) = $sth->fetchrow) {
			$days *= 1;
			if (!$TU->{$uid} || ($TU->{$uid} != 999999 && $TU->{$uid} > $days)) {
				$TU->{$uid} = $days;
			}
		}
		$sth->finish;

		for my $id (keys %$TU) { $sphere->{$id} = $TU->{$id}; }
		$self->{cache}->set("thumbusers$self->{user}{user}{id}",$TU,15*60);
		
	}
}

sub tagUsers {
	my $self = shift;
	my $sphere = shift;
	my $sql = "SELECT profileId,DATEDIFF(NOW(),dateAdded) as days FROM tagRef WHERE tagRef.addedById=$self->{user}{user}{id} and dateAdded > DATE_SUB(NOW(),INTERVAL 8 DAY)";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	while (my($uid,$days) = $sth->fetchrow) {
		if (!$sphere->{$uid} || ($sphere->{$uid} != 999999 && $sphere->{$uid} > $days)) {
			$days = $days * 1;
			$sphere->{$uid} = $days;
		}
	}
	$sth->finish;
}


sub getMinisphere {
	my $self = shift;
	my ($allparam,$minisphere,$spherepeople) = @_;

	if ($spherepeople eq "") {
		return $minisphere;
	}
	
	if ($allparam eq "") {
		my $sql = "SELECT users.id,(TIME_TO_SEC(TIMEDIFF(NOW(),users.lastActive)) / 60) as minutes FROM users inner join profiles on users.id=profiles.userId WHERE users.id IN ($spherepeople) ORDER BY lastActive desc";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		my $count = 0;
		my $onnow = 0;
		while (my ($id,$minutes) = $sth->fetchrow) {
			$minisphere->{$id} = 1;
			if ($minutes > 15) {
				$count++;
			} else {
				$onnow++;
			}

			last if ($count > 5);
		}
		$sth->finish;

		$self->{user}{page}{onlinenow} = $onnow;
	} else {
		my $sql = "SELECT users.id,(TIME_TO_SEC(TIMEDIFF(NOW(),users.lastActive)) / 60) as minutes FROM users inner join profiles on users.id=profiles.userId WHERE users.id IN ($spherepeople) ORDER BY lastActive desc;";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		my $count = 0;
		my $onnow = 0;
		while (my ($id,$minutes) = $sth->fetchrow) {
			$minisphere->{$id} = 1;
			if ($minutes > 15) {
				$count++;
			} else {
				$onnow++;
			}
		}
		$sth->finish;

		$self->{user}{page}{onlinenow} = $onnow;
	}


	if ($self->{user}{user}{id}) {
		$minisphere->{$self->{user}{user}{id}} = 1;
	}
}

sub getProfile {
	my $self = shift;
	my $uid = shift;
	my $db_sth = shift;
	my $sphere = shift;
	my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid) or return;

	$User->rank;
	my $profile = $User->profile;

	$db_sth->{lastonline}->execute($uid);
	$profile->{minutes} = $db_sth->{lastonline}->fetchrow;

	$db_sth->{onmyhotlist}->execute($uid);
	$profile->{onmyhotlist} = $db_sth->{onmyhotlist}->fetchrow;

	if ($profile->{minutes} <= 15) {
		$profile->{onlinenow} = 1;
	}
	$profile->{timesince} = $self->{util}->timesince($profile->{minutes});

	($profile->{strippedlinkhandle} = $profile->{handle}) =~ s/[^a-z0-9_]//ig;


	my $left = 0;
	if ($sphere->{$uid} == 999999) {
		$left = "forever";
	} else {
		$left = 8 - $sphere->{$uid};
		if ($left == 1) {
			$left = "<i>one more day</i>";
		} else {
			$left = "$left more days";
		}
	}

	$profile->{daysago} = $sphere->{$uid};
	$profile->{daysleft} = $left;

	return $profile;
}

sub getTopic {
	my $self = shift;
	my $uid = shift;
	my $profile = shift;
	my $db_sth = shift;

	$db_sth->{profileTopic}->execute($uid);
	if ($db_sth->{profileTopic}->rows) {
		my $id;
		($id,$profile->{topic}) =  $db_sth->{profileTopic}->fetchrow;
		$db_sth->{profileTopicResponses}->execute($id);
		$profile->{topicCount} = $db_sth->{profileTopicResponses}->fetchrow || 0;
	}
	return;
}

sub getQuestions {
	my $self = shift;
	my $uid = shift;
	my $db_sth = shift;
	my $Blings = shift;
	my $maxdate = shift;
	my $lastupdate = shift;


	$db_sth->{questions}->execute($uid);


	my @ret;

	while (my $item = $db_sth->{questions}->fetchrow_hashref) {
		my $bling = $Blings->getBling($item->{id},$self->{user}{user}{id});
		$item->{bling} = $bling->{type};

		$item->{type} = 'question';
		$item->{timesince} = $self->{util}->timesince($item->{minutes});

		$item->{handle} = $self->{util}->getHandle($item->{userId});
		$item->{linkhandle} = $self->{util}->linkify($item->{handle});

		util::cleanHtml($item->{answer},qw(i b));

		if ($item->{date} gt $maxdate) {
			$maxdate = $item->{date};
		}
		if ($item->{minutes} < $lastupdate) {
			$lastupdate = $item->{minutes};
		}

		if ($item->{photoId} > 0) {
			$db_sth->{photosize}->execute($item->{photoId});
			my ($height,$width) = $db_sth->{photosize}->fetchrow_array;
			if ($width == 400) {
				$item->{answer} =  qq|<a id="qowPhotoLink$item->{id}" onclick="return expandPhoto($item->{id},$height,$item->{photoId});" href='#'><div class="inlineQOW" id="qowPhoto$item->{id}" onmouseover="hoverlink(this,1)" onmouseout="hoverlink(this,0)" style="background: url('/photos/$uid/large/$item->{photoId}.jpg') 0% 5% repeat;" /></div></a><br clear="all" />| . $item->{answer};
			} else {
				$item->{answer} =  qq|<a href='/picture.pl?id=$item->{photoId}'><img src="/photos/$uid/large/$item->{photoId}.jpg" class="qow_illustration" height='$height' width='$width'/></a><br clear="all" />| . $item->{answer};
			}
		}
		if ($item->{videoId} > 0) {
			my $ve = video::videoEgg->new(dbh => $self->{dbh},user => $self->{user});
			my $path = $ve->video($item->{videoId});
			$item->{answer} = qq|<a href="/profiles/$item->{linkhandle}#$item->{id}"><script language="javascript">videoEgg.drawMovie("$path");</script></a><br><br>$item->{answer}|;
			$self->{user}{page}{videoEgg} = 1;
		}

		push @ret, {question => $item};
	}
	return @ret;
}

sub getTags {
	my $self = shift;
	my $uid = shift;
	my $query = shift;
	my $db_sth = shift;
	my $Tags = shift;
	my $maxdate = shift;
	my $lastupdate = shift;

	my $dir = $query =~ /out/ ? 'out' : 'in';

	$db_sth->{$query}->execute($uid);
	return $db_sth->{$query}->fetchrow;
}

sub getPhotos {
	my $self = shift;
	my $uid = shift;
	my $profile = shift;
	my $db_sth = shift;
return;
}

sub getUsers {
	my $self = shift;
	my $mode = shift;
	my $sphere = shift;

	$mode='teammates' if substr($mode,0,9) eq 'teammates';

	my %modes = (
		hotlist		=> sub {$self->hotlistUsers($_[0])},
		thumbs 		=> sub {$self->thumbUsers($_[0])},
		tags 		=> sub {$self->tagUsers($_[0])},
		teammates	=> sub {$self->teammates($_[0])},
	);

	$mode = 'everyone' unless defined $modes{$mode};

	if ($mode eq 'everyone') {
		for (keys %modes) {
			$modes{$_}->($sphere);
		}
		# also show people from whom you have new messages waiting
		$self->newMessageUsers($sphere);
	} else {
		$modes{$mode}->($sphere);
	}


	# get rid of people who have been explicitly thumbed down full stop
	# since being thumbed up or tagged
	{
		my $sql = "SELECT profileId,DATEDIFF(NOW(),insertDate) as days FROM thumb WHERE thumb.userId=$self->{user}{user}{id} and type='D'";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		while (my($uid,$days) = $sth->fetchrow) {
			delete $sphere->{$uid} if ($days < $sphere->{$uid});
		} 
		$sth->finish;        
	}


	# pull yourself out, cause we're gonna pull that stuff by itself.
	delete $sphere->{$self->{user}{user}{id}};


	# OK, now we have a list of everyone to include on the updates page.  now we need to pull the actual updates and group them into nice little blog clusters.
	# How do we do that?
	# let's pull all the updates, associate a date and type to them (qow, tag, etc) and then group the tags together by person in between qows.
	$self->{user}{update}{spheresize} = keys(%$sphere);

	return join(",",keys(%$sphere));
}


1;
