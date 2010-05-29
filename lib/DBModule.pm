package DBModule;

use strict;
use Carp qw(cluck);
use DBI;
use Data::Dumper;

our @getFields = qw();
our @setFields = qw();
our $tablename = qw();

sub getFields { @getFields }
sub setFields { @setFields }

sub new
{
	my $class = shift;
	my $db = shift;
	my $id = undef;

	my $self = { 
		db => $db, 
		origid => $id, 
		fields => {},
		changed => {},
		idfield => 'id',
		idstring => '',
	};
	bless $self, ref($class) || $class;

	for (($self->getFields)) {
		$self->{fields}{$_} = undef;
	}
	$self->{tablename} = $self->tablename();

	if ($#_ > -1) {
		my $argument = shift;
		unless (ref $argument) {
			$self->set('id',$argument);
			$self->markExists();
			$self->load();
		} elsif (ref $argument eq 'HASH') {
			for (($self->getFields)) {
				if (exists($argument->{$_})) {
					$self->set($_,$argument->{$_});
					delete $self->{changed}{$_};
					$self->markExists if ($_ eq 'id');
				}
			}
		}
	}

	$self;
}

sub markExists {
	my $self = shift;
	delete $self->{changed}{id};
	$self->{origid} = $self->{fields}{id};
}


sub load
{
	my $self = shift;

	return undef unless $self->{db};

	my $query = "SELECT ".join(',',($self->getFields))." FROM ".$self->{tablename}." WHERE id = ?";
	my $sth = $self->{db}->prepare($query);
	my $res = $sth->execute($self->{fields}{id});
	my $row = $sth->fetchrow_hashref();
	for (($self->getFields)) {
		$self->set($_,$row->{$_});
		delete $self->{changed}{$_};
	}
	$self->markExists;
	return 1;
}

sub save
{
	my $self = shift;
	my $noupdate = shift;
	my $query;


	if ($self->{changed}{id} == 1 || $self->{origid} eq '') {
		$query = "INSERT INTO ".$self->{tablename};
		my @values = map {defined($self->{fields}{$_}) ? $self->{db}->quote($self->{fields}{$_}) : 'NULL'} ($self->setFields);

		{
			local $"=',';
			$query .= "(".join(',',($self->setFields)).") VALUES (@values)";
		}
		my $sth = $self->{db}->do($query) or Carp::cluck("Failed to insert ($query; ".join(', ',@values)."): ".$self->{db}->errstr);

		if (exists $self->{fields}{id} && !defined $self->{fields}{id}) {
			#$self->set('id',$self->{db}->last_insert_id(),1);
			$self->set('id',$self->{db}->last_insert_id(undef,undef,undef,undef,{sequence=>'public.'.$self->{tablename}.'_id_seq'}),1);
		}
	} else {
		if (scalar keys %{$self->{changed}} > 0) {
			$query = "UPDATE $self->{tablename} SET ";
			my @sets = map {"$_ = ".(defined($self->{fields}{$_}) ? $self->{db}->quote($self->{fields}{$_}) : 'NULL')} keys %{$self->{changed}};
			$query .= join(',',@sets)." WHERE id = ?";
			$self->{db}->do($query,undef,$self->{fields}{id});
		}
	}

	return $self->{db}->errstr ? $self->{db}->errstr : $self->{fields}{id};
}
sub delete
{
	my $self = shift;
	my $query = "DELETE FROM $self->{tablename} WHERE id = ?";
	my $sth = $self->{db}->prepare($query);
	$sth->execute($self->get('id'));
}

sub copy
{
	my $self = shift;
	my $new = ref($self)->new($self->getAll());
	$new->markExists;
	$new;
}

sub setAll
{
	my $self = shift;
	my %args = @_;

	for (($self->setFields)) {
		my $call = "set$_";
		if (defined $args{$_}) {
			$self->set($_,$args{$_});
		}
	}
}

sub getAll
{
	my $self = shift;
	my %fields;
	for (($self->getFields)) {
		$fields{$_} = $self->get($_);
	}
	\%fields;
}

sub set
{
	my $self = shift;
	my $name = shift;
	my $value = shift;

	$self->{changed}{$name} = 1;
    $self->{fields}{$name} = $name =~ /dt/ && $value eq '' ? 'NOW()' : $value;
}
sub get
{
	my $self = shift;
	my $name = shift;
	return $self->{fields}{$name};
}

sub find
{
	my $self = shift;
	my %args = @_;
	my @order;
	my $where;	

	for (($self->getFields())) {
		my $arg = '-'.$_;
		if (defined $args{$arg}) {
			$args{$arg} = $self->{db}->quote($args{$arg})  unless $args{$arg} eq 'NULL';
			push @order, "$_ = $args{$arg}";
		}
	}
	if (scalar @order) {
		my $where = join ' AND ', @order;
		if (exists $args{'--Limit'}) {
			$where .= " LIMIT $args{'--Limit'}";
		}
		return $self->findWhere($where);
	} else {
		return undef;
	}
}

sub findWhere
{
    my $self = shift;
    my $where = shift;
	my $order = shift;
	my $orderdir = shift;
    my @results = ();

	my $query = "SELECT ".(join',',($self->getFields))." FROM $self->{tablename} ";
	$query .= " WHERE $where " if defined $where;
	if (defined $order) {
		$query .= " ORDER BY $order ";
		$query .= $orderdir == 0 ? ' ASC ' : ' DESC ';
	}


	my $sth = $self->{db}->prepare($query);
	my $res = $sth->execute or (Carp::cluck("Can't execute $query"),return(undef));
	while (my $h = $sth->fetchrow_hashref) {
		push @results, ref($self)->new($self->{db},$h);
	}
	$sth->finish;
	return \@results;
}

1;
