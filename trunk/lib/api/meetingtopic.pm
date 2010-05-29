package api::meetingtopic;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use Users;
use util;
use Alerts;
use template2;
use blog;

our @ISA = qw(api);


sub deleteTagById {

	my $self = shift;

    my $tag = $self->{query}->param('tagId');
    my $topic = $self->{query}->param('topicId');
# make sure this is the owner of the topic
	my $checkOwner = $self->{dbh}->prepare("SELECT userId FROM profileTopic WHERE id=$topic");
	$checkOwner->execute;
	my $oid = $checkOwner->fetchrow;
	$checkOwner->finish;
	if ($self->{actingUser} && $oid eq $self->{actingUser}) {
		$self->{dbh}->do("DELETE FROM topicTagRef WHERE topicId=$topic AND tagId=$tag");
	} else {
        return $self->generateResponse("fail","","Authentication Required");
	}

}

sub cleanTag {
    my ($tag) = @_;

# clean anything that isn't alpha, numeric, or an underscore
# also allow 8859-1 letters, but not symbols

    $tag =~ s/[^A-Za-z0-9\_\xc0-\xff]//gsm;
    return $tag;


}

sub tag {
	
    my $self = shift;

    my $tag = $self->{query}->param('tag');
	$tag = cleanTag($tag);
	my $topic = $self->{query}->param('topicId');
    if ($self->{actingUser}) {
        my $data;
        foreach $tag (tagSplit($tag)) {
            my $tid = addTag($self->{dbh},$tag,$self->{actingUser},$topic);
            $data .= "<tag><id>$tid</id><value>$tag</value></tag>\n";
        }
        return length $data ? $self->generateResponse("ok","handleTopicTag",$data) : $self->generateResponse("fail","","not allowed!");
    } else {
        return $self->generateResponse("fail","","Authentication Required");
    }

}


sub tagSplit {
        my ($taglist) = @_;

        my @tags;

        while ($taglist =~ /"(.*?)"/) {
            my $tag = $1;
            $taglist =~ s/"$tag"//gsm;
        }
        push(@tags,split(/\s+/,$taglist));

        return @tags;
}

sub addTag {
	my ($dbh,$tag,$userId,$topic) = @_;
		my $tid;

        my $sql = "SELECT id FROM tag WHERE value=?";
        my $sth = $dbh->prepare($sql);
        $sth->execute($tag);
        if (!( $tid = $sth->fetchrow)) {
            $tag = lc($tag);
            $sql = "INSERT INTO tag (value,insertDate,addedBy) VALUES (?,NOW(),?)";
            $sth = $dbh->prepare($sql);
            $sth->execute($tag,$userId);
            $tid = $sth->{mysql_insertid};
        }
        $sth->finish;

		$sth = $dbh->prepare("INSERT INTO topicTagRef (topicId,tagId,userId,date) VALUES (?,?,?,NOW());");
		$sth->execute($topic,$tid,$userId);
		$sth->finish;
}



sub postResponse {
	my $self = shift;
	 if ($self->{actingUser}) {
		my $ptid = $self->{query}->param('meetingTopicId');
		my $prid = $self->{query}->param('meetingResponseId');
		my $response = $self->{query}->param('response');
		util::cleanHtml($response);

		# check and see if this user already has a response. if so, update it. if not, insert
		my $new = 0;
		if ($prid) {
			my $sql = "UPDATE profileResponse SET response=? WHERE id=?";
			$self->{dbh}->do($sql,undef,$response,$prid);
		} else {
			my $sql="INSERT INTO profileResponse (userId,response,date,profileTopicId) VALUES (?,?,NOW(),?)";
			$new = 1;
			my $sth = $self->{dbh}->prepare($sql);
			$sth->execute($self->{actingUser},$response,$ptid);
			my $prid = $sth->{mysql_insertid};
			$sth->finish;
		}

		# do we need to send an alert?
		my $tuid = $self->{dbh}->selectrow_array("SELECT userId FROM profileTopic WHERE id = ?",undef,$ptid);
		my $Alert = Alerts->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tuid);
warn "SENDING ALERT? ".$Alert->checkSub('newcomment');
		if ($Alert->checkSub('newcomment')) {
			my $user = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tuid);
			if ($user) {
				my %hash;
				$hash{user} = $user->profile;
				$hash{response} = {response => $response};
				warn "SENDING: ".$Alert->send('newcomment',\%hash);
			}
		}
		
		$response = $self->{query}->param('response');
		$response =~ s/\n\n/<BR \/><BR \/>/gsm;	
		my $data = "<response>" . protectXML($response) . "</response>";
		$data .= "\n<responseId>$prid</responseId>";
		my $rsp = $self->generateResponse("ok","showResponse",$data);

		return $rsp;
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub response {
	my $self = shift;
	my $topicId = $self->{query}->param('topicId');
	my $response = $self->{query}->param('response');

    $response  =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	$response =~ s|\n|<br>|gsm;
    util::cleanHtml($response);

    
	my $sql = "INSERT INTO profileResponse (userId,profileTopicId,response,date) VALUES (?,?,?,NOW())";
	$self->{dbh}->do($sql,undef,$self->{user}{user}{id},$topicId,$response) or return $self->generateResponse('ok','handleProfileResponse',"We screwed up!");
	
	unless ($self->{dbh}->selectrow_array("SELECT * FROM profiletopicwatch WHERE userId=? AND topicId=?",undef,$self->{user}{user}{id},$topicId)) {
		$self->{dbh}->do("INSERT INTO profiletopicwatch (userId,topicId,date) VALUES (?,?,NOW());",undef,$self->{user}{user}{id},$topicId);
	}


	# do we need to send an alert?
	my $tuid = $self->{dbh}->selectrow_array("SELECT userId FROM profileTopic WHERE id = ?",undef,$topicId);
	if ($tuid != $self->{user}{user}{id}) {
		my $Alert = Alerts->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tuid);
	warn "SENDING ALERT? ".$Alert->checkSub('newcomment');
		if ($Alert->checkSub('newcomment')) {
			my $user = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tuid);
			if ($user) {
				my %hash;
				$hash{user} = $user->profile;
				$hash{response} = {response => $response};
				warn "SENDING: ".$Alert->send('newcomment',\%hash);
			}
		}
	}
		

	my $id = $self->{dbh}->selectrow_array("SELECT last_insert_id()");

	my $data = $self->hashToXML('response',{ responseId => $id, handle => $self->{user}{user}{handle},linkhandle => $self->{user}{user}{linkhandle} } );

	util::shortenString($response,80);
	util::cleanHtml($response,'everything');
	
	$self->{cache}->set('justoverheard',[$id,$response,$self->{user}{user}{id},$self->{dbh}->selectrow_array("SELECT userId FROM profileTopic WHERE id = $topicId")]);

	warn $self->generateResponse('ok','handleProfileResponse',($self->generateList($topicId))[1]);
	return $self->generateResponse('ok','handleProfileResponse',($self->generateList($topicId))[1]);
}

sub generateList {
	my $self = shift;
	my $tid = shift || $self->{query}->param('topicId');
	my $limit = shift || $self->{query}->param('limit') || 3;

	$limit = $limit eq 'all' ? '' : "LIMIT $limit";

	my $sql = "SELECT id as responseId,response,userId FROM profileResponse WHERE profileTopicId = $tid ORDER BY date DESC $limit";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $data;
	while (my $r = $sth->fetchrow_hashref) {
		($r->{handle},$r->{linkhandle}) = $self->{util}->getHandle($r->{userId});
		$data .= $self->hashToXML('Presponse',$r);
	}

	if (wantarray) {
		return ($tid,$data);
	} else {
		return $self->generateResponse('ok','handleGenerateList',$data);
	}
}


sub addWatch {
	my $self = shift;
	my $tid = $self->{query}->param('topicId');
warn "addWatch $tid";
	$self->{dbh}->do("INSERT INTO profiletopicwatch (userId,topicId,date) VALUES ($self->{user}{user}{id},$tid,NOW());");
	return $self->generateResponse('ok');
}

sub removeWatch {
    my $self = shift;
    my $tid = $self->{query}->param('topicId');
    $self->{dbh}->do("DELETE FROM  profiletopicwatch WHERE userId=$self->{user}{user}{id} and topicId=$tid;");
    return $self->generateResponse('ok');

}

sub deleteResponse {
	my $self = shift;
	my $rid = $self->{query}->param('responseId');
warn "DELETE RESPONSE $rid";
	my $tid = $self->{dbh}->selectrow_array("SELECT t.id FROM profileTopic t, profileResponse r WHERE t.id=r.profileTopicId AND t.userId = $self->{user}{user}{id} AND r.id = ?",undef,$rid);
	if ($tid) {
		$self->{dbh}->do("DELETE FROM profileResponse WHERE id = ?",undef,$rid);

		my ($tid,$data) = $self->generateList($tid);
		
		$data .= "<deletedId>$rid</deletedId>";

		return $self->generateResponse('ok','handleResponseDelete',$data);
	} else {
		return $self->generateResponse('fail','','something went awry.');
	}
}

sub start {
	my $self = shift;
	my $topic = $self->{query}->param('topic');

	$topic  =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	util::cleanHtml($topic);

	$self->{dbh}->do("INSERT INTO profileTopic (userId,question,date,enabled,type) VALUES (?,?,NOW(),1,'meeting')",undef,$self->{user}{user}{id},$topic);
	my $id = $self->{dbh}->selectrow_array("SELECT last_insert_id()");
    $self->{dbh}->do("INSERT INTO profiletopicwatch (userId,topicId,date) VALUES (?,?,NOW());",undef,$self->{user}{user}{id},$id);

	my $blog = blog->new(db => $self->{dbh});
	if ($blog->blogthis($self->{user}{user}{id},'topic')) {
		$self->{user}{topic}{question} = $topic;
		$self->{user}{topic}{id} = $id;
		my $html = processTemplate($self->{user},"blog/topic.html",1);
		$blog->post($self->{user}{user}{id},'topic','My new topic on Consumating',$html);
	}

	return $self->generateResponse('ok','handleNewTopic',"<topicId>$id</topicId><title><![CDATA[$topic]]></title>");
}

sub close {
	my $self = shift;
	my $cnt = $self->{dbh}->selectall_arrayref("SELECT t.id,count(r.id) FROM profileTopic t LEFT JOIN profileResponse r ON r.profileTopicId=t.id WHERE t.userid=$self->{user}{user}{id} AND enabled=1 AND type='meeting' GROUP BY 1");
	my $del = $self->{dbh}->prepare("DELETE FROM profileTopic WHERE id = ? AND userId=$self->{user}{user}{id}");
	my $upd = $self->{dbh}->prepare("UPDATE profileTopic SET enabled=0 WHERE id=? AND userId=$self->{user}{user}{id}");
	for (@$cnt) {
		if ($_->[1]) {
			$upd->execute($_->[0]);
		} else {
			$del->execute($_->[0]);
		}
	}
	return $self->generateResponse('ok','','');
}

sub delete {
	my $self = shift;
	my $topicId = $self->{query}->param('topicId');
	my $starter = $self->{dbh}->selectrow_array("SELECT userId FROM profileTopic WHERE id = ?",undef,$topicId);
	if ($starter == $self->{user}{user}{id}) {
		$self->{dbh}->do("DELETE FROM profileResponse WHERE profileTopicId = ?",undef,$topicId);
		$self->{dbh}->do("DELETE FROM profileTopic WHERE id = ?",undef,$topicId);
		$self->{dbh}->do("DELETE FROM profiletopicwatch WHERE topicId=?",undef,$topicId);
	}
	return $self->generateResponse('ok','handleTopicDelete',"<id>$topicId</id>");
}

sub overheard {
	my $self = shift;

	if (0) {
	my @d = $self->{dbh}->selectrow_array("SELECT response,r.userId,t.userId,r.id FROM profileResponse r,profileTopic t WHERE t.id=r.profileTopicId AND type='meeting' ORDER BY id DESC LIMIT 1");	
	$d[0] = util::shortenString($d[0],80);
	util::cleanHtml($d[0]);
	my $T = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $d[2]);
	my $R = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $d[1]);
	return $self->generateResponse('ok','handleOverheard',"<text>$d[0]</text><linkhandle>$T->{profile}{linkhandle}</linkhandle><userId>$R->{profile}{userId}</userId><photoId>$R->{profile}{primaryPhoto}</photoId><id>$d[3]</id>");
	}

	my $dat = $self->{cache}->get('justoverheard');
	my $R = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $dat->[2]);
	my $T = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $dat->[3]);

	$dat->[1] = util::shortenString($dat->[1],80);
	util::cleanHtml($dat->[1]);

	return $self->generateResponse('ok','handleOverheard',"<id>$dat->[0]</id><text><![CDATA[$dat->[1]]]></text><linkhandle>$T->{profile}{linkhandle}</linkhandle><userId>$R->{profile}{userId}</userId><photoId>$R->{profile}{primaryPhoto}</photoId>");
}

sub checkNew {
	my $self = shift;
	my $topicId= $self->{query}->param('topicId');
	my $lastId = $self->{query}->param('lastId');

warn "checkNew $topicId,$lastId";
	my $topicUser = $self->{dbh}->selectrow_array("SELECT userId FROM profileTopic WHERE id = ?",undef,$topicId);
	my $sth = $self->{dbh}->prepare("SELECT *,(TIME_TO_SEC(TIMEDIFF(NOW(),date))/60) as minutes FROM profileResponse WHERE profileTopicId = ? AND id > ?");
	$sth->execute($topicId,$lastId);
	my $data;
	while (my $r = $sth->fetchrow_hashref) {
warn "MYPROFILE? $self->{user}{user}{id} == $topicUser";
		$r->{myprofile} = $self->{user}{user}{id} == $topicUser ? 1 : 0;
		($r->{handle},$r->{linkhandle}) = $self->{util}->getHandle($r->{userId});
		$r->{timesince} = $self->{util}->timesince($r->{minutes});

		$self->{user}{response} = $r;
		$data .= processTemplate($self->{user},'view.topicDiv.html',1);
	}

	return $data || '<nogo/>';
}


1;
