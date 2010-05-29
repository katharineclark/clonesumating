#!/usr/bin/perl

use strict;

use lib qw(. ../lib ../../lib lib);
use Profiles;
use template2;
use CM_Tags;



{

	my $P = Profiles->new();

$P->{user}{system}{tab} = 'Questions';


my $sql = "SELECT count(1) FROM questionresponse;";
my $sth = $P->{dbh}->prepare($sql);
$sth->execute;
$P->{user}{page}{contentcount} = $sth->fetchrow;
$sth->finish;


# load most recent question
{
	my $sql = qq|select * from questionoftheweek where date < NOW() order by date desc limit 5;|;
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	while (my $question = $sth->fetchrow_hashref) {
		$sql = qq|SELECT count(1) FROM questionresponse WHERE questionId=?|;
		my $getresp = $P->{dbh}->prepare($sql);
		$getresp->execute($question->{id});
		$question->{responses} = $getresp->fetchrow;
		push(@{$P->{user}{questions}},{question=>$question});
	}
	$sth->finish;

	$sql = qq|SELECT count(1) FROM questionoftheweek WHERE date < NOW();|;
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	$P->{user}{question}{count} = $sth->fetchrow - 1;
	$sth->finish;
}


# get most recent user topics

{ 

	my $sql = qq|select count(1) from profileTopic where enabled=1;|;
	my $sth = $P->{dbh}->prepare($sql);
	my $count = 0;
	$sth->execute;
	$P->{user}{page}{conversations} = $sth->fetchrow;
	$sth->finish;
}



# load most recent photo contest

{

	my $sql = qq|SELECT * FROM photo_contest WHERE itson=1 and startDate <= NOW() order by startDate desc limit 1;|;
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	$P->{user}{photocontest} = $sth->fetchrow_hashref;
	$sth->finish;

	$P->{user}{photocontest}{tag} = lc cleanTag($P->{user}{photocontest}{tagname} . '_contest'); 


	$sql = qq|SELECT count(1) FROM photo_contest_entry WHERE contestId=$P->{user}{photocontest}{id}|;
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	$P->{user}{photocontest}{responses} = $sth->fetchrow;
	$sth->finish;

	$sql = qq|SELECT count(1) FROM photo_contest WHERE startDate <= NOW()|;
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	$P->{user}{photocontest}{count} = $sth->fetchrow - 1;
	$sth->finish;

        $sql = qq|SELECT userId,photoId FROM photo_contest_entry WHERE contestId = $P->{user}{photocontest}{id} ORDER BY RAND() LIMIT 6|;
        $sth = $P->{dbh}->prepare($sql);
        $sth->execute;
        while (my ($uid,$pid) = $sth->fetchrow_array) {
        	my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or next;
			my $profile = $User->profile;
			$profile->{photoId} = $pid;
			push(@{ $P->{user}{photocontestentries} },{profile => $profile});
        }
        $sth->finish;

}

# load some conversations
{ 
	
	my $sql = "SELECT * FROM profileTopic ORDER BY date DESC limit 5;";
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	while (my $convo = $sth->fetchrow_hashref) {
            my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $convo->{userId}) or next;
			push(@{$P->{user}{conversations}},{topic => $convo,profile=>$User->profile});
	}
	$sth->finish;
}
		
print $P->Header();
print processTemplate($P->{user},'play/index.html');

}
