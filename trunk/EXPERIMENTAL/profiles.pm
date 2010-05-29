package portalize::profiles;


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
    $P->{user}{global}{section} = 'peeps';


	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> CGI->new($r),
	};
	bless $self, $class;

	(undef,$self->{user}{query}{handle},$self->{command}) = split(/\//,$P->{command});
    warn "PROFILES PID: $$: $self->{command}";

	#%db_sth = $self->prepareQueries unless ($dbActive);

	if ($self->{command} eq "") {
		$self->displayDefault()
	} elsif ($self->{command} eq "updates") {
		$self->displayMyUpdates();
	} 

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

	my $getUserIdByHandle = $self->{dbh}->prepare("SELECT userId FROM profiles WHERE handle=?");
	$getUserIdByHandle->execute($handle);
	my $uid = $getUserIdByHandle->fetchrow;
	$getUserIdByHandle->finish;

    my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid) or die "No such user";
	$self->{user}{profile} = $U->profile;

	if ($self->{user}{profile}{userId} eq $self->{user}{user}{id}) {
		$self->{user}{page}{myprofile} = 1;
	}

	# check to see if there is an active topic
	my $getActiveTopic = $self->{dbh}->prepare("SELECT * FROM profileTopic WHERE type='profile' and userId=? and enabled=1");
	$getActiveTopic->execute($self->{user}{profile}{userId});
	if (my($topic) = $getActiveTopic->fetchrow_hashref) {
		$self->{user}{topic} = $topic;
		my $getTopicCount = $self->{dbh}->prepare("SELECT count(1) FROM profileResponse WHERE profileTopicId=?");
		$getTopicCount->execute($topic->{id});
		$self->{user}{topic}{responseCount} = $getTopicCount->fetchrow;
		$getTopicCount->finish;
	}

	# load content
	my @queries;
    push(@queries,"(select null as text,photoId,userId,'photo' as type,photo_contest_entry.insertDate as date,id,contestId as contestId,1 as enabled from photo_contest_entry where userId=?)");
    push(@queries,"(select answer as text,photoId,userId,'qow' as type,date,id,questionId as contestId,1 as enabled from questionresponse where userId=?)");
    #push(@queries,"(select question as text,null as photoId,userId,'topic' as type,date,id,null as contestId,enabled from profileTopic where enabled=0 AND userId=?)");

    my $sql = join(" UNION ",@queries) . " order by date desc limit $offset,20";

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($self->{user}{profile}{userId},$self->{user}{profile}{userId}); # ,$self->{user}{profile}{userId});

    my $getQuestion = $self->{dbh}->prepare("SELECT question,id FROM questionoftheweek WHERE id=?");
    my $getContest = $self->{dbh}->prepare("SELECT description,name,shortname,tagname,id FROM photo_contest WHERE id=?");
    my $getQuestionVote = $self->{dbh}->prepare("SELECT type as direction FROM bling WHERE questionresponseId=? and userId=?");
    my $getPhotoVote = $self->{dbh}->prepare("SELECT type AS direction FROM photo_contest_bling WHERE entryId=? and userId=?");
    my $getResponseCount = $self->{dbh}->prepare("SELECT count(id) as responses FROM profileResponse WHERE profileTopicId=?");


	while (my $newstuff = $sth->fetchrow_hashref) {
        my ($contest,$vote);
        delete $newstuff->{photoId} if ($newstuff->{photoId} eq "" || $newstuff->{photoId} eq "0");
        if ($newstuff->{type} eq "qow") {
            warn "loading question";
            $getQuestion->execute($newstuff->{contestId});
            $getQuestionVote->execute($newstuff->{id},$self->{user}{user}{id});

            $vote = $getQuestionVote->fetchrow_hashref;
            $contest = $getQuestion->fetchrow_hashref;
        } elsif ($newstuff->{type} eq "photo") {
            warn "loading contest";
            $getContest->execute($newstuff->{contestId});
            $getPhotoVote->execute($newstuff->{id},$self->{user}{user}{id});

            $vote = $getPhotoVote->fetchrow_hashref;
            $contest = $getContest->fetchrow_hashref;
        } elsif ($newstuff->{type} eq "topic") {
            $getResponseCount->execute($newstuff->{id});
            $contest = $getResponseCount->fetchrow_hashref;
        }
        $newstuff->{text} =~ s/<.*?>//gsm;
		if ($newstuff->{type} eq "qow") {
        push(@{$self->{user}{qows}},{content=>$newstuff,user=>$U->profile,contest=>$contest,vote=>$vote});
		} elsif ($newstuff->{type} eq "photo") {
        push(@{$self->{user}{photothemes}},{content=>$newstuff,user=>$U->profile,contest=>$contest,vote=>$vote});
		}

        push(@{$self->{user}{posts}},{content=>$newstuff,user=>$U->profile,contest=>$contest,vote=>$vote});
    }


	# get self tags
	my $getSelfTags = $self->{dbh}->prepare("SELECT value FROM tag,tagRef WHERE tag.id=tagRef.tagId and tagRef.profileId=? and tagRef.addedById=tagRef.profileId ORDER BY value");
	$getSelfTags->execute($self->{user}{profile}{userId});
	while (my $tag = $getSelfTags->fetchrow_hashref) {
		push(@{$self->{user}{selftags}},{tag=>$tag});
	}
	$getSelfTags->finish;

	#get other photos
	my $getPhotos = $self->{dbh}->prepare("SELECT * FROM photos WHERE rank > 1 and rank <= 5 and userId=?");
	$getPhotos->execute($self->{user}{profile}{userId});
	while (my $photo = $getPhotos->fetchrow_hashref) {
		push(@{$self->{user}{photos}},{photo => $photo});
	}
	$getPhotos->finish;



	print processTemplate($self->{user},"portalize/profile.html",0,"portalize/outside.html");

}

sub displayMyUpdates() {   

	 my $self = shift;

# group by days# show # of thumbs up and downs, # of comments received# show new tags    

		my $offset = $self->{query}->param('offset') || 0;    my $getProfileThumbs = $self->{dbh}->prepare("SELECT COUNT(1) FROM thumb WHERE profileId=? AND type=? AND DATE(insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))");    my $getQuestionThumbs = $self->{dbh}->prepare("SELECT COUNT(1) FROM bling inner join questionresponse on bling.questionresponseId=questionresponse.id WHERE questionresponse.userId=? AND type=? AND DATE(insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))");
    my $getPhotoThumbs = $self->{dbh}->prepare("SELECT COUNT(1) FROM photo_contest_bling inner join photo_contest_entry on photo_contest_bling.entryId=photo_contest_entry.id WHERE photo_contest_entry.userId=? AND type=? AND DATE(photo_contest_bling.insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))");
    my $getTags = $self->{dbh}->prepare("SELECT value,left(value,35) as shortvalue,addedById,anonymous FROM tag inner join tagRef on tag.id=tagRef.tagId WHERE tagRef.profileId=? AND DATE(dateAdded) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))");

    foreach my $daysago ($offset .. ($offset + 6)) {
        my %thisday;

        $getProfileThumbs->execute($self->{user}{user}{id},'U',$daysago);
        $thisday{thumbs}{pups} = $getProfileThumbs->fetchrow;
        $getProfileThumbs->execute($self->{user}{user}{id},'D',$daysago);
        $thisday{thumbs}{pdowns} = $getProfileThumbs->fetchrow;

        $getQuestionThumbs->execute($self->{user}{user}{id},'U',$daysago);
        $thisday{thumbs}{qups} = $getQuestionThumbs->fetchrow;
        $getQuestionThumbs->execute($self->{user}{user}{id},'D',$daysago);
        $thisday{thumbs}{qdowns} = $getQuestionThumbs->fetchrow;

        $getPhotoThumbs->execute($self->{user}{user}{id},'U',$daysago);
        $thisday{thumbs}{cups} = $getPhotoThumbs->fetchrow;
        $getPhotoThumbs->execute($self->{user}{user}{id},'D',$daysago);
        $thisday{thumbs}{cdowns} = $getPhotoThumbs->fetchrow;


        $thisday{thumbs}{ups} = $thisday{thumbs}{pups} + $thisday{thumbs}{qups} + $thisday{thumbs}{cups};
        $thisday{thumbs}{downs} = $thisday{thumbs}{pdowns} + $thisday{thumbs}{qdowns} + $thisday{thumbs}{cdowns};


        $getTags->execute($self->{user}{user}{id},$daysago);

        while (my $tag = $getTags->fetchrow_hashref) {
             my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{addedById}) or next;
            push(@{$thisday{tags}},{tag => $tag,profile=> $U->profile()});
        }
        $thisday{day}{daysago} = $daysago;
        $thisday{day}{date} = time() - ($daysago * 24 * 60 * 60);
        push(@{$self->{user}{days}},\%thisday);
        $self->{user}{page}{offset} = $daysago;

    }

    print processTemplate($self->{user},"portalize/profile.myupdates.html",0,"portalize/outside.html");
}

