package CM_Tags;
use strict;
use Exporter;
use tags;
use Cache;
use Users;
use Alerts;

our @ISA    = qw(Exporter);
our @EXPORT = qw(addTag tagSplit removeTag cleanTag);

our $memcache = new Cache;

sub cleanTag {
	my ($tag) = @_;

# clean anything that isn't alpha, numeric, or an underscore
# also allow 8859-1 letters, but not symbols

	$tag =~ s/[^A-Za-z0-9\_\xc0-\xff]//gsm;
	return $tag;


}

sub tagSplit {
        my ($taglist) = @_;

        my @tags;        
    
        while ($taglist =~ /"(.*?)"/) {
			my $tag = $1;
			$taglist =~ s/"$tag"//gsm;
        }
        push(@tags,split(/\s+/,$taglist));
    
        return @tags;
}


sub removeTag {
	my ($dbh,$tid,$uid) = @_;
	my ($sql,$sth);

	# check if it's a contest tag
	my $name = $dbh->selectrow_array("SELECT value FROM tag WHERE id = ?",undef,$tid);
	if ($name =~ /_contest/) {
		# get the current contest
		my ($cid,$contestname) = $dbh->selectrow_array("SELECT id,tagname FROM photo_contest WHERE itson=1 ORDER BY startDate DESC LIMIT 1");
		my $cntag = lc cleanTag($contestname.'_contest');
		# are the entered?
		my $entry = $dbh->selectrow_array("SELECT COUNT(*) FROM photo_contest_entry WHERE contestId = ? AND userId = ?",undef,$cid,$uid);
		if ($cntag eq $name && $entry > 0) {
			# don't let them remove this tag!
			return;
		}
	}

#warn "REMOVE TAG $tid, $uid";
	# clear from cache
	my $GlobalTagRef = new tags($memcache,$dbh);
	$GlobalTagRef->removeTagrefById($uid,$tid);
#warn "REMOVE TAG 2: $tid, $uid";

	# clear from db
	$sql = "DELETE FROM tagRef WHERE tagId=$tid AND profileId=$uid;";
	$sth = $dbh->prepare($sql);
	$sth->execute;
#warn "REMOVE TAG 3: $tid, $uid";
	$sth->finish;

}

sub addTag {
	
	my ($dbh,$tag,$pid,$uid) = @_;
	my ($source,$sql,$sth,$tid);


	# check and make sure this person hasn't been flagged.

	$sql = "SELECT trouble FROM users WHERE id=?";
	$sth = $dbh->prepare($sql);
	$sth->execute($uid);
	my $trouble = $sth->fetchrow;
	$sth->finish;
	if ($trouble eq "Y") {
		return;
	}


	# make sure the person and/or tag isn't blocked

	$sth = $dbh->prepare("SELECT COUNT(*) FROM blocklist WHERE type='tag' AND profileId=? AND userId=?");
	$sth->execute($pid,$uid);
	if ($sth->fetchrow > 0) {
		return;
	}

	$sql = "SELECT COUNT(*) FROM user_blocked_tags WHERE type=? AND profileId = ? AND value = ?";
	$sth = $dbh->prepare($sql);
	$sth->execute('user',$pid,$uid);
	if ($sth->fetchrow > 0) {
		return;
	}

	$tag = cleanTag($tag);

	$sth->execute('tag',$pid,lc($tag));
	if ($sth->fetchrow > 0) {
		return;
	}

	# see if the user is an anonymous tagger, and if so see if the target allows anonymous taggers
	my $anon = 1;
	my $go = 1;
	if ($uid == $pid) {
		# always allowed to tag yourself
		#warn "TAGGING YOURSELF $tag";
		$go=1;
	} else {
		$sql = "SELECT id,userId,tagPublicly,allowAnonymousTags FROM profiles WHERE userId = ? OR userId = ?";
		$sth = $dbh->prepare($sql);
		$sth->execute($uid,$pid);
		while (my @r = $sth->fetchrow) {
			if ($r[1] == $pid) {
				# allow anonymous tags?
				$go = $r[3];
			} elsif ($r[1] == $uid) {
				# anonymous tagger?
				$anon = $r[2] == 0 ? 1 : $r[2] == 1 ? 0 : -1;
			}
		}
		$sth->finish;

		#warn "ADD TAG: $go, $anon";
		if (!$go && $anon == 1) {
			# they do not allow anonymous tags and the tagger is currently anonymous
			# warn "they do not allow anonymous tags and the tagger is currently anonymous";
			return;
		}
	}
			


	$sql = "SELECT id FROM tag WHERE value=?";
	#warn $sql;
	$sth = $dbh->prepare($sql);
	$sth->execute($tag);
	if (!( $tid = $sth->fetchrow)) {
		$tag = lc($tag);
		$sql = "INSERT INTO tag (value,insertDate,addedBy) VALUES (?,NOW(),?)";
		$sth = $dbh->prepare($sql);
		$sth->execute($tag,$uid);
		$tid = $sth->{mysql_insertid};

	}
	$sth->finish;

	if ($uid eq $pid) {
			$source = "O";
	} else {
			$source = "U";
	}

	#warn "DELETE FROM tagRef WHERE profileId=$pid and tagId=$tid;";
	$dbh->do("DELETE FROM tagRef WHERE profileId=? and tagId=?",undef,$pid,$tid);
	$dbh->do("INSERT INTO tagRef (profileId,tagId,source,addedById,dateAdded,anonymous) VALUES (?,?,?,?,NOW(),?);",undef,$pid,$tid,$source,$uid,$anon);


	if ($pid != $uid) {
		my $A = Alerts->new(dbh => $dbh, cache => $memcache, userId => $pid);
		if ($A->checkSub('newtag')) {
			my %data;
			my $User = Users->new(dbh => $dbh, cache => $memcache, userId => $pid);
			$data{user} = $User->profile;
			if ($anon != 1) {
				$User = Users->new(dbh => $dbh, cache => $memcache, userId => $uid);
				$data{tagger} = $User->profile;
			}
			$data{tag}{value} = $tag;
			$A->send('newtag',\%data);
		}
	}
	
	my $GlobalTagRef = new tags($memcache,$dbh);
	$GlobalTagRef->add($pid,$tid);


	return $tid;

}

1;
