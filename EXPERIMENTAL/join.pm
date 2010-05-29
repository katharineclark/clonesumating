package portalize::join;


use strict;
 
use Data::Dumper;
use Date::Calc qw(Delta_DHMS Today_and_Now);
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use CGI;
use DBI qw(:sql_types);
use POSIX qw(strftime);


use lib "../lib";
use template2;
use Profiles;
use cache;
use faDates;
use sphere;
use Users;

our (%db_sth,$guserid,$handle,$dbh);
our $cache = new Cache;

sub handler :method {
	my $class = shift;
	my $r = shift;

	$r->content_type('text/html');

	my $dbActive = ref $dbh && $dbh->ping;

	my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
    $P->{user}{global}{imgserver} = "img.consumating.com";
	unless (ref $P) {
		return 0;
	}
    $P->{user}{global}{section} = 'weekly';


	warn "REGISTER PID: $$: $P->{command}";
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

	#%db_sth = $self->prepareQueries unless ($dbActive);

	if ($self->{command} eq "") {
		$self->displayDefault();
	} elsif ($self->{command} eq "/tags") {
		$self->displayTags();
    } elsif ($self->{command} eq "/peeps") {
        $self->displayPeeps();
    } elsif ($self->{command} eq "/post") {
        $self->displayPost();
	} elsif ($self->{command} eq "/create") {
		$self->create();
	}


	return 0;
}


sub displayDefault() {
	my $self = shift;


	print processTemplate($self->{user},"portalize/join/index.html",0,"portalize/outside.html");

}

sub displayTags() {
    my $self = shift;


    print processTemplate($self->{user},"portalize/join/tags.html",0,"portalize/outside.html");

}


sub displayPeeps() {
    my $self = shift;


	my $sql = "SELECT tagId FROM tagRef WHERE profileId=?";
	my $getMyTags = $self->{dbh}->prepare($sql);
	$getMyTags->execute($self->{user}{user}{id});
	my @tags;
	while (my $tid = $getMyTags->fetchrow) {
		push(@tags,$tid);	
	}
	$getMyTags->finish;

	$sql = "SELECT profileId, count(tagRef.id) as count FROM tagRef inner join photos on (tagRef.profileId=photos.userId and photos.rank=1) WHERE source='O' and tagId in (" . join(",",@tags) . ") and profileId != ? GROUP BY profileId having count > 5 ORDER BY RAND() limit 10";
	my $getPeeps = $self->{dbh}->prepare($sql);
	$getPeeps->execute($self->{user}{user}{id});
	while (my $peep = $getPeeps->fetchrow_hashref) {

		 my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $peep->{profileId}) or next;

		push(@{$self->{user}{peeps}},{profile => $U->profile, tags => $peep});


	}

    print processTemplate($self->{user},"portalize/join/peeps.html",0,"portalize/outside.html");



}


sub displayPost() {
    my $self = shift;


    print processTemplate($self->{user},"portalize/join/post.html",0,"portalize/outside.html");

}



sub create() {

	my $self = shift;

}
