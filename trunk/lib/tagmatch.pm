package tagmatch;

use strict;
 
use Socket;

sub new  {
	my $class = shift;
	my $self = { 
		host => 'localhost',
		port => 19000,
		proto => getprotobyname('tcp'),
	};
	bless $self, ref $class || $class;

	$self;
}

sub searchUser {
	my ($self,$handle) = @_;

	my $sock = $self->open;

	print $sock "User\t$handle\n";
	my @results;
	while (<$sock>) {
		chomp;
		my @r = split /\t/,$_;
		next if $r[0] eq $handle;
		push @results,[@r];
	}
	return \@results;

	$self->close($sock);
}
sub quit {
	my $self = shift;

	my $sock = $self->open;
	print $sock "quitserver\n";
	$self->close($sock);
}

sub open {
	my $self = shift;

	socket(my $sock,PF_INET,SOCK_STREAM,$self->{proto});
	my $sin = sockaddr_in($self->{port}, inet_aton($self->{host}));
	connect($sock,$sin) || exit -1;

	my $old_fh = select($sock); $|=1; select($old_fh);

	return $sock;
}
sub close {
	my ($self,$sock) = @_;
	close $sock;
}

1;
