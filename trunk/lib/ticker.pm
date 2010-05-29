package ticker;

use strict;
 
use profiles;

sub new {
	my $class = shift;
	my ($dbh,$count,$sfw) = @_;

	my $self = {
		dbh 	=> $dbh,
		count 	=> $count,
		sfw		=> defined $sfw ? $sfw : 1,
	};


	bless $self, ref($class) || $class;

	$self->init;

	$self;
}
sub init {
	my $self = shift;

	$self->buildSql();

	$self->{userlookup} = $self->{dbh}->prepare("SELECT handle FROM profiles WHERE userid = ?");
	$self->{taglookup} = $self->{dbh}->prepare("SELECT value FROM tag WHERE id = ?");
}

sub count {
	my $self = shift;
	$self->{count} = $_[0] if (scalar @_);
	$self->{count};
}
sub sfw {
	my $self = shift;
	$self->{sfw} = $_[0] if (scalar @_);
	$self->{sfw};
}

sub buildSql {
	my $self = shift;

	my $sql = "SELECT DISTINCT(tagId),profileId,addedById,dateAdded FROM tagRef WHERE source='U' AND anonymous = -1 "
			. ($self->{sfw}
				? "AND value NOT LIKE '%shit%' AND value NOT LIKE '%piss%' AND value NOT LIKE '%fuck%' "
				. "AND value NOT LIKE '%cunt%' AND value NOT LIKE '%cock%' AND value NOT LIKE '%tits%' "
				: ''
			  )
			. "ORDER BY dateAdded DESC LIMIT $self->{count}";

	$self->{sth} = $self->{dbh}->prepare($sql);
}

sub build {
	my $self = shift;
	my $sfw  = shift;

	if ($sfw != $self->{sfw}) {
		$self->sfw($sfw);
		$self->buildSql;
	}
	
	$self->{sth}->execute;

	delete $self->{tagIds};

	my $count = 0;
	my %data;
	while (my $ticker = $self->{sth}->fetchrow_hashref) {
		$self->{userlookup}->execute($ticker->{profileId});
		$ticker->{addedTo} = $self->{userlookup}->fetchrow;

		$self->{userlookup}->execute($ticker->{addedById});
		$ticker->{addedBy} = $self->{userlookup}->fetchrow;

		$self->{taglookup}->execute($ticker->{tagId});
		$ticker->{value} = $self->{taglookup}->fetchrow;

		$ticker->{linkaddedTo} = linkify($ticker->{addedTo});
		$ticker->{linkaddedBy} = linkify($ticker->{addedBy});
		push @{$self->{tagIds}}, $ticker->{tagId};

		$data{$count++}{ticker} = $ticker;
	}

	return \%data;
}

sub DESTROY {
	my $self = shift;

	$self->{sth}->finish;
	$self->{userlookup}->finish;
	$self->{taglookup}->finish;
}

1;
