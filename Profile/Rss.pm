package Profile::Rss;

use strict;
use Page;
use Profile;
use Apache2::Const qw(REDIRECT);
use bbDates;
use Date::Calc qw(Time_to_Date Day_of_Week Day_of_Week_to_Text Month_to_Text Mktime);

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;


	$self->prepare;
	$self->displayDefault;

	my $QR = QuestionResponse->new(dbh => $self->{dbh}, cache => $self->{cache}, force => 1);
	my $responses = $QR->getByUser($self->{user}{profile}{id});

	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{user}{profile}{id}) or return (0);

	my @items;

	for my $question (map {$responses->{$_}} sort {$responses->{$b}->{timestamp} <=> $responses->{$a}->{timestamp}} keys %$responses) {
		next unless length $question->{answer} || $question->{photoId} > 0 || $question->{videoId};
		$self->{sth}{getquestion}->execute($question->{questionId});
		$question->{question} = $self->{sth}{getquestion}->fetchrow;
		util::cleanHtml($question->{answer});

		$question->{linkhandle} = $U->{profile}{linkhandle};

		if ($question->{photoId} > 0) {
			$self->{sth}{photodims}->execute($question->{photoId});
			my ($width,$height) = $self->{sth}{photodims}->fetchrow;

			$question->{answer} =  qq|<a href='/picture.pl?id=$question->{photoId}'><img src="http://img.consumating.com/photos/$self->{user}{profile}{id}/large/$$question{photoId}.jpg" class="qow_illustration" height='$height' width='$width'/></a><br clear="all" />| . $question->{answer};
		}

		my @date = Time_to_Date($question->{timestamp});
warn "DATE @date";
		my $date = Day_of_Week_to_Text(Day_of_Week(@date[0..2])) . ", $date[2] ".Month_to_Text($date[1])." $date[0] $date[3]:$date[4]:$date[5] PST";

		push @items, {
			question => $question, 
			item => {type => 'question', date => $date, sort_date => $question->{timestamp} },
		};
	}

	# get contest entries
	my $entries = $self->{dbh}->selectall_arrayref("SELECT contestId,photoId,c.name,c.description,insertDate FROM photo_contest_entry e,photo_contest c WHERE c.id=e.contestId AND e.userId = $self->{user}{profile}{id}");

	my $currentContestId = $self->{dbh}->selectrow_array("SELECT id FROM photo_contest WHERE itson = 1");
	for my $entry (@$entries) {
		my @datetime = split / /,$entry->[4];
		my @date = split /-/,$datetime[0];
		my $date = Day_of_Week_to_Text(Day_of_Week(@date)) . ", $date[2] ".Month_to_Text($date[1])." $date[0] $datetime[1] PST";
		push @items, {
			contest => {
				id => $entry->[0],
				itson => $currentContestId == $entry->[0] ? 1 : 0,
				photoId => $entry->[1],
				linkhandle => $U->{profile}{linkhandle},
				userId => $self->{user}{profile}{id},
				name => $entry->[2],
				description => $entry->[3],
			},
			item => {type => 'contest', date => $date, sort_date => Mktime(@date,split(/:/,$datetime[1])) }
		};
	}

	$self->{user}{items} = [sort { $b->{item}{sort_date} cmp $a->{item}{sort_date} } @items];

	$self->{req}->content_type('text/xml');
	print $self->{P}->process("Profile/rss.xml",1);



	return (0);
}

sub prepare {
	my $self = shift;

	for
	(
    	[ getquestion	=> "SELECT question FROM questionoftheweek WHERE id = ?" ],
    	[ photodims		=> "SELECT width,height FROM photos WHERE id = ?" ],
	)
	{
		$self->{sth}->{$_->[0]} = $self->{dbh}->prepare($_->[1]) or warn "Failed to prepare $_->[0]: ".$self->{dbh}->errstr;
	}

	$self->SUPER::prepare();
}

1;
