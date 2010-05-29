#!/usr/bin/perl

use strict;
 
use lib "lib";
use Profiles;
use template2;
use sphere;


{

	my $P = Profiles->new();
	my %sphere = getSphere($P->{dbh},$P->{user});

	my $onmyhotlist = $P->{dbh}->prepare("SELECT count(1) FROM hotlist WHERE userId=? and profileId=?");
	foreach my $uid (sort {$sphere{$b}{'actionTime'} cmp $sphere{$a}{'actionTime'}} keys %sphere) {
			if ($sphere{$uid}{reason} eq "hotlist" || $sphere{$uid}{reason} eq 'newmessages') {
				#this person is in the hotlist or something, so we don't need to show them
				next;
			}
			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or next;

			# load up extra data like which question they gave a thumb up to, or which contest entry you liked
			my $data;
			if ($sphere{$uid}{questionId}) {
				$data = loadQuestion($P,$sphere{$uid}{questionId});
			} elsif ($sphere{$uid}{tagId}) {
				$data = loadTag($P,$sphere{$uid}{tagId});
			} elsif ($sphere{$uid}{contestId}) {
				$data = loadContest($P,$sphere{$uid}{contestId});
			}

			$onmyhotlist->execute($P->{user}{user}{id},$uid);
			$User->{profile}{onmyhotlist} = $onmyhotlist->fetchrow;

			if ($sphere{$uid}{days} == 0) {
				# this person was thumbed today
				push(@{$P->{user}{today}},{profile => $User->profile,reason=>$sphere{$uid},data=>$data});	
			} elsif ($sphere{$uid}{days} == 1) {
				# this person was thumbed yesterday
				push(@{ $P->{user}{yesterday}},{profile => $User->profile,reason=>$sphere{$uid},data=>$data});
			} elsif ($sphere{$uid}{days} == 2) {
			    push(@{ $P->{user}{'2daysago'}},{profile => $User->profile,reason=>$sphere{$uid},data=>$data});
			} else {
				# this person was thumbed this week
				push(@{ $P->{user}{thisweek}},{profile => $User->profile,reason=>$sphere{$uid},data=>$data});
			}
		
	}


	my $onlinenow = getMinisphere(join(",",keys(%sphere)),$P);

	if (0) {
	foreach my $uid (sort {$onlinenow->{$b} <=> $onlinenow->{$a}} keys %{$onlinenow}) {

            my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $uid) or next;
			push(@{ $P->{user}{onlinenow}},{profile => $User->profile});

	}
	}


	print $P->Header();
	print processTemplate($P->{user},"updates/history.html");


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
