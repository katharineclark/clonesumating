package api::updates;

use strict;
 
use Data::Dumper;
use lib qw(lib ../lib ../../lib);
use api;
use sphere;
use Users;

our @ISA = qw(api);

sub showTags {
	my $self = shift;
	my $uid = $self->{query}->param('userId');
	my $timeframe = $self->{query}->param('timeframe');

	my $timeframesql = " > DATE_SUB(NOW(),INTERVAL $timeframe) ";
	if ($timeframe eq "1 DAY") {
		$timeframesql = " >= DATE(NOW()) ";
	}

	unless ($uid) {
		return $self->generateResponse('fail','','No user chosen!');
	}

	my $sql = "SELECT tagId,addedById, profileId, profileId as primaryUser, dateAdded as date, (TIME_TO_SEC(TIMEDIFF(NOW(),dateAdded)) / 60) "
				."AS minutes, anonymous FROM tagRef WHERE (((addedById = $uid OR profileId = $uid) AND "
				.($uid == $self->{user}{user}{id} ? "1) " : "anonymous=-1) ")
				."OR (addedById = $uid AND profileId = $uid)) AND dateAdded $timeframesql ORDER BY dateAdded DESC";


	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my %tags;
	my $Tags = tags->new($self->{cache}, $self->{dbh});
	my @ret;
	while (my $item = $sth->fetchrow_hashref) {
		my $tag = $Tags->getTagref($item->{profileId},$item->{tagId});
		$item->{value} = $tag->{value};


		$item->{timesince} = $self->{util}->timesince($item->{minutes});
		$item->{direction} = $item->{addedById} == $uid ? 'out' : 'in';

		if ($item->{direction} eq 'in') {
			($item->{handle},$item->{linkhandle}) = $self->{util}->getHandle($item->{addedById});
			my $user = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $item->{addedById});        
			my ($blocklist,$tagblock);
			if ($user) {
				$blocklist = $user->getBlocklist($uid);
				$tagblock = (ref $blocklist eq 'ARRAY' && grep {'tag'} @$blocklist) ? 1 : 0;
			}

			push @ret, qq|<tag tagvalue="$item->{value}" direction="in"><![CDATA[ |
				.($item->{anonymous} == 1 ? '' : qq|by <a href="/profiles/$item->{linkhandle}">$item->{handle}</a>| )
				.qq| $item->{timesince} ago. |
				.($item->{profileId} eq $self->{user}{user}{id} && $item->{addedById} != $self->{user}{user}{id} && $item->{anonymous} != 1 && !$tagblock
					? qq|<a href="#" onclick="tagBack($item->{addedById},'$item->{handle}','$item->{linkhandle}');return false;">tag back!</a>|
					: ''
				 )
				.qq|]]></tag>|;
		} else {
			($item->{handle},$item->{linkhandle}) = $self->{util}->getHandle($item->{profileId});
			push @ret, qq|<tag tagvalue="$item->{value}" direction="out"><![CDATA[ |.($item->{anonymous} == 1 ? '' : qq|to <a href="/profiles/$item->{linkhandle}">$item->{handle}</a>| ).qq| $item->{timesince} ago.]]></tag>|;
		}

		$tags{$item->{value}} = $item;
	}
	return $self->generateResponse('ok','handleShowTags',"<uid>$uid</uid>@ret");
}

sub peepHistory {
	my $self = shift;
	my $userId = $self->{query}->param('userId');

	my %sphere = getSphere($self->{dbh},$self->{user});

	unless ($sphere{$userId}) {
		return $self->generateResponse('fail','',"This isn't one of your peeps!");
	}
	my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userId) or return generateResponse('fail','',"User not found!");

	my $ret;
	if ($sphere{$userId}{reason} eq 'hotlist') {
		$ret = qq|<reason>default</reason><body><![CDATA[<a href="/profiles/$User->{profile}{linkhandle}">$User->{profile}{handle}</a> is on your hotlist.]]></body>|;
	} elsif ($sphere{$userId}{reasaon} eq 'newmessages') {
		$ret = qq|<reason>default</reason><body><![CDATA[You have new messages from <a href="/profiles/$User->{profile}{linkhandle}">$User->{profile}{handle}</a><]]>/body>|;
	} elsif ($sphere{$userId}{questionId}) {
		my $data = loadQuestion($self,$sphere{$userId}{questionId});
		$ret = qq|<reason>question</reason><handle>$User->{profile}{handle}</handle><linkhandle>$User->{profile}{linkhandle}</linkhandle><question>$data->{question}</question><questionId>$data->{id}</questionId>|;
	} elsif ($sphere{$userId}{tagId}) {
		my $data = loadTag($self,$sphere{$userId}{tagId});
		$ret = qq|<reason>tag</reason><handle>$User->{profile}{handle}</handle><linkhandle>$User->{profile}{linkhandle}</linkhandle><tag>$data->{value}</tag>|;
	} elsif ($sphere{$userId}{contestId}) {
		my $data = loadContest($self,$sphere{$userId}{contestId});
		my $photoId = $self->{dbh}->selectrow_array("SELECT photoId FROM photo_contest_entry WHERE contestId=$data->{id} AND userId=$self->{user}{user}{id}");
		$ret = qq|<reason>contest</reason><handle>$User->{profile}{handle}</handle><linkhandle>$User->{profile}{linkhandle}</linkhandle><contest>$data->{shortname}</contest><contestId>$data->{id}</contestId><photoId>$photoId</photoId>|;
	} else {
		$ret = qq|<reason>default</reason><body><![CDATA[You gave a thumbs up to <a href="/profiles/$User->{profile}{linkhandle}">$User->{profile}{handle}</a>]]></body>|;
	}
	
	return $self->generateResponse('ok','handlePeepHistory',$ret);
}


sub loadQuestion {
	my $P = shift;
	my ($qid) = @_;

	my $sth = $P->{dbh}->prepare("SELECT question,date,id FROM questionoftheweek WHERE ID=?");
	$sth->execute($qid);
	my $r = $sth->fetchrow_hashref;
	$sth->finish;
	return $r;
}


sub loadTag {
    my $P = shift;
    my ($qid) = @_;


    my $sth = $P->{dbh}->prepare("SELECT value,id FROM tag WHERE id=?");
    $sth->execute($qid);
    my $r = $sth->fetchrow_hashref;
    $sth->finish;
    return $r;



}

sub loadContest {
    my $P = shift;
    my ($qid) = @_;


    my $sth = $P->{dbh}->prepare("SELECT name,shortname,description,id  FROM photo_contest WHERE ID=?");
    $sth->execute($qid);
    my $r = $sth->fetchrow_hashref;
    $sth->finish;
    return $r;



}


1;
