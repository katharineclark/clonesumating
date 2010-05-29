package Profile::Thumbup;

use strict;
use Page;
use Profile;
use Apache2::Const qw(REDIRECT);
use bbDates;

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;

	$self->prepare;
	$self->displayDefault;

	if ($self->{user}{user}{id}) {
		my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{user}{profile}{id});
		$self->{sth}{checkthumb}->execute($self->{user}{profile}{id},$self->{user}{user}{id});
		my $oldtype = $self->{sth}{checkthumb}->fetchrow;
		if ($oldtype eq 'D') {
			$User->updateField('popularity',$User->{profile}{popularity} + 3);
		} elsif (!$oldtype) {
			$User->updateField('popularity',$User->{profile}{popularity} + 2);
		}

		$self->{sth}{deletethumb}->execute($self->{user}{profile}{id},$self->{user}{user}{id});
		$self->{sth}{insertthumb}->execute($self->{user}{profile}{id},$self->{user}{user}{id},'U');

		$self->{req}->headers_out->set(Location => "/profiles/$self->{user}{profile}{linkhandle}");
		return REDIRECT;
	} else {
        $self->{user}{global}{requiredFields} = qq|"handle","tagline","do","firstName","lastName","month","day","year","sex","username","password"|;
        $self->{user}{global}{requiredFieldsDescriptions} = qq|"YOUR CONSUMATING NAME","YOUR TAGLINE","YOUR TAGS","YOUR FIRST NAME","YOUR LAST NAME","YOUR BIRTH MONTH","YOUR BIRTH DAY","YOUR BIRTH YEAR","YOUR GENDER","YOUR EMAIL ADDRESS","YOUR PASSWORD"|;

        $self->{user}{global}{requiredValidEmail} = 1;
        $self->{user}{global}{requireLocation} = 1;
        $self->{user}{global}{suggestPhoto} = 1;

	 	my %args;

        $self->{user}{login}{monthSelect} =  monthSelect($args{month});
        $self->{user}{login}{daySelect} = daySelect($args{day});
        $self->{user}{login}{yearSelect} = yearSelect($args{year}||1988,1900,1988);
        $self->{user}{login}{countrySelect} = $self->{util}->countrySelect($args{country}||"US");

		$self->{user}{page}{mode} = "thumb";
		$self->{user}{page}{thumb} = "up";

		print $self->{P}->process("Profile/invite.html");
	}

	return (0);
}

sub prepare {
	my $self = shift;

	for
	(
		[ checkthumb	=> "SELECT type FROM thumb WHERE profileId=? AND userId=?" ],
    	[ deletethumb	=> "DELETE FROM thumb WHERE profileId=? AND userId=?" ],
    	[ insertthumb	=> "INSERT INTO thumb (profileId,userId,type,insertDate) VALUES (?,?,?,NOW())" ],
	)
	{
		$self->{sth}->{$_->[0]} = $self->{dbh}->prepare($_->[1]) or warn "Failed to prepare $_->[0]: ".$self->{dbh}->errstr;
	}

	$self->SUPER::prepare();
}

1;
