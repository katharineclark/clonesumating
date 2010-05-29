package Profile::Messages;

use strict;
use Page;
use Profile;

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;

	$self->prepare;
	$self->displayDefault;

	if ($self->{user}{user}{id}) {
		$self->{sth}{loadmessages}->execute($self->{user}{user}{id},$self->{user}{profile}{id},$self->{user}{profile}{id},$self->{user}{user}{id});
		my $firstUnread = 0;
		while (my $m = $self->{sth}{loadmessages}->fetchrow_hashref) {
			$m->{handle} = $self->{util}->getHandle($m->{fromId});
			if ($m->{isread}) {
				delete $m->{text};
			} elsif (!$firstUnread) {
				$m->{firstUnread} = 1;
				$firstUnread = 1;
			}
			push @{$self->{user}{messages}}, { message => $m };
		}
		if (!$firstUnread && ref $self->{user}{messages} eq 'ARRAY') {
			$self->{user}{messages}->[scalar(@{$self->{user}{messages}})-1]->{isread} = 0;
		}

		$self->{sth}->{setmessageread}->execute($self->{user}{user}{id},$self->{user}{profile}{id});
	}

	if ($self->{user}{user}{points} < 0) {
		$self->{user}{user}{points} = 0;
	}

	if ($self->{user}{user}{id}) {
		print $self->{P}->process('Profile/messages.html');
	} else {
		print $self->{P}->process('Profile/nomessages.html');
	}

	return (0);
}

sub prepare {
	my $self = shift;

	for
	(
		[ loadmessages		=> "SELECT * FROM messages WHERE (fromId=? AND toId=?) OR (fromId=? AND toId=?) ORDER BY date" ],
		[ setmessageread 	=> "UPDATE messages SET isread=1 WHERE toId=? AND fromId=?" ],
	)
	{
		$self->{sth}->{$_->[0]} = $self->{dbh}->prepare($_->[1]) or warn "Failed to prepare $_->[0]: ".$self->{dbh}->errstr;
	}

	$self->SUPER::prepare();
}

1;
