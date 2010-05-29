package photos;
 
use strict;
use Exporter;
use Image::Magick;

our @ISA    = qw(Exporter);
our @EXPORT = qw(savePhoto);


my $photoDir = "$staticPath/photos";
my $tmp = $tempPath;


sub savePhoto {

	my ($cgi,$userId,$dbh) = @_;

	my $imageId;

    if (!-e "$photoDir/$userId") {
        mkdir("$photoDir/$userId",0777);
        mkdir("$photoDir/$userId/small",0777);
        mkdir("$photoDir/$userId/med",0777);
        mkdir("$photoDir/$userId/large",0777);
        mkdir("$photoDir/$userId/50",0777);
        mkdir("$photoDir/$userId/100",0777);
	}

	my $fname = $cgi->param('photo');
    $fname = lc($fname);
	my $imageFile = qq|$tmp/$userId.$fname|;
    open(OUT,"> $imageFile");
    my $F = $cgi->upload('photo');
    while (<$F>) {
		print OUT $_;
	}
	close(OUT);

    my $image = Image::Magick->new();

    my $rv = $image->Read($imageFile);
    $image->Set(magick=>'jpg');

    my ($width,$height);
    ($width,$height) = $image->Get('width', 'height');
    if ($width != 0 && $height != 0) {

    my $sql = "SELECT count(1) FROM photos WHERE userId=$userId";
        my $sth=$dbh->prepare($sql);
        $sth->execute;
        my $count = $sth->fetchrow;
        $sth->finish;

    # if there are no other photos, set this as the #1 photo.
        my $rank = 1;
        if ($count > 0) {
            $rank = 99;
        }
        my $sql = "INSERT INTO photos (userId,rank,height,width,timestamp) values ($userId,$rank,$height,$width,NOW());";

        my $sth = $dbh->prepare($sql);
        $sth->execute;
        $imageId = $sth->{mysql_insertid};
        $sth->finish;

		my $setAspect = $dbh->prepare("UPDATE photos SET height=?,width=? WHERE id=?");

        # make a version that is 100 high
		{
			my ($xoff,$yoff);
        	my $multiplier = 100 / $height;
        	my $nwidth = $width * $multiplier;
            my $nheight = 100;
            if ($nwidth < 100) {
            	my $foo = 100 / $nwidth;
                $nwidth = 100;
                $nheight = 100 * $foo;
            }

            $xoff = int(($nwidth / 2) - 50);
            $nwidth = int($nwidth);
            $nheight = int($nheight);

            $image->Scale(width=>$nwidth,height=>$nheight);

            # writes cropped 100x100
            $image->Crop(width=>100,height=>100,x=>$xoff,y=>0);
            $image->Write("$photoDir/$userId/100/$imageId.jpg");
            $image->Scale(width=>"50",height=>"50");
            $image->Write("$photoDir/$userId/50/$imageId.jpg");

			# reload original image
   			$image = Image::Magick->new();
            $rv = $image->Read($imageFile);
            $image->Set(magick=>'jpg');
            ($width,$height) = $image->Get('width', 'height');
            if ($width > 400) {
            	$multiplier = 400 / $width;
                $nheight = $height * $multiplier;
                $image->Scale(width=>"400",height=>"$nheight");
                $xoff = 150;
                $yoff = ($nheight / 2) - 50;
				$setAspect->execute($nheight,400,$imageId);
            } else {
                $xoff = int(($width / 2) - 50);
                $yoff = int(($height / 2) - 50);
            }

            # writes photo that is at most 400 pix wide
            $image->Write("$photoDir/$userId/large/$imageId.jpg");

            my $image = Image::Magick->new();
            my $rv = $image->Read($imageFile);
            $image->Set(magick=>'jpg');
            ($width,$height) = $image->Get('width', 'height');

            $multiplier = 100 / $width;
            $nheight = $height * $multiplier;
            $image->Scale(width=>"100",height=>"$nheight");
            # writes photo that is at most 100 px wide
            $image->Write("$photoDir/$userId/med/$imageId.jpg");

            $multiplier = 50 / $width;
            $yoff = ((($nheight) / 2) - 25);
            $nheight = $height * $multiplier;
            if ($nheight > 50) {
            	$image->Scale(width=>"50",height=>"$nheight");
                $width = 50;
                $height = 50;
            }
            $xoff = 25;
     		# writes photo that is at most 50 pix wide
            $image->Write("$photoDir/$userId/small/$imageId.jpg");

			return $imageId;
		}
	} else {
		return 0;
	}
}

1;
