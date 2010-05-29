package convmatch;

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

sub search {
	my ($self,$query) = @_;

warn "SEARCHING $query";
	my $sock = $self->open;
	print $sock "CSM_search\t$query\n";
	my @results;
	while (<$sock>) {
		chomp;
		my @r = split /\t/,$_;
		push @results, [@r];
	}
	$self->close($sock);
	return \@results;
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
