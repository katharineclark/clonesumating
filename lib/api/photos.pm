package api::photos;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use QuestionResponse;
use CONFIG;

our @ISA = qw(api);

sub delete {
	my $self = shift;
	my $photoDir = "$staticPath/photos";
	my $photoId = $self->{query}->param('photoId');


	$self->{dbh}->do("DELETE FROM photos WHERE id = ? AND userId = ?",undef,$photoId,$self->{user}{user}{id});
	warn $self->{dbh}->errstr if $self->{dbh}->errstr;
	unlink("$photoDir/$self->{user}{user}{id}/large/$photoId.jpg");
	unlink("$photoDir/$self->{user}{user}{id}/med/$photoId.jpg");
	unlink("$photoDir/$self->{user}{user}{id}/small/$photoId.jpg");

	# if there are any question responses that use this photo, clear them
	#$self->{dbh}->do("UPDATE questionresponse SET photoId = 0 WHERE userId = ? AND photoId = ?",undef,$self->{user}{user}{id},$photoId);
	my $QR = QuestionResponse->new(dbh => $self->{dbh}, cache => $self->{cache});
	my $responses = $QR->getByUser($self->{user}{user}{id});
	for my $e (keys %$responses) {
		if ($responses->{$e}->{photoId} == $photoId) {
			my $QR = QuestionResponse->new(dbh => $self->{dbh}, cache => $self->{cache}, responseId => $responses->{$e}->{id});
			$QR->updatePhoto(0);
			last;
		}
	}
			
	warn $self->{dbh}->errstr if $self->{dbh}->errstr;
	
	return $@ ? $self->generateResponse("fail","","<delete>$photoId</delete>") : $self->generateResponse("ok","deletePhotoReturn","<delete>OK</delete>");
}

1;
