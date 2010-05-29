package api::popularity;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use Users;

our @ISA = qw(api);

sub get24HourTop10 {
	my $self = shift;
	my $sql = "SELECT users.id as userId,tagline,handle,city,state,country, photos.id as photoId FROM (users inner join photos on users.id=photos.userId and photos.rank=1), profiles where users.id=profiles.userid order by todaypopularity desc, popularity desc limit 10;";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $count = 0;
	my $data;
	while (my $profile = $sth->fetchrow_hashref) {
		$profile->{linkhandle} = linkify($profile->{handle});
		$data .= $self->hashToXML("profile",$profile);
	}
	$sth->finish;

	$data .= "<title>Popular Over the Last 24-Hours</title>";

	return $self->generateResponse("ok","populateList",$data);
}

sub getTop10 {
	my $self = shift;
	my $sql = "SELECT users.id as userId,tagline,handle,city,state,country, photos.id as photoId FROM (users inner join photos on users.id=photos.userId and photos.rank=1), profiles where users.id=profiles.userid order by popularity desc,todayPopularity desc limit 10;";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $data = $self->buildProfile($sth);
	$sth->finish;

	$data .= "<title>Top 10 Overall</title>";

	return $self->generateResponse("ok","populateList",$data);
}

sub getTop10Boys {
	my $self = shift;
	my $sql = "SELECT users.id as userId,tagline,handle,city,state,country, photos.id as photoId FROM (users inner join photos on users.id=photos.userId and photos.rank=1), profiles where users.id=profiles.userid and users.sex='M' order by popularity desc,todayPopularity desc limit 10;";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $data = $self->buildProfile($sth);
	$sth->finish;

	$data .= "<title>Top 10 Boys</title>";

	return $self->generateResponse("ok","populateList",$data);
}

sub getTop10Girls {
	my $self = shift;
	my $sql = "SELECT users.id as userId,tagline,handle,city,state,country, photos.id as photoId FROM (users inner join photos on users.id=photos.userId and photos.rank=1), profiles where users.id=profiles.userid and users.sex='F' order by popularity desc,todayPopularity desc limit 10;";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $data = $self->buildProfile($sth);
	$sth->finish;

	$data .= "<title>Top 10 Girls</title>";

	return $self->generateResponse("ok","populateList",$data);
}

1;
