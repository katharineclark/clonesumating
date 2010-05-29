package Profile::Tags;

use strict;
use Page;
use Profile;

our @ISA = qw(Page Profile);

sub display {
	my $self = shift;


    $self->prepare;
    $self->displayDefault;


	if ($self->{query}->param('offset')) {
		return moretags($self);
	} else {	

	#$self->loadTags(99999999);

	my $guserid = $self->{user}{profile}{userId};

	warn "This user is: $guserid";
	my %db_sth = prepareQueries($self);

    my %mytags;
    my $sharedtags = 0;

	warn "self->{user}{user}{id} = " . $self->{user}{user}{id};
    if ($self->{user}{user}{id} && $self->{user}{user}{id} != $guserid) {
# load my tags to do a comparison
		warn "load my own tags";
        $db_sth{gettagId}->execute($self->{user}{user}{id});
        while (my $tag = $db_sth{gettagId}->fetchrow) {
			warn "Loading tag: $tag";
            $mytags{$tag} = 1;
        }
    }


# get tags added to self

	delete $self->{user}{selftags};

    $db_sth{getTags}->execute($guserid,'O');
    while (my $tag = $db_sth{getTags}->fetchrow_hashref) {
        $db_sth{getTagCount}->execute($tag->{tagId});
        $tag->{size} = $db_sth{getTagCount}->fetchrow;
		warn "tag: $$tag{value} = $$tag{size}";
        if ($tag->{size} > 500) {
            $tag->{fontsize} = 20;
        } elsif ($tag->{size} > 100) {
            $tag->{fontsize} = 18;
        } elsif ($tag->{size} > 50) {
            $tag->{fontsize} = 16;
        } elsif ($tag->{size} > 20) {
            $tag->{fontsize} = 14;
        } else {
            $tag->{fontsize} = 12;
        }

		warn "font size: ". $tag->{fontsize};
        push(@{ $self->{user}{selftags} },{tag => $tag});
        if ($mytags{$tag->{tagId}} == 1) {
            push(@{ $self->{user}{sharedtags} },{tag => $tag});
            $sharedtags++;
        }
    }
 my $sql = "SELECT value,tagId,addedById,anonymous,(TIME_TO_SEC(TIMEDIFF(NOW(),tagRef.dateAdded)) / 60) as minutes from tagRef inner join tag on tagRef.tagId=tag.id WHERE tagRef.profileId=? and source=? ORDER BY tagRef.dateAdded DESC LIMIT 0,50";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($guserid,'U');
    while (my $tag = $sth->fetchrow_hashref) {


        if ($guserid == $self->{user}{user}{id}) {
            $tag->{myprofile} = 1;
        }
        $tag->{timesince} = $self->{util}->timesince($tag->{minutes});
        my $u = Users->new(dbh => $self->{dbh}, cache => $self->{cache},userId => $tag->{addedById}) or next;
        push(@{ $self->{user}{addedtags} },{tag => $tag,profile=>$u->profile});
        if ($mytags{$tag->{tagId}} == 1) {
            push(@{ $self->{user}{sharedtags} },{tag => $tag});
            $sharedtags++;
        }
    }

    if ($self->{user}{user}{id} && $self->{user}{user}{id} != $guserid) {

        my $sql = "SELECT value FROM tagRef inner join tag ON tagRef.tagId=tag.id WHERE tagRef.profileId=$guserid AND tagRef.addedById=? ORDER BY tagRef.dateAdded DESC";        my $sth= $self->{dbh}->prepare($sql);
        $sth->execute($self->{user}{user}{id});
        while (my $tag = $sth->fetchrow_hashref) {
            push(@{ $self->{user}{mytags} },{tag => $tag});
        }
        $sth->finish;
    }

    if ($sharedtags > 0) {
        $self->{user}{page}{shared} =  $sharedtags;
    }



	print $self->{P}->process('Profile/tags.html');
	}

	return (0);
}


sub moretags {


    my $self = shift;

    my $guserid = $self->{user}{profile}{userId};

    my %db_sth = prepareQueries($self);


    my $offset = $self->{query}->param('offset') || 0;
    my $sql = "SELECT value,tagId,addedById,anonymous,(TIME_TO_SEC(TIMEDIFF(NOW(),tagRef.dateAdded)) / 60) as minutes "
            . "FROM tagRef INNER JOIN tag ON tagRef.tagId=tag.id WHERE tagRef.profileId=? AND source=? "
            . "ORDER BY tagRef.dateAdded DESC LIMIT $offset,50";


	warn $sql;
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($guserid,'U');
    while (my $tag = $sth->fetchrow_hashref) {
        if ($guserid == $self->{user}{user}{id}) {
            $tag->{myprofile} = 1;
        }
        $tag->{timesince} = $self->{util}->timesince($tag->{minutes});
        my $u = Users->new(dbh => $self->{dbh}, cache => $self->{cache},userId => $tag->{addedById}) or next;
        push(@{ $self->{user}{addedtags} },{tag => $tag,profile=>$u->profile});
        if ($tag->{addedById} == $self->{user}{user}{id}) {
            push(@{ $self->{user}{mytags} },{tag => $tag});
        }
    }

    my $cnt = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM tagRef WHERE source='U' and profileId=?",undef,$guserid);
    if ($cnt > $offset + 50) {
        $self->{user}{page}{offset} = $offset + 50;
    } else {
        $self->{user}{page}{offset} = 0;
    }

    print $self->{P}->process("view.moretags.html",1);
	return 0;


}


sub prepareQueries {    my ($P) = shift;my %db_sth = (    gettagId            => $P->{dbh}->prepare("SELECT tagId FROM tagRef WHERE profileId = ? AND source='O'"),    getTagCount         => $P->{dbh}->prepare("SELECT COUNT(*) FROM tagRef WHERE tagId = ?"),    getTags             => $P->{dbh}->prepare("SELECT value, tagId FROM tagRef r INNER JOIN tag t ON r.tagId=t.id WHERE r.profileId=? AND source=? ORDER BY value"),    getuserid           => $P->{dbh}->prepare("SELECT userId FROM profiles WHERE handle=? OR handle=?"),    updatelastactive    => $P->{dbh}->prepare("UPDATE users SET lastActive = NOW() WHERE id = ?"),    loadmessages        => $P->{dbh}->prepare("SELECT * FROM messages WHERE (fromId=? AND toId=?) OR (fromId=? AND toId=?) ORDER BY date"),    setmessageread      => $P->{dbh}->prepare("UPDATE messages SET isread=1 WHERE toId=? AND fromId=?"),    threerandomtags     => $P->{dbh}->prepare("SELECT value FROM tag t, tagRef r WHERE t.id=r.tagId AND r.profileId=? AND r.source='O' ORDER BY RAND() LIMIT 3"),    topicbyId           => $P->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId,channelId FROM profileTopic WHERE userId=? AND id=? and type='profile'"),    lastTopic           => $P->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId,channelId FROM profileTopic WHERE userId=? and type='profile' ORDER BY date DESC limit 1"),    lastEnabledTopic    => $P->{dbh}->prepare("SELECT enabled,id,question,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes,userId,channelId FROM profileTopic WHERE userId=? AND enabled = 1 and type='profile' ORDER BY date DESC limit 1"),    getResponses        => $P->{dbh}->prepare("SELECT count(1) as count,max(date) as endDate,(TIME_TO_SEC(TIMEDIFF(NOW(),max(date))) / 60) as minutes FROM profileResponse WHERE profileTopicId=?"),    responseCount       => $P->{dbh}->prepare("SELECT COUNT(*) FROM profileResponse WHERE profileTopicId=?"),    responseUsers       => $P->{dbh}->prepare("SELECT DISTINCT userId FROM profileResponse WHERE profileTopicId=? AND userId != ? ORDER BY RAND() LIMIT 8"),    responseBody        => $P->{dbh}->prepare("SELECT response,userId,date,(TIME_TO_SEC(TIMEDIFF(NOW(),date)) / 60) as minutes, id AS responseId FROM profileResponse WHERE profileTopicId = ? ORDER BY date ASC LIMIT ?,?"),
    topicCount          => $P->{dbh}->prepare("SELECT COUNT(*) FROM profileTopic WHERE userId = ?"),
    oldertopicCount     => $P->{dbh}->prepare("SELECT COUNT(*) FROM profileTopic WHERE userId = ? AND id != ?"),
    responses           => $P->{dbh}->prepare("SELECT id AS responseId,response,userId FROM profileResponse WHERE profileTopicId=? ORDER BY date DESC LIMIT 3"),

    checkthumb          => $P->{dbh}->prepare("SELECT type FROM thumb WHERE profileId=? AND userId=?"),
    deletethumb         => $P->{dbh}->prepare("DELETE FROM thumb WHERE profileId=? AND userId=?"),
    insertthumb         => $P->{dbh}->prepare("INSERT INTO thumb (profileId,userId,type,insertDate) VALUES (?,?,?,NOW())"),

    countryname         => $P->{dbh}->prepare("SELECT printable_name FROM country WHERE iso = ?"),

    tagsincommon        => $P->{dbh}->prepare("SELECT COUNT(t1.tagId) FROM tagRef AS t1, tagRef AS t2 WHERE t1.source=t2.source and t1.source='O' and  t1.tagId=t2.tagId AND t1.profileId=? AND t2.profileId=?"),
    threecommontags     => $P->{dbh}->prepare("SELECT value FROM tag t, tagRef t1, tagRef t2 WHERE t1.source=t2.source and t1.source='O' AND  t1.tagId=t2.tagid AND t1.profileId=? AND t2.profileId=? AND t1.tagId=t.id ORDER BY RAND() LIMIT 3"),

    firstmessage        => $P->{dbh}->prepare("SELECT * FROM messages WHERE (fromId=? AND toId=?) OR (fromId=? AND toId=?) ORDER BY date LIMIT 1"),
    firstmessagereply   => $P->{dbh}->prepare("SELECT date FROM messages WHERE toId = ? AND fromId = ? ORDER BY date LIMIT 1"),

    contestparticipant  => $P->{dbh}->prepare("SELECT e.id,c.shortname FROM photo_contest c,photo_contest_entry e WHERE e.contestid=c.id AND e.userid=? AND c.itson=1"),
    contestblingcount   => $P->{dbh}->prepare("SELECT COUNT(*) FROM photo_contest_bling WHERE entryId=? AND type=?"),
    contestblingtype    => $P->{dbh}->prepare("SELECT type FROM photo_contest_bling WHERE entryId=? AND userId=?"),
    contesttotalbling   => $P->{dbh}->prepare("SELECT COUNT(*) FROM photo_contest_bling b, photo_contest_entry e WHERE b.entryId = e.id AND e.userId=? AND b.type=?"),

    checkhotlist        => $P->{dbh}->prepare("SELECT COUNT(*) FROM hotlist WHERE userId=? AND profileId=?"),
  age                 => $P->{dbh}->prepare("SELECT DATE_FORMAT(NOW(), '%Y') - DATE_FORMAT(birthDate, '%Y') - (DATE_FORMAT(NOW(), '00-%m-%d') < DATE_FORMAT(birthDate, '00-%m-%d')) FROM users WHERE id=?"),
    thumbtype           => $P->{dbh}->prepare("SELECT type FROM thumb WHERE userId=? AND profileId=?"),
    getphotos           => $P->{dbh}->prepare("SELECT * FROM photos WHERE userId=? AND rank <= 5 ORDER BY rank"),

    getquestion         => $P->{dbh}->prepare("SELECT question FROM questionoftheweek WHERE id = ?"),
    photodims           => $P->{dbh}->prepare("SELECT width,height FROM photos WHERE id = ?"),

    thumbcnt            => $P->{dbh}->prepare("SELECT COUNT(*) FROM thumb WHERE type=? AND profileId=?"),
    getChannels         => $P->{dbh}->prepare("SELECT name,id FROM profileChannels ORDER BY id;"),
    allEvents           => $P->{dbh}->prepare("SELECT id,name,tag FROM events WHERE approved=1 AND (DATE(date) >= DATE(NOW()) OR date IS NULL OR DATE(date) = '0000-00-00')"),
    attendingEvent      => $P->{dbh}->prepare("SELECT COUNT(*) FROM tagRef r INNER JOIN tag t ON t.id=r.tagId WHERE r.profileId=? AND t.value = ?"),
);  

    return %db_sth;}


