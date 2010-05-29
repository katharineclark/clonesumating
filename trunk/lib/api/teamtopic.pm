package api::teamtopic;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use util;
use Users;

our @ISA = qw(api);

sub response {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');
	my $topicId = $self->{query}->param('topicId');
	my $response = $self->{query}->param('response');

    $response  =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    util::cleanHtml($response);
    
	my $sql = "INSERT INTO teamResponse (teamId,userId,teamTopicId,response,date) VALUES (?,?,?,?,NOW())";
	$self->{dbh}->do($sql,undef,$teamId,$self->{user}{user}{id},$topicId,$response);

	my $id = $self->{dbh}->selectrow_array("SELECT last_insert_id()");

	my $data = $self->hashToXML('response',{ responseId => $id, handle => $self->{user}{user}{handle},linkhandle => $self->{user}{user}{linkhandle} } );

	$self->generateList($topicId);
	#return $self->generateResponse('ok','handleTopicResponse',$data);
}

sub generateList {
	my $self = shift;
	my $tid = shift || $self->{query}->param('topicId');
	my $limit = shift || $self->{query}->param('limit') || 3;

	$limit = $limit eq 'all' ? '' : "LIMIT $limit";

	my $sql = "SELECT id as responseId,response,userId FROM teamResponse WHERE teamTopicId = $tid ORDER BY date DESC $limit";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $data;
	while (my $r = $sth->fetchrow_hashref) {
		my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $r->{userId});
		$r->{handle} = $User->{profile}->{handle};
		$r->{linkhandle} = $User->{profile}->{linkhandle};
		$data .= $self->hashToXML('Presponse',$r);
	}

	if (wantarray) {
		return ($tid,$data);
	} else {
		return $self->generateResponse('ok','handleGenerateList',$data);
	}
}


sub deleteResponse {
	my $self = shift;
	my $rid = $self->{query}->param('responseId');
	my $teamId = $self->{query}->param('teamId');
	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId) or return $self->generateResponse('fail','','something went awry.');
	my ($tid,$tuid,$ruid) = $self->{dbh}->selectrow_array("SELECT t.id,t.userId,r.userId FROM teamTopic t, teamResponse r WHERE t.id=r.teamTopicId AND t.teamId = ? AND r.id = ?",undef,$rid);
	if ($tid) {
		return $self->generateResponse('fail','','something went awry.') unless $team->isMember($tuid) || $team->isMember($ruid);

		$self->{dbh}->do("DELETE FROM teamResponse WHERE id = ?",undef,$rid);

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
	my $teamId = $self->{query}->param('teamId');

	$topic  =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	util::cleanHtml($topic);

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId) or return $self->generateResponse('fail','','invalid team');
	return $self->generateResponse('fail','','not a member') unless $team->isMember($self->{user}{user}{id});

	$self->{dbh}->do("INSERT INTO teamTopic (teamId,userId,question,date,enabled) VALUES (?,?,?,NOW(),1)",undef,$teamId,$self->{user}{user}{id},$topic);
	my $id = $self->{dbh}->selectrow_array("SELECT last_insert_id()");

	return $self->generateResponse('ok','handleNewTopic',"<topicId>$id</topicId><title><![CDATA[$topic]]></title>");
}

sub close {
	my $self = shift;
	my $topic = $self->{query}->param('topicId');
	my $cnt = $self->{dbh}->selectall_arrayref("SELECT t.id,count(r.id) FROM teamTopic t LEFT JOIN teamResponse r ON r.profileTopicId=t.id WHERE t.id=$topic AND t.userid=$self->{user}{user}{id} AND enabled=1 GROUP BY 1");
	my $del = $self->{dbh}->prepare("DELETE FROM teamTopic WHERE id = ? AND userId=$self->{user}{user}{id}");
	my $upd = $self->{dbh}->prepare("UPDATE teamTopic SET enabled=0 WHERE id=? AND userId=$self->{user}{user}{id}");
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
	my $starter = $self->{dbh}->selectrow_array("SELECT userId FROM teamTopic WHERE id = ?",undef,$topicId);
	if ($starter == $self->{user}{user}{id}) {
		$self->{dbh}->do("DELETE FROM teamResponse WHERE teamTopicId = ?",undef,$topicId);
		$self->{dbh}->do("DELETE FROM teamTopic WHERE id = ?",undef,$topicId);
	}
	return $self->generateResponse('ok','handleTopicDelete',"<id>$topicId</id>");
}

1;
