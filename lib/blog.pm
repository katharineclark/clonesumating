package blog;
use strict;
 
use Data::Dumper;
use Net::Blogger;
use Net::LiveJournal;

sub new {
    my $class = shift;
    my %args = @_;

    my @parm = @_;

    my $self = {
        db => $args{db}
    };

    bless $self, ref($class) || $class;

    $self;
}


sub blogthis {
	my $self = shift;
	my $userId = shift;
	my $type = shift;
    my $typeclause;

	warn "BLOG $type FOR $userId?";
    if ($type eq "qow") {
        $typeclause = "postQow = 'Y'";
    } elsif ($type eq "topic") {
        $typeclause = "postTopic = 'Y'";
    } elsif ($type eq "contest") {
        $typeclause = "postPhoto='Y'";
    }   
	warn "SELECT count(1) FROM blogapi WHERE $typeclause AND userId=$userId;";
	my $blog = $self->{db}->prepare("SELECT count(1) FROM blogapi WHERE $typeclause AND userId=$userId;");
	$blog->execute;
	my $c = $blog->fetchrow;
	$blog->finish;
	warn "Blogs posting with this type: $c";
	if ($c > 0) {
		return 1;
	} else {
		return 0;		
	}
}


sub post {
	my $self = shift;
	my $userId = shift;
	my $type = shift;
	my $title = shift;
	my $html = shift;

	my $typeclause;
	if ($type eq "qow") {
		$typeclause = "postQow = 'Y'";
	} elsif ($type eq "topic") {
		$typeclause = "postTopic = 'Y'";
	} elsif ($type eq "contest") {
		$typeclause = "postContest='Y'";
	}	
	
	my $getBlogs = $self->{db}->prepare("SELECT * FROM blogapi WHERE $typeclause AND userId=$userId;");
	$getBlogs->execute;
	while (my $blog = $getBlogs->fetchrow_hashref) {
		warn "BLOGGING TO $blog->{type} FOR $userId";

		my $error = 0;
		my $errormsg ="";
		if ($blog->{type} eq "livejournal") {

    		my $lj = Net::LiveJournal->new(user => $blog->{username}, password => $blog->{password});

    		# make an entry object...
    		my $entry = Net::LiveJournal::Entry->new(subject => $title,
           				                             body    => $html);
			if (my $url = $lj->post($entry)) {
			} else {
				$error = 1;
			}
		} elsif ($blog->{type} eq "blogger") {

       		my $b = Net::Blogger->new(engine=>$blog->{engine});
        	$b->Username($blog->{username});
        	$b->Password($blog->{password});
        	$b->Proxy($blog->{apiurl});
			$b->BlogId($blog->{blogid});
			my $id;
			if ($blog->{engine} eq "Movabletype") {
				$id = $b->metaWeblog()->newPost(description => $html,publish=>1,title=>$title) || { $error = 1 };
			} else {
				$id = $b->newPost(postbody=>\$html,publish=>1) || {$error = 1 };
			}
			if ($error == 1) { $errormsg = $b->LastError() }
		}
		if ($error == 1) {
			warn "ERROR POSTING TO BLOG - $$blog{type} for $$blog{username} :: $errormsg";
		}
	}
}


1;
