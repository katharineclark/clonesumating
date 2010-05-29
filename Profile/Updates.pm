package Profile::Updates;

use strict;
 
use Apache2::Const qw(REDIRECT);
use Page;
use Profile;

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;

	my $handle = $self->{util}->delinkify($self->{user}{query}{handle});
	my $uid = $self->{util}->getUserId($handle);
	if ($uid != $self->{user}{user}{id}) {
		$self->{req}->headers_out->set(Location => "/profiles/$self->{user}{user}{linkhandle}/updates");
		return REDIRECT;
	}

	$self->prepare;
	$self->displayDefault;

	my $offset = $self->{query}->param('offset') || 0;    

	foreach my $daysago ($offset .. ($offset + 6)) {
		my %thisday;

		$self->{sth}{getProfileThumbs}->execute($self->{user}{user}{id},'U',$daysago);
		$thisday{thumbs}{pups} = $self->{sth}{getProfileThumbs}->fetchrow;
		$self->{sth}{getProfileThumbs}->execute($self->{user}{user}{id},'D',$daysago);
		$thisday{thumbs}{pdowns} = $self->{sth}{getProfileThumbs}->fetchrow;

		$self->{sth}{getQuestionThumbs}->execute($self->{user}{user}{id},'U',$daysago);
		$thisday{thumbs}{qups} = $self->{sth}{getQuestionThumbs}->fetchrow;
		$self->{sth}{getQuestionThumbs}->execute($self->{user}{user}{id},'D',$daysago);
		$thisday{thumbs}{qdowns} = $self->{sth}{getQuestionThumbs}->fetchrow;

        $self->{sth}{getPhotoThumbs}->execute($self->{user}{user}{id},'U',$daysago);
        $thisday{thumbs}{cups} = $self->{sth}{getPhotoThumbs}->fetchrow;
        $self->{sth}{getPhotoThumbs}->execute($self->{user}{user}{id},'D',$daysago);
        $thisday{thumbs}{cdowns} = $self->{sth}{getPhotoThumbs}->fetchrow;

        $thisday{thumbs}{ups} = $thisday{thumbs}{pups} + $thisday{thumbs}{qups} + $thisday{thumbs}{cups};
        $thisday{thumbs}{downs} = $thisday{thumbs}{pdowns} + $thisday{thumbs}{qdowns} + $thisday{thumbs}{cdowns};

		$self->{sth}{getTags}->execute($self->{user}{user}{id},$daysago);

        while (my $tag = $self->{sth}{getTags}->fetchrow_hashref) {
             my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $tag->{addedById}) or next;
            push(@{$thisday{tags}},{tag => $tag,profile=> $U->profile()});
        }
        $thisday{day}{daysago} = $daysago;
        $thisday{day}{date} = time() - ($daysago * 24 * 60 * 60);
        push(@{$self->{user}{days}},\%thisday);
        $self->{user}{page}{offset} = $daysago;
	}

	print $self->{P}->process('Profile/updates.html');

	return (0);
}

sub prepare {
	my $self = shift;

	for 
	(
		[ getProfileThumbs 	=> "SELECT COUNT(1) FROM thumb WHERE profileId=? AND type=? AND DATE(insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))" ],
		[ getQuestionThumbs => "SELECT COUNT(1) FROM bling inner join questionresponse on bling.questionresponseId=questionresponse.id WHERE questionresponse.userId=? AND type=? AND DATE(insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))" ],
    	[ getPhotoThumbs 	=> "SELECT COUNT(1) FROM photo_contest_bling inner join photo_contest_entry on photo_contest_bling.entryId=photo_contest_entry.id WHERE photo_contest_entry.userId=? AND type=? AND DATE(photo_contest_bling.insertDate) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))" ],
    	[ getTags 			=> "SELECT value,left(value,35) as shortvalue,addedById,anonymous FROM tag inner join tagRef on tag.id=tagRef.tagId WHERE tagRef.profileId=? AND DATE(dateAdded) = DATE(DATE_SUB(NOW(),INTERVAL ? DAY))" ],
	)
	{
		$self->{sth}->{$_->[0]} = $self->{dbh}->prepare($_->[1]);
	}

	$self->SUPER::prepare();
}
		

1;
