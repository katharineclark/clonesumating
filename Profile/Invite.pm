package Profile::Invite;

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

	my $tags = $self->{query}->param('tags');
	if ($self->{user}{user}{id} && $tags !~ /_rsvp\b/) {
		$self->{req}->headers_out->set(Location => "/profiles/$self->{user}{profile}{linkhandle}");
		return REDIRECT;
	}	

	my $verify = $self->{query}->param('v');
	if ($self->{util}->decrypt($verify,$self->{user}{profile}{handle}) ne "1") {
		print $self->{req}->headers_out->set(Location => "/register.pl");
		return REDIRECT;

	}

	my @tags;
	if ($tags ne "") {
		@tags = split(/\s+/,$tags);
		foreach my $t (0 .. $#tags) {
			$tags[$t] = qq|<a href="/tags/$tags[$t]">$tags[$t]</a>|;
		}
		if ($#tags > 0) {
			$tags[$#tags] = "and $tags[$#tags]";
		}	
		my $ttags = join(", ",@tags);
		$self->{user}{page}{rawtags} = $tags;
		$self->{user}{page}{tags} = $ttags;
	}

	#if it's a party invite and they're logged in, send them to the meeting page
	if ($self->{user}{user}{id} && $tags =~ /_rsvp/) {
		(my $tag) = grep {/_rsvp/} split /\s+/,$tags;
warn "We got a party! $tag";
		$tag =~ s/_rsvp//;
		my $mid = $self->{dbh}->selectrow_array("SELECT id FROM events WHERE tag = ?",undef,$tag);
warn "party id: $mid";
		print $self->{req}->headers_out->set(Location => "/meetings?id=$mid");
		return REDIRECT;
	}

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

	$self->{user}{page}{mode} = "invite";

	print $self->{P}->process("Profile/invite.html");

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
