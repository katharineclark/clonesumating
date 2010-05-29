package EXPERIMENTAL::peeps;


use strict;
 
use Data::Dumper;
use Date::Calc qw(Delta_DHMS Today_and_Now);
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use CGI;
use POSIX qw(strftime);


use lib qw(lib ../lib);
use template2;
use Profiles;
use cache;
use faDates;
use sphere;
use portalize;

our @ISA = qw(portalize);
our %db_sth;

sub doPortal {
	my $self = shift;
	my $dbActive = shift;

	$self->{user}{global}{section} = 'peeps';
    $self->{user}{global}{imgserver} = "img.consumating.com";

	if ($self->{command} eq "") {
		$self->displayPeeps();
	} elsif ($self->{command} eq "/onlinenow") {
		$self->displayOnline();
	} elsif ($self->{command} eq "/peeplist") {
		$self->displayOnline('popup');
	} elsif ($self->{command} eq "/myupdates") {
		$self->displayMyUpdates();
	} elsif ($self->{command} eq "/list") {
		$self->displayHistory();
	}



	return 0;
}


sub displayMyUpdates() {
	my $self = shift;

# group by days
# show # of thumbs up and downs, # of comments received
# show new tags

	my $offset = $self->{query}->param('offset') || 0;

	my $getProfileThumbs = $self->{dbh}->prepare("SELECT COUNT(1) FROM thumb WHERE profileId=? AND type=? AND DATE(insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))");
    my $getQuestionThumbs = $self->{dbh}->prepare("SELECT COUNT(1) FROM bling inner join questionresponse on bling.questionresponseId=questionresponse.id WHERE questionresponse.userId=? AND type=? AND DATE(insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))");
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

    print processTemplate($self->{user},"portalize/peeps.myupdates.html",0,"portalize/outside.html");
}

sub displayOnline() {
    my $self = shift;
	my $mode = shift;

    my %sphere = getSphere($self->{dbh},$self->{user});
	my $onlinenow = getMinisphere(join(",",keys(%sphere)),$self);


	foreach my $uid (sort {$onlinenow->{$a} <=> $onlinenow->{$b}} keys %{$onlinenow}) {

			  my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid) or next;
			$U->{profile}{minutes} = $onlinenow->{$uid};
			if ($onlinenow->{$uid} <= 15) {
				$U->{profile}{onlinenow} = 1;
			}
			push(@{$self->{user}{onlinenow}},{user => $U->profile});

	}

	if ($mode ne "popup") {
	# get tags the online people have been adding or receiving


	my $sql = "SELECT value,left(value,35) as shortvalue,profileId,addedById,(TIME_TO_SEC(TIMEDIFF(NOW(),tagRef.dateAdded)) / 60) as minutes FROM tag inner join tagRef on tag.id=tagRef.tagId WHERE profileId in (" . join(",",keys(%{$onlinenow})) . ") OR addedById in (" . join(",",keys(%{$onlinenow})) . ") order by tagRef.dateAdded DESC limit 50;";
	my $getTags = $self->{dbh}->prepare($sql);
	$getTags->execute;
	while (my $tag = $getTags->fetchrow_hashref) {
		
              my $tagee = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{profileId}) or next;
              my $tager = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{addedById}) or next;
		
			push(@{$self->{user}{recenttags} },{tag => $tag,tagee => $tagee->profile, tager => $tager->profile});

	}
    	print processTemplate($self->{user},"portalize/peeps.onlinenow.html",0,"portalize/outside.html");
	} else {
    	print processTemplate($self->{user},"portalize/peeps.peeplist.html",1);
	}


}


sub displayHistory() {
	my ($self) = shift;

	my %sphere = getSphere($self->{dbh},$self->{user});

	foreach my $uid (keys(%sphere)) {
			my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid) or next;
			push(@{$self->{user}{peeps}},{profile =>$User->profile()});	
	}


	print processTemplate($self->{user},"portalize/peeps.list.html",0,"portalize/outside.html");


}


sub loadQuestion {
	my $P = shift;
	my ($qid) = @_;

	my $sth = $P->{dbh}->prepare("SELECT question,date,id FROM questionoftheweek WHERE ID=?");
	$sth->execute($qid);
	my $r = $sth->fetchrow_hashref;
	$sth->finish;
	return $r;
}


sub loadTag {
    my $P = shift;
    my ($qid) = @_;


    my $sth = $P->{dbh}->prepare("SELECT value,id FROM tag WHERE id=?");
    $sth->execute($qid);
    my $r = $sth->fetchrow_hashref;
    $sth->finish;
    return $r;



}

sub loadContest {
    my $P = shift;
    my ($qid) = @_;


    my $sth = $P->{dbh}->prepare("SELECT name,shortname,description,id  FROM photo_contest WHERE ID=?");
    $sth->execute($qid);
    my $r = $sth->fetchrow_hashref;
    $sth->finish;
    return $r;



}





sub getMinisphere {
    my ($spherepeople,$P) = @_;
	my $minisphere;
        my $sql = "SELECT users.id,(TIME_TO_SEC(TIMEDIFF(NOW(),users.lastActive)) / 60) as minutes FROM users inner join profiles on users.id=profiles.userId WHERE users.id IN ($spherepeople) ORDER BY lastActive desc;";
        my $sth = $P->{dbh}->prepare($sql);
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
		
		$P->{user}{page}{onlinenow} = $onnow;


        $minisphere->{$P->{user}{user}{id}} = 1;
	return $minisphere;
}


sub displayPeeps() {
	my $self = shift;

	
	my $offset = $self->{query}->param('offset') || 0;
	# get new convos, questions, 
	my %sphere = getSphere($self->{dbh},$self->{user});
    my $onlinenow = getMinisphere(join(",",keys(%sphere)),$self);

	my $pc = $self->{query}->param('exclude_photos') || 1;	
	my $pq = $self->{query}->param('exclude_questions') || 1;
	my $pt = $self->{query}->param('exclude_topics') || 1;

	$self->{user}{page}{exclude_photos} = $pc if ($pc eq "x");
    $self->{user}{page}{exclude_questions} = $pq if ($pq eq "x");
    $self->{user}{page}{exclude_topics} = $pt if ($pt eq "x");

	my @queries;

	if ($pc == 1) {
		push(@queries,"(select null as text,photoId,userId,'photo' as type,photo_contest_entry.insertDate as date,id,contestId as contestId,1 as enabled from photo_contest_entry where userId in (" . join(",",keys(%sphere)) . "))");
	} 
	if ($pq == 1) {
		push(@queries,"(select answer as text,photoId,userId,'qow' as type,date,id,questionId as contestId,1 as enabled from questionresponse where userId in (" . join(",",keys(%sphere)) . "))");
	}
	if ($pt == 1) {
		push(@queries,"(select question as text,null as photoId,userId,'topic' as type,date,id,null as contestId,enabled from profileTopic where userID in (" . join(",",keys(%sphere)) . "))");
	}
	my $sql = join(" UNION ",@queries) . " order by date desc limit $offset,20";

	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $getQuestion = $self->{dbh}->prepare("SELECT question,id FROM questionoftheweek WHERE id=?");
	my $getContest = $self->{dbh}->prepare("SELECT description,name,shortname,tagname,id FROM photo_contest WHERE id=?");
	my $getQuestionVote = $self->{dbh}->prepare("SELECT type as direction FROM bling WHERE questionresponseId=? and userId=?");
	my $getPhotoVote = $self->{dbh}->prepare("SELECT type AS direction FROM photo_contest_bling WHERE entryId=? and userId=?");
	my $getResponseCount = $self->{dbh}->prepare("SELECT count(id) as responses FROM profileResponse WHERE profileTopicId=?");

	while (my $newstuff = $sth->fetchrow_hashref) {
		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $newstuff->{userId}) or next;
		my ($contest,$vote);
		$U->{profile}{daysleft} = 8 - $sphere{$U->{profile}{id}}{days} if ($sphere{$U->{profile}{id}}{days} < 10);
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
		push(@{$self->{user}{newstuff}},{content=>$newstuff,user=>$U->profile,contest=>$contest,vote=>$vote});
	}

	$self->{user}{page}{offset} = $offset + 20;
	print processTemplate($self->{user},"portalize/peeps.html",0,"portalize/outside.html");

}





1;
