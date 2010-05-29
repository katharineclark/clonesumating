package Peeps;

use strict;
 
use Class::Inspector;
use Data::Dumper;
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use DBI qw(:sql_types);

use lib qw(. ./lib ../lib);
use template2;
use Profiles;
use cache;
use sphere;

our $dbh;
our $cache = new Cache;

sub handler :method {
    my $class = shift;
    my $r = shift;

    $r->content_type('text/html');

    my $dbActive = ref $dbh && $dbh->ping;

    my $P = Profiles->new(request => $r, cache => $cache, dbh => $dbh);
    unless (ref $P) {
        return 0;
    }
    $P->{user}{global}{section} = 'peeps';

    my $self = {
        req     => $r,
        user    => $P->{user},
        cache   => $P->{cache},
        dbh     => $P->{dbh},
        util    => util->new(dbh => $P->{dbh}, cache => $P->{cache}),
        query   => CGI->new($r),
        P       => $P,
		command	=> $P->{command},
    };
    bless $self, $class;

    $self->prepare() unless $dbActive;

    if ($self->{command} eq "") {
        $self->displayDefault();
    } else {
        my $subclass = 'Peeps::'.ucfirst($self->{command});
        if (Class::Inspector->loaded($subclass)) {
            my $API = $subclass->new(
                req     => $r,
                user    => $P->{user},
                cache   => $P->{cache},
                dbh     => $P->{dbh},
                util    => util->new(dbh => $P->{dbh}, cache => $P->{cache}),
                query   => CGI->new($r),
                P       => $P,
            );
            return $API->display;
        } else {
            $self->displayDefault();
        }
    }

    return 0;
}

sub displayDefault {
	my $self = shift;

	(my $offset = $self->{user}{page}{offset}) = $self->{query}->param('offset') || 0;
	$self->{user}{page}{offset} += 20;

	my %sphere = getSphere($self->{dbh}, $self->{user});
	unless (keys %sphere) {
		print $self->{P}->process("Peeps/view.html");
		return 0;
	}

	my $onlinenow = getMinisphere(join(',',keys %sphere), $self);

	(my $noPhotos = $self->{user}{page}{exclude_photos}) = $self->{query}->param('exclude_photos');
	(my $noQuestions = $self->{user}{page}{exclude_questions}) = $self->{query}->param('exclude_questions');
	(my $noTopics = $self->{user}{page}{exclude_topics}) = $self->{query}->param('exclude_topics');

	my @queries;

	my $userids = join(',',keys %sphere);

	unless ($noPhotos) {
		push @queries,"(SELECT NULL AS text,photoId,NULL AS videoId, userId, 'photo' AS type,insertDate AS date,id,contestId,1 AS enabled FROM photo_contest_entry WHERE userId IN ($userids))";
	}
	unless ($noQuestions) {
		push @queries,"(SELECT answer AS text,photoId,videoId,userId,'qow' AS type,date,id,questionId AS contestId,1 AS enabled FROM questionresponse WHERE userId IN ($userids))";
	}
	unless ($noTopics) {
		push @queries,"(SELECT question AS text,NULL AS photoId,NULL AS videoId,userId,'topic' AS type,date,id,NULL AS contestId,enabled FROM profileTopic WHERE userId IN ($userids))";
	}
	
	my $sql = join(" UNION ",@queries) . " ORDER BY date DESC LIMIT $offset,20";
warn "$sql;";
	my $sth = $self->{dbh}->prepare($sql);

	$sth->execute;
	while (my $e = $sth->fetchrow_hashref) {
		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $e->{userId}) or next;
		$U->{profile}{daysleft} = 8 - $sphere{$U->{profile}{id}}{days} if ($sphere{$U->{profile}{id}}{days} < 10);
		
		delete $e->{photoId} if ($e->{photoId} eq "" || $e->{photoId} eq "0");
		delete $e->{videoId} if ($e->{videoId} eq "" || $e->{videoId} eq "0");

		my ($vote,$entry);
		if ($e->{type} eq 'qow') {
			$self->{sth}{getQuestion}->execute($e->{contestId});
			$entry = $self->{sth}{getQuestion}->fetchrow_hashref;

			$self->{sth}{getQuestionVote}->execute($e->{id},$self->{user}{user}{id});
			$vote = $self->{sth}{getQuestionVote}->fetchrow_hashref;
		} elsif ($e->{type} eq 'photo') {
			$self->{sth}{getContest}->execute($e->{contestId});
			$entry = $self->{sth}{getContest}->fetchrow_hashref;

			$e->{enabled} = $entry->{itson};
			
			$self->{sth}{getContestVote}->execute($e->{id}, $self->{user}{user}{id});
			$vote = $self->{sth}{getContestVote}->fetchrow_hashref;
		} elsif ($e->{type} eq 'topic') {
			$self->{sth}{getResponseCount}->execute($e->{id});
			$entry = $self->{sth}{getResponseCount}->fetchrow_hashref;
		}

		push @{$self->{user}{updates}}, {
			content		=> $e,
			user		=> $U->profile,
			entry		=> $entry,
			vote		=> $vote
		};
	}

	print $self->{P}->process("Peeps/view.html") if ref($self) eq 'Peeps';
}

sub prepare {
	my $self = shift;

	my $datestr = 'DATE(b.insertDate) = DATE(DATE_SUB(NOW(), INTERVAL ? DAY))';

	for 
	(
		[ getQuestion		=> "SELECT * FROM questionoftheweek WHERE id = ?" ],
		[ getContest		=> "SELECT * FROM photo_contest WHERE id = ?" ],
		[ getQuestionVote	=> "SELECT * FROM bling WHERE questionresponseId = ? AND userId = ?" ],
		[ getContestVote	=> "SELECT * FROM photo_contest_bling WHERE entryId = ? AND userId = ?" ],
		[ getResponseCount	=> "SELECT COUNT(*) AS count FROM profileResponse WHERE profileTopicId = ?" ],
		[ profileThumbs		=> "SELECT COUNT(*) FROM thumb b WHERE profileId = ? AND type = ? AND $datestr" ],
		[ questionThumbs	=> "SELECT COUNT(*) FROM bling b INNER JOIN questionresponse r ON b.questionresponseId = r.id WHERE r.userId = ? AND type = ? AND $datestr" ],
		[ photoThumbs		=> "SELECT COUNT(*) FROM photo_contest_bling b INNER JOIN photo_contest_entry e ON b.entryId = e.id WHERE e.userId = ? AND type = ? AND $datestr" ],
	)
	{
		$self->{sth}->{$_->[0]} = $self->{dbh}->prepare($_->[1]);
	}

}

1;
