package api::system;

use strict;
 
use Digest::SHA1 qw(sha1_hex);

use lib qw(lib ../lib ../../lib);
use api;
use Users;

our @ISA = qw(api);

sub checkHandle {
	my $self = shift;
	my $sql;
	if ($self->{actingUser}) {
		 $sql = "SELECT count(1) FROM profiles WHERE handle=? and userId!=$self->{actingUser}";
	} else {
		$sql = "SELECT count(1) FROM profiles WHERE handle=?";
	}
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute($self->{query}->param('handle'));
	my $c = $sth->fetchrow;
	$sth->finish;
	if ($c > 0) {
		return $self->generateResponse("ok","overlapHandle",qq|<handle available="false" />|);
	} else {
		return $self->generateResponse("ok","",qq|<handle available="true" />|);
	}

	return;
}

sub checkEmail {
	my $self = shift;

	my $sql = "SELECT count(1) FROM users WHERE username=?";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute($self->{query}->param('username'));
	my $c = $sth->fetchrow;
	$sth->finish;
	if ($c > 0) {
		return $self->generateResponse("ok","overlapEmail",qq|<user available="false" />|);
	} else {
		return $self->generateResponse("ok","",qq|<user available="true" />|);
	}

	return;
}

sub getNewUsers {
	my $self = shift;

	my $sth = $self->{dbh}->prepare("SELECT id,TIMEDIFF(NOW(),createDate) FROM users ORDER BY createDate DESC LIMIT 10");
	$sth->execute;
	my $data;
	while (my ($id,$time) = $sth->fetchrow) {
		my $u = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $id);
		$data .= "<user><id>$id</id><handle><![CDATA[$u->{profile}->{handle}]]></handle><linkhandle><![CDATA[$u->{profile}->{linkhandle}]]></linkhandle><time>$time</time></user>";
	}
	$sth->finish;
	return $self->generateResponse('ok','listNewUsers',$data);
}

sub auth {
	my $self = shift;
	my $username = $self->{query}->param('username');
	my $password = $self->{query}->param('password');

	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, username => $username, password => $password);
	return $self->generateResponse('fail','',qq|Invalid username/password|) unless $U;

	my $hash = sha1_hex($username.'apple$#%pudding!*$^cheesecake');
	my $id = $U->{profile}{userId};
	
	return $self->generateResponse('ok','handleAuth',qq|<login userId="$id">$hash</login>|);
}

1;
