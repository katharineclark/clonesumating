package toys::store;

use strict;
 
use Data::Dumper;
use Date::Calc qw(Delta_DHMS Today_and_Now);
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use CGI;


use lib "lib";
use template2;
use Profiles;
use cache;
use items;

our (%db_sth,$guserid,$handle,$dbh);
our $cache = new Cache;

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $dbActive = ref $dbh && $dbh->ping;

	my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
	unless (ref $P) {
		return OK;
	}
	$P->{user}{system}{tab} = "Browse";


	warn "TOYS::STORE PID: $$, $P->{command}";
	my $self = {
		req 	=> $r,
		user 	=> $P->{user},
		cache 	=> $P->{cache},
		dbh		=> $P->{dbh},
		util	=> util->new(dbh => $P->{dbh}, cache => $P->{cache}),
		query	=> CGI->new($r),
	};
	bless $self, $class;

	$self->{command} = $P->{command};

	%db_sth = $self->prepareQueries unless ($dbActive);

	return $self->showStore();
}

sub showStore {
	my $self = shift;

	my %used = ();

	# get featured toys
	$db_sth{featured}->execute;
	while (my $i = $db_sth{featured}->fetchrow_hashref) {
		push @{$self->{user}{featuredItems}}, {item => $i};
		$used{$i->{id}} = 1;
	}
	if (defined $self->{user}{featuredItems} && scalar(@{$self->{user}{featuredItems}}) % 12 != 0) {
		for (1 .. 12-(scalar(@{$self->{user}{featuredItems}}) % 12)) {
			push @{$self->{user}{featuredBlanks}}, {};
		}
	} elsif (!defined $self->{user}{featuredItems}) {
		for (1 .. 12) {
			push @{$self->{user}{featuredBlanks}}, {};
		}
	}

	# get popular toys
	$db_sth{popular}->execute;
	my ($id,$count) = (undef,undef);
	$db_sth{popular}->bind_columns(\$id,\$count);
	while ($db_sth{popular}->fetchrow_arrayref) {
		$id =~ s/\D+//g;
		next if $used{$id};
		$db_sth{item}->execute($id);
		next unless $db_sth{item}->rows;
		$used{$id}=1;
		push @{$self->{user}{popularItems}}, {item => $db_sth{item}->fetchrow_hashref};
		last if scalar @{$self->{user}{popularItems}} == 12;
	}
	if (defined $self->{user}{popularItems} && scalar(@{$self->{user}{popularItems}}) % 12 != 0) {
		for (1 .. 12-(scalar(@{$self->{user}{popularItems}}) % 12)) {
			push @{$self->{user}{popularBlanks}}, {};
		}
	} elsif (!defined $self->{user}{popularItems}) {
		for (1 .. 12) {
			push @{$self->{user}{popularBlanks}}, {};
		}
	}

	# get recent items
	$db_sth{recent}->execute;
	while (my $i = $db_sth{recent}->fetchrow_hashref) {
		warn "USED $i->{id}? $used{$i->{id}}";
		next if $used{$i->{id}};
		$used{$i->{id}} = 1;
		push @{$self->{user}{recentItems}}, {item => $i};
		last if scalar @{$self->{user}{recentItems}} == 12;
	}
	if (defined $self->{user}{recentItems} && scalar(@{$self->{user}{recentItems}}) % 12 != 0) {
		for (1 .. 12-(scalar(@{$self->{user}{recentItems}}) % 12)) {
			push @{$self->{user}{recentBlanks}}, {};
		}
	} elsif (!defined $self->{user}{recentItems}) {
		for (1 .. 12) {
			push @{$self->{user}{recentBlanks}}, {};
		}
	}

	print processTemplate($self->{user},"items/store.html");
	return OK;
}


sub prepareQueries {
	my $self = shift;

	return (
		featured	=> $self->{dbh}->prepare("SELECT ui.* FROM user_items ui LEFT JOIN user_item_info uii ON uii.itemId = ui.id WHERE  featured = 1 ORDER BY createDate DESC LIMIT 12"),
		popular		=> $self->{dbh}->prepare("SELECT description,COUNT(*) FROM point_transaction WHERE type='item' AND description LIKE 'Purchase%' GROUP BY 1 ORDER BY 2 DESC LIMIT 24"),
		recent		=> $self->{dbh}->prepare("SELECT ui.* FROM user_items ui LEFT JOIN user_item_info uii ON uii.itemId = ui.id ORDER BY createDate DESC LIMIT 36"),
		item		=> $self->{dbh}->prepare("SELECT * FROM user_items WHERE id = ?"),
	);
}
