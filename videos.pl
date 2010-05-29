#!/usr/bin/perl

use lib "lib";
use strict;
use template2;
use Profiles;
use Image::Magick;
use CM_Tags;
use List::Util qw(first);
use points;
use video::videoEgg;

{ 

	my $P = Profiles->new();

	$P->{page}{videoEgg} = 1;

	if ($P->{command} eq "/minipicker") {
		minipicker($P);
	} elsif ($P->{command} eq "/picked") {
		picked($P);
	}


}



sub minipicker {
	my ($P) = @_;

	my $show = $P->{query}->param('show') || 5;
	my $offset = $P->{query}->param('offset') || 0;
	if ($offset < 0) { $offset = 0; }
	my ($sql,$sth,$count);
	$sql = "SELECT count(1) FROM videos WHERE userId=$P->{user}{user}{id}";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	my $count = $sth->fetchrow;
	$sth->finish;
    $sql = "SELECT * FROM videos WHERE userId=$P->{user}{user}{id} ORDER BY id DESC LIMIT $offset,$show;";
    $sth = $P->{dbh}->prepare($sql);
    $sth->execute;
	my $shown = 0;

    while (my $video = $sth->fetchrow_hashref) {
		push(@{$P->{user}{videos}},{video => $video});
		$shown++;
    }

	if ($count > ($offset+$shown)) {
		$P->{user}{page}{more} =  $offset + $shown;
	} 
	if ($offset > 0) {
		my $less =$offset - $show;
		$less = 0 if ($less < 0); 
		$P->{user}{page}{less} = $less;
	}

	my $mode = $P->{query}->param('mode');


	my $ve = video::videoEgg->new(dbh => $P->{dbh}, user => $P->{user}, cache => $P->{cache});
	$P->{user}{page}{videoPublisher} = $ve->publisher;


    print $P->Header();
	if ($mode eq "" || $mode eq "qow") {
    	print processTemplate($P->{user},"videos.minipicker.html",1);
	} elsif ($mode eq "videocontest") {
		print processTemplate($P->{user},"videos.minipicker-videocontest.html",1);
	}

}

sub picked {
	my ($P) = @_;


	$P->{user}{video} = $P->{dbh}->selectrow_hashref("SELECT * FROM videos WHERE id = ?",undef,$P->{query}->param('id'));

	$P->{user}{page}{contest} = $P->{query}->param('contest');
	$P->{user}{page}{remind} = $P->{query}->param('remind');
	$P->{user}{entry}{ups} = $P->{query}->param('ups');
	$P->{user}{entry}{downs} = $P->{query}->param('downs');
    my $mode = $P->{query}->param('mode');
	print $P->Header();
    if ($mode eq "" || $mode eq "qow") {
		print processTemplate($P->{user},"videos.picked.html",1);
	} elsif ($mode eq "videocontest") {
		print processTemplate($P->{user},"videos.picked-videocontest.html",1);
	}
}
