package api::photocontest;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;

our @ISA = qw(api);


sub vote {
	my $self = shift;
	my $xml;	
	my $entryId = $self->{query}->param('entryId');
	my $vote = $self->{query}->param('vote');


   # get the current contest
        my $sql = "SELECT * FROM photo_contest WHERE itson=1 AND startDate <= NOW() ORDER BY startDate DESC LIMIT 1";
        my $getContest = $self->{dbh}->prepare($sql);
        $getContest->execute;
        my $contest = $getContest->fetchrow_hashref;
        $getContest->finish;

#		warn "user $self->{user}{user}{id} voting $vote for $entryId in conteste $contest->{id}";
		my $removePrevVote = $self->{dbh}->prepare("DELETE FROM photo_contest_bling WHERE userId=? and entryId=?");
		$removePrevVote->execute($self->{user}{user}{id},$entryId);
		$removePrevVote->finish;
        my $insertVote = $self->{dbh}->prepare("INSERT INTO photo_contest_bling (contestId,entryId,userId,type,insertDate) VALUES (?,?,?,?,NOW());");

		$insertVote->execute($contest->{id},$entryId,$self->{user}{user}{id},$vote);
		$insertVote->finish;

  
        my $sql = "select photo_contest_entry.* from photo_contest_entry left join photo_contest_bling on photo_contest_entry.id=photo_contest_bling.entryId and photo_contest_bling.userId=? WHERE photo_contest_entry.contestId=? AND photo_contest_bling.id is null ORDER BY RAND() limit 1;";
         
        my $getRandomEntry = $self->{dbh}->prepare($sql);
        $getRandomEntry->execute($self->{user}{user}{id},$contest->{id});
		my $entry;
        if ($entry = $getRandomEntry->fetchrow_hashref) {
        my $User = Users->new(dbh => $self->{dbh}, cache => new Cache, userId => $entry->{userId});
             

    	$sql = "SELECT height,width FROM photos WHERE id=?";
        my $getPhoto = $self->{dbh}->prepare($sql);
        $getPhoto->execute($entry->{photoId});
        my $photo = $getPhoto->fetchrow_hashref;
        $getPhoto->finish;

        if ($photo->{width} < 400) {
            $photo->{pad} = 1;
        } else {
			$photo->{pad} = 0;
		}
        $self->{user}{entry} = $entry;
        $self->{user}{profile} = $User->profile;
        $self->{user}{contest} = $contest; 
    
        $sql = "SELECT count(1) FROM photo_contest_entry WHERE contestId=?";
        my $getCount = $self->{dbh}->prepare($sql);
        $getCount->execute($contest->{id});
        my $entries = $getCount->fetchrow;
        $getCount->finish; 
    
        $sql = "SELECT count(1) FROM photo_contest_bling inner join photo_contest_entry on photo_contest_bling.entryId=photo_contest_entry.id WHERE photo_contest_bling.userId=? and photo_contest_entry.contestId=?";
        $getCount = $self->{dbh}->prepare($sql);
        $getCount->execute($self->{user}{user}{id},$contest->{id});
        my $votes = $getCount->fetchrow;
        $getCount->finish;

		$xml = qq|<entryId>$entry->{id}</entryId>
				  <userId>$User->{profile}{userId}</userId>
				  <photoId>$entry->{photoId}</photoId>
				  <handle><![CDATA[$User->{profile}{handle}]]></handle>
				  <linkhandle>$User->{profile}{linkhandle}</linkhandle>
				  <entries>$entries</entries>
				  <pad>$photo->{pad}</pad>
				  <votes>$votes</votes>|;

		} else {

			$xml = qq|<noentry>1</noentry>|;
		}

		warn $self->generateResponse("ok","displayNextEntry",$xml);
		return $self->generateResponse("ok","displayNextEntry",$xml);


}

1;
