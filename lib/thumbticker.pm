package thumbticker;

use strict;
 
use util;
use Cache;

sub new {
	my $class = shift;
	my ($dbh,$memcache,$count,$widget) = @_;

	my $self = {
		dbh 	=> $dbh,
		cache	=> new Cache,
		count 	=> $count || 35,
		widget	=> $widget || 0,
	};


	bless $self, ref($class) || $class;

	$self->init;

	$self;
}
sub init {
	my $self = shift;

	$self->buildSql();

	$self->{userlookup} = $self->{dbh}->prepare("SELECT handle FROM profiles WHERE userid = ?");
	$self->{thumblookup} = $self->{dbh}->prepare("SELECT COUNT(*) FROM thumb WHERE profileId = ? AND type = ?");
	$self->{blinglookup} = $self->{dbh}->prepare("SELECT COUNT(*) FROM bling b,questionresponse r WHERE r.userId = ? AND b.questionresponseId = r.id AND b.type = ?");
	$self->{responder} = $self->{dbh}->prepare("SELECT userId FROM questionresponse WHERE id = ?");
}

sub count {
	my $self = shift;
	$self->{count} = $_[0] if (scalar @_);
	$self->{count};
}

sub buildSql {
	my $self = shift;

	#my $sql = "SELECT DISTINCT(profileId) AS profileId,type, insertDate FROM thumb ORDER BY insertDate DESC LIMIT $self->{count}";
	my $sql = "(SELECT DISTINCT(profileId) AS profileId, type,insertDate FROM thumb) UNION "
			#"(SELECT DISTINCT(r.userId) AS profileId, b.type, insertDate FROM bling b, questionresponse r WHERE r.id = b.questionresponseId) "
			. "(SELECT CONCAT('Q',questionresponseId),type,insertDate FROM bling ) "
			. "ORDER BY insertDate DESC LIMIT 200";

	$self->{sth} = $self->{dbh}->prepare($sql);
}

sub build {
	my $self = shift;
	
	$self->{sth}->execute;

	my $count = 0;
	my %data;
	my %seen;
	while (my $ticker = $self->{sth}->fetchrow_hashref) {
		next unless $ticker->{profileId};
		$ticker->{profileId} =~ /Q(\d+)/;
		if ($1) {
			next if $seen{$1};
			$self->{responder}->execute($1);
			$ticker->{profileId} = $self->{responder}->fetchrow;
			next unless $ticker->{profileId};
		}
		next if $seen{$ticker->{profileId}};
		$seen{$ticker->{profileId}}++;

		$ticker->{handle} = getHandle($ticker->{profileId});
		next unless $ticker->{handle};
		$ticker->{linkhandle} = linkify($ticker->{handle});

		$self->{thumblookup}->execute($ticker->{profileId},'U');
		$ticker->{ups} = $self->{thumblookup}->fetchrow || 0;
		$self->{thumblookup}->execute($ticker->{profileId},'D');
		$ticker->{dns} = $self->{thumblookup}->fetchrow || 0;

		$self->{blinglookup}->execute($ticker->{profileId},'U');
		$ticker->{ups} += ($self->{blinglookup}->fetchrow);
		$self->{blinglookup}->execute($ticker->{profileId},'D');
		$ticker->{dns} += ($self->{blinglookup}->fetchrow);

		$ticker->{widget} = $self->{widget}||0;

		$data{$count++}{ticker} = $ticker;
		last if $count == $self->{count};
	}

	return \%data;
}

sub DESTROY {
	my $self = shift;

	$self->{sth}->finish;
	$self->{userlookup}->finish;
	$self->{thumblookup}->finish;
}

1;
