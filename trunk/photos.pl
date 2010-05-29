#!/usr/bin/perl

use lib "lib";
use strict;
use template2;
use Profiles;
use photos;
use Image::Magick;
use CM_Tags;
use List::Util qw(first);
use points;

use CONFIG;


my $photoDir = "$staticPath/photos";
my $tmp = "$tempPath";


# main 

{ 

	my $P = Profiles->new();

#	if (!verify(\%user)) {
#   	 exit;
#	}

	if ($P->{command} eq "") {
		default($P);
	} elsif ($P->{command} eq "/minipicker") {
		minipicker($P);
	} elsif ($P->{command} eq "/picked") {
		picked($P);
	} elsif ($P->{command} eq "/upload") {
		upload($P);
	}


}




sub default {
	my ($P) = @_;

	my ($sql,$sth,$count);

	$sql = "SELECT * FROM photos WHERE userId=$P->{user}{user}{id} order by timestamp desc;";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	
	while (my $photo = $sth->fetchrow_hashref) {

		$photo->{place} = $count + 1;
		if ($photo->{rank} <= 5) {

			%{ $P->{user}{'photo'. $photo->{rank} } }= %{$photo};
			$photo->{selected} = 'selected';
		}
        push(@{ $P->{user}{photos}},{photo => $photo});
	}


	$P->{user}{photo}{incontest} = $P->{dbh}->selectrow_array("SELECT COUNT(*) FROM photo_contest c, photo_contest_entry e WHERE e.contestId=c.id AND c.itson=1 AND e.userId=?",undef,$P->{user}{user}{id}) || 0;


	print $P->Header();
	print processTemplate($P->{user},"settings/photos.html");

} 


sub minipicker {
	my ($P) = @_;

	my $show = $P->{query}->param('show') || 5;
	my $offset = $P->{query}->param('offset') || 0;
	if ($offset < 0) { $offset = 0; }
	my ($sql,$sth,$count);
	$sql = "SELECT count(1) FROM photos WHERE userId=$P->{user}{user}{id}";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	my $count = $sth->fetchrow;
	$sth->finish;
    $sql = "SELECT * FROM photos WHERE userId=$P->{user}{user}{id} order by timestamp desc limit $offset,$show;";
    $sth = $P->{dbh}->prepare($sql);
    $sth->execute;
	my $shown = 0;

    while (my $photo = $sth->fetchrow_hashref) {
		push(@{$P->{user}{photos}},{photo => $photo});
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

    print $P->Header();
	if ($mode eq "" || $mode eq "qow") {
    	print processTemplate($P->{user},"play/photopicker/questions.html",1);
	} elsif ($mode eq "photocontest") {
		print processTemplate($P->{user},"play/photopicker/photos.html",1);
	}

} 

sub picked {
	my ($P) = @_;


	$P->{user}{photo}{id} = $P->{query}->param('id');
	$P->{user}{page}{contest} = $P->{query}->param('contest');
	$P->{user}{page}{remind} = $P->{query}->param('remind');
	$P->{user}{entry}{ups} = $P->{query}->param('ups');
	$P->{user}{entry}{downs} = $P->{query}->param('downs');
    my $mode = $P->{query}->param('mode');
	print $P->Header();
    if ($mode eq "" || $mode eq "qow") {
		print processTemplate($P->{user},"play/photopicker/questions.picked.html",1);
	} elsif ($mode eq "photocontest") {
		print processTemplate($P->{user},"play/photopicker/photos.picked.html",1);
	}

}


sub upload {
	
	my ($P) = @_;

	my $userId = $P->{user}{user}{id};

	my $imageId = savePhoto($P->{query},$P->{user}{user}{id},$P->{dbh});
	if ($imageId != 0) {

		if (0) {
		my $Points = points->new(dbh => $P->{dbh}, cache => $P->{cache});
		if ($P->{user}{user}{firstUpload} ne "Y") {
			my $sql = "UPDATE users SET firstUpload='Y',points=points+1 WHERE id=$P->{user}{user}{id}";
			$P->{dbh}->do($sql);
			my $msg = "Your account has been credited <b>1 point</b> for uploading your first photo!";
			$Points->storeTransaction({
				userid	=> $P->{user}{user}{id},
				points	=> $Points->{system}{firstupload},
				type	=> 'system',
				desc	=> "$Points->{system}{firstupload}{desc}"
				}
			);
		} else {
			my $bin = $Points->getTransactions(userid => $P->{user}{user}{id}, type => 'system');
			unless (first {$_ eq $Points->{system}{first5upload}{desc}} @$bin) {
				$Points->storeTransaction({
					userid	=> $P->{user}{user}{id},
					points	=> $Points->{system}{first5upload},
					type	=> 'system',
					desc	=> "$Points->{system}{first5upload}{desc}"
					}
				);
			}
		}
		}

		my $mode = $P->{query}->param('mode') || "normal";

		if ($mode eq "normal") {
			print $P->{query}->redirect("/photos.pl?saved=1");
		} elsif ($mode eq "minipicker") {
			print $P->{query}->redirect("/photos.pl/picked?id=$imageId");
		}

	} else {
		print $P->Header();
		print "There was a problem uploading your photo.";
	}


}

