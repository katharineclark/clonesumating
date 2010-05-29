package api::peeps;

use strict;
 
use lib qw(lib ../lib ../../lib);
use sphere;
use api;
use EXPERIMENTAL::peeps;
use template2;

our @ISA = qw(api);


sub getOnlinePeeps() {
	my $self = shift;

	#warn "Getting sphere for " . $self->{user}{user}{id};
	my %sphere = getSphere($self->{dbh},$self->{user});
	my $onlinenow = getMinisphere(join(",",keys(%sphere)),$self);
	my $data;

	my $newNotes = $self->{dbh}->prepare("SELECT COUNT(*) FROM messages WHERE fromId=? AND toId=$self->{user}{user}{id} AND isRead=0");

	foreach my $uid (keys %{$onlinenow}) {
 		my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid) or next;
		if ($onlinenow->{$uid} <=  15) {
			$User->{profile}{minutes} = $onlinenow->{$uid};
			$newNotes->execute($uid);
			$User->{profile}{newNotes} = $newNotes->fetchrow || 0;
warn "$User->{profile}{handle} - $uid : $onlinenow->{$uid}; $User->{profile}{newNotes}";
			$data .= $self->hashToXML("profile",$User->profile);
		}
	}

	$data = "<peeps>$data</peeps>";

	return $self->generateResponse("ok","updatePeeps",$data);


}

sub portalize {
	my $self = shift;

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

	print processTemplate($self->{user},"portalize/peeps.peeplist.html",1);

	return (0);
}

1;
