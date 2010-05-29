package api::team;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use points;

our @ISA = qw(api);

sub changeIncentive {
	my $self = shift;
	my $invite = $self->{query}->param('inviteId');
	my $points = $self->{query}->param('points');

	
	my ($teamId,$inviteUser) = $self->{dbh}->selectrow_array("SELECT teamId,userId FROM team_invites WHERE id = ?",undef,$invite);
	my $h = $self->{util}->getHandle($inviteUser);
	my $P = points->new(dbh => $self->{dbh}, cache => $self->{cache});

	my $teamname = $self->{dbh}->selectrow_array("SELECT name FROM teams WHERE id = ?",undef,$teamId);

	my $sth = $self->{dbh}->prepare("SELECT points FROM team_invite_incentives WHERE inviteId = ? AND userId = ?");
	$sth->execute($invite,$self->{user}{user}{id});
	if (defined (my $oldpoints = $sth->fetchrow)) {
		$self->{dbh}->do("UPDATE team_invite_incentives SET points = ? WHERE inviteId = ? AND userId = ?",undef,$points,$invite,$self->{user}{user}{id});
		$P->storeTransaction({userid => $self->{user}{user}{id}, points => $oldpoints - $points, type => 'team', desc => "update $teamname's incentive offer for $h"});
	} else {
		my $teamId = $self->{dbh}->selectrow_array("SELECT teamid FROM team_invites WHERE id = ?",undef,$invite);
		$self->{dbh}->do("INSERT INTO team_invite_incentives (teamId,inviteId,userId,points,date) VALUES (?,?,?,?,NOW())",undef,$teamId,$invite,$self->{user}{user}{id},$points);
		$P->storeTransaction({userid => $self->{user}{user}{id}, points => (-1 * $points), type => 'team', desc => "update $teamname's incentive offer for $h"});
	}
	$sth->finish;
	return $self->generateResponse('ok','','');
}

sub negotiate {
	my $self = shift;
	my $invite = $self->{query}->param('inviteId');
	my $notes = $self->{query}->param('comments');

	$self->{dbh}->do("UPDATE team_invites SET notes=? WHERE id=? AND userId=?",undef,$notes,$invite,$self->{user}{user}{id});
	return $self->generateResponse('ok','','');
}

sub acceptInvite {
	my $self = shift;
	my $inviteId = $self->{query}->param('inviteId');
	my $invite = $self->{dbh}->selectrow_hashref("SELECT * FROM team_invites WHERE id = ? AND userId=?",undef,$inviteId,$self->{user}{user}{id});
	unless ($invite->{id} == $inviteId) {
		return $self->generateResponse('fail','','');
	}

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $invite->{teamId});
	$team->addmember($self->{user}{user}{id},$invite);
	return $self->generateResponse('ok','','');
}

sub inviteUser {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId);
	if ($team) {
		warn $team->invite($self->{user}{user}{id},$self->{query}->param('handle'));
	}
	return $self->generateResponse('ok','','');
}

sub join {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId);
	if ($team) {
		warn "DOING TEAM JOIN FOR $self->{user}{user}{id} TO TEAM $teamId";
		warn $team->join($self->{user}{user}{id});
	}
	return $self->generateResponse('ok','refreshPage','');
}

sub joinvote {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');	
	my $joinId = $self->{query}->param('joinId');
	my $type   = $self->{query}->param('type');

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId) or return $self->generateResponse('fail','','');

	$self->{dbh}->do("DELETE FROM team_join_votes WHERE teamId=? AND team_join_id = ? AND userId = ?",undef,$teamId,$joinId,$self->{user}{user}{id});
	$self->{dbh}->do("INSERT INTO team_join_votes (teamId,team_join_id,userId,type,date) VALUES (?,?,?,?,NOW())",undef,$teamId,$joinId,$self->{user}{user}{id},$type);

	my $mc = scalar $team->members;

	warn "Member Count: $mc";
	my $votesneeded = int((2/3) * $mc);
	warn "Votes needed to complete join: $votesneeded";

    my $ups = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_join_votes WHERE teamId=? AND team_join_Id=? AND type='U'",undef,$teamId,$joinId);
    my $dns = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_join_votes WHERE teamId=? AND team_join_Id=? AND type='D'",undef,$teamId,$joinId);
	
	my $vc = $ups + $dns;
	
	if ($vc >= $votesneeded) {
		# we have a quorum, count em up!
		if ($ups > $dns) {
			$team->addmember($self->{dbh}->selectrow_array("SELECT userId FROM team_joins WHERE id =?",undef,$joinId));
		} elsif ($dns > $ups) {
			$team->reject($self->{dbh}->selectrow_array("SELECT userId FROM team_joins WHERE id =?",undef,$joinId));
		}
	}
	
	my $data = qq|<joinId>$joinId</joinId><votesneeded>$votesneeded</votesneeded><ups>$ups</ups><downs>$dns</downs>|;

	return $self->generateResponse('ok','updateJoinVote',$data);
}

sub boot {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');
	my $userId = $self->{query}->param('userId');

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId) or return $self->generateResponse('fail','','No team!');
	return $self->generateResponse('fail','',"You're not a member of this team!") unless $team->isMember($self->{user}{user}{id});

	$team->boot($userId);
	return $self->generateResponse('ok','refreshPage','');
}
sub bootvote {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');
	my $bootId = $self->{query}->param('bootId');
	my $type   = $self->{query}->param('type');

	
	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId) or return $self->generateResponse('fail','','No team!');

	$self->{dbh}->do("DELETE FROM team_boot_votes WHERE teamId=? AND team_boot_id=? AND userId=?",undef,$teamId,$bootId,$self->{user}{user}{id});
	$self->{dbh}->do("INSERT INTO team_boot_votes (teamId,team_boot_id,userId,type,date) VALUES (?,?,?,?,NOW())",undef,$teamId,$bootId,$self->{user}{user}{id},$type);

	my $mc = scalar $team->members;


    warn "Member Count: $mc";
    my $votesneeded = int((2/3) * $mc);
    warn "Votes needed to complete boot: $votesneeded";

    my $ups = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_boot_votes WHERE teamId=? AND team_boot_Id=? AND type='U'",undef,$teamId,$bootId);
    my $dns = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM team_boot_votes WHERE teamId=? AND team_boot_Id=? AND type='D'",undef,$teamId,$bootId);

	my $vc = $ups + $dns;
	warn "Vote: $vc";

	if ($vc >= $votesneeded) {
		# we have a quorum!
		warn "LETS DO IT";
		if ($ups > $dns) {
			warn "BOOTING";
			my $boot = $self->{dbh}->selectrow_hashref("SELECT userId FROM team_boots WHERE id = ?",undef,$bootId);
			$team->removemember($boot->{userId},$boot);
			$team->reject($boot->{userId});
			$self->{dbh}->do("DELETE FROM team_boots WHERE id = ?",undef,$bootId);
			$self->{dbh}->do("DELETE FROM team_boot_votes WHERE team_boot_id = ?",undef,$bootId);
		} elsif ($dns > $ups) {
			warn "NOT BOOTING";
			$self->{dbh}->do("DELETE FROM team_boots WHERE id = ?",undef,$bootId);
			$self->{dbh}->do("DELETE FROM team_boot_votes WHERE team_boot_id = ?",undef,$bootId);
		}
	}

    my $data = qq|<bootId>$bootId</bootId><votesneeded>$votesneeded</votesneeded><ups>$ups</ups><downs>$dns</downs>|;
	return $self->generateResponse('ok','updateBootVote',$data);
}
		

sub disband {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId) or return $self->generateResponse('fail','','no team!');
	return $self->generateResponse('fail','',"You're not the team leader!") if ($team->data('ownerId') != $self->{user}{user}{id});

	$team->disband();
	return $self->generateResponse('ok','refreshPage','');
}

sub checkmember {
	my $self = shift;
	my $teamId = $self->{query}->param('teamId');
	my $handle = $self->{query}->param('handle');

	my $team = team->new(dbh => $self->{dbh}, cache => $self->{cache}, id => $teamId) or return $self->generateResponse('fail','','no team!');

	if (my $userId = $self->{util}->getUserId($handle)) {
		if ($team->isMember($userId)) {
			return $self->generateResponse('ok','handleChangeOwner',"<userId>$userId</userId><handle><![CDATA[$handle]]></handle>");
		} else {
			return $self->generateResponse('fail','','User is not a member of this team, so they cannot be the new owner!');
		}
	} else {
		return $self->generateResponse('fail','','user not found');
	}
}




1;
