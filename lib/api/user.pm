package api::user;

use strict;
 
use Data::Dumper;
use Date::Calc qw(Delta_DHMS Today_and_Now);
use LWP::UserAgent;

use lib qw(lib ../lib ../../lib);
use api;
use Users;
use points;
use CM_Tags;
use QuestionResponse;
use sphere;
use invite;

our @ISA = qw(api);

sub addTag {
	my $self = shift;

	my $tag = $self->{query}->param('tag');
	my $userId = $self->{query}->param('userId');
	if ($self->{actingUser}) {
		my $data;
		foreach $tag (tagSplit($tag)) {
			if (my $tid = CM_Tags::addTag($self->{dbh},$tag,$userId,$self->{actingUser})) {
				$data .= "<tag><userId>$userId</userId><id>$tid</id><value>$tag</value></tag>\n";
			}
		}
		return length $data ? $self->generateResponse("ok","tagAdded",$data) : $self->generateResponse("fail","","not allowed!");
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub getTags {
	my $self = shift;

	my $userId = $self->{query}->param('userId');

	return $self->generateResponse('fail','','Missing UserID') unless $userId;

	my $GlobalTagRef = tags->new($self->{cache}, $self->{dbh});

	my $tags = $GlobalTagRef->getProfile($userId);
	my $psth = $self->{dbh}->prepare("SELECT p.handle FROM profiles p, users u WHERE p.userId = u.id AND u.id = ?");

	my %tags;
	my $sortTags = sub {
		$tags{$a} ||= $GlobalTagRef->getTagref($userId,$a);
		$tags{$b} ||= $GlobalTagRef->getTagref($userId,$b);
		return $tags{$b}->{dateAdded} cmp $tags{$a}->{dateAdded};
	};
	my $cnt = 0;
	my (@Otags,@Utags);
	for (sort $sortTags @$tags) {
		my $tag = $tags{$_};
		next unless $tag->{value} && $tag->{dateAdded};
		my $user;
		if ($tag->{anonymous} < 1) { 
			$user = $self->{util}->getHandle($tag->{addedById});
		}
		$tag->{addedby} = $user;
		$tag->{linkaddedby} = $self->{util}->linkify($user);

		my ($d,$t) = split / /,$tag->{dateAdded};

		my @delta = Delta_DHMS(split(/-/,$d),split(/:/,$t),Today_and_Now);
		$tag->{timesince} = $self->{util}->timesince($delta[0]*1440 + $delta[1]*60 + $delta[2] + int($delta[3]/60));

		if ($tag->{source} eq 'O') {
			push @Otags, $tag;
		} else {
			push @Utags, $tag;
			$cnt++;
		}

	}
	@Otags = sort {$a->{value} cmp $b->{value}} @Otags;
	my $data = join"\n",(map {$self->hashToXML("tag",$_)} @Otags,@Utags);

	return $self->generateResponse("ok","tagList",$data);

}

sub deleteTag {
	my $self = shift;

	if ($self->{actingUser} == $self->{query}->param('userId')) {
		my $tid = $self->{query}->param('tagId');
		removeTag($self->{dbh},$tid,$self->{actingUser});

		my ($u,$t) = map{$self->{query}->param($_)||undef}qw(blockuser blocktag);
		if ($u) {
			#$self->{dbh}->do("INSERT INTO user_blocked_tags (type,value,profileId) VALUES ('user',?,?)",undef,$u,$self->{actingUser});
			# put in blocklist
warn "ADDDING TO BLOCKLIST";
			$self->{dbh}->do("INSERT INTO blocklist (profileId,userId,type) VALUES (?,?,'tag')",undef,$self->{user}{user}{id},$u);

			if (ref $self->{cache}->get("block$self->{user}{user}{id}") eq 'ARRAY') {
				my $blocklist = $self->{cache}->get("block$self->{user}{user}{id}");
				my $found = 0;
				for (@$blocklist) {
					if ($_ eq $u) {
						$found = 1;
						last;
					}
				}
				unless ($found) {
					push @$blocklist, $u;
					$self->{cache}->set("block$self->{user}{user}{id}",$blocklist);
				}
			} else {
				$self->{cache}->set("block$self->{user}{user}{id}",[$u]);
			}

			if (my $ref = $self->{cache}->get("block$self->{user}{user}{id}-$u")) {
				push @$ref,'tag';
				my %r = map {$_ => 1} @$ref;
				my @r = keys %r;
				$self->{cache}->set("block$self->{user}{user}{id}-$u",\@r);
			} else {
				$self->{cache}->set("block$self->{user}{user}{id}-$u",['tag']);
			}
		}
		if ($t) {
			$self->{dbh}->do("INSERT INTO user_blocked_tags (type,value,profileId) VALUES ('tag',?,?)",undef,$t,$self->{actingUser});
		}


		my $data = "<tagId>$tid</tagId>";
		return $self->generateResponse("ok","tagDeleted",$data);
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
	
}

sub deleteOtherTag {
	my $self = shift;
	if ($self->{actingUser}) {
		my $tid = $self->{query}->param('tagId');
		my $sql = "SELECT t.value,r.addedById FROM tagRef r, tag t WHERE t.id=r.tagId AND r.tagId = ? AND r.profileId = ?";
		warn "SELECT t.value,r.addedById FROM tagRef r, tag t WHERE t.id=r.tagId AND r.tagId = $tid AND r.profileId = $self->{actingUser}";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute($tid,$self->{actingUser});
		if ($sth->rows) {
			my ($tag,$addedBy) = $sth->fetchrow;
			warn $self->generateResponse("ok","deleteTagInfo","<addedBy>$addedBy</addedBy><tag id='$tid'>$tag</tag>");
			return $self->generateResponse("ok","deleteTagInfo","<addedBy>$addedBy</addedBy><tag id='$tid'>$tag</tag>");
		} else {
			return $self->generateResponse("fail","","Invalid input");
		}
		$sth->finish;
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}

}
	
sub get {
	my $self = shift;

	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{query}->param('userId')) or return $self->generateResponse('fail','','');

	if ($self->{query}->param('topic') == 1) {
		# show current topic
		$U->{profile}{topic} = $self->{dbh}->selectrow_array("SELECT question FROM profileTopic WHERE enabled = 1 AND userId = ?",undef,$U->{profile}{id});
		$U->{profile}{topic} = util::shortenString($U->{profile}{topic},80) if length $U->{profile}{topic};
		
	}
	return $self->generateResponse('ok','',$self->hashToXML("user",$U->{profile}));

}

sub getRandomRecommendation {
	my $self = shift;
	if ($self->{actingUser}) {
		my $sql = "SELECT type,lookup FROM related WHERE userId=? ORDER BY RAND() LIMIT 1;";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute($self->{actingUser});
		my $rel = $sth->fetchrow_hashref;
		$sth->finish;   
						
		$sql = "SELECT handle,tagline,city,state,country,photos.id as photoId,users.id as userId FROM (users inner join profiles on users.id = profiles.userId) inner join photos on photos.userId=users.id and photos.rank=1 WHERE users.id IN ($$rel{lookup}) ORDER BY RAND() limit 1;";
		$sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		my $prof = $sth->fetchrow_hashref;
		$sth->finish;
		
		$prof->{linkhandle} = linkify($prof->{handle});
		my %res  = (%{$prof} , %{ $rel });
		my $data = $self->hashToXML("profile",\%res);
		return $self->generateResponse("ok","printRecommendation",$data);
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}

}
sub getRecommendation {
	my $self = shift;
	if ($self->{actingUser}) {
		my $filter = $self->{query}->param('filter');
        my $distance = $self->{query}->param('distance') || '';
        my $sex = $self->{query}->param('sex') || '';

		my $ids;
        if ($filter eq "similar" ||$filter eq "quirky") {
			my $sth =  $self->{dbh}->prepare("select lookup from related where userId=$self->{user}{user}{id} AND type='$filter';");

			$sth->execute;
			$ids = $sth->fetchrow;
			$sth->finish;
        } elsif ($filter eq "likeyou") {
			my $sth = $self->{dbh}->prepare("select userId from thumb where type='U' and profileId=$self->{user}{user}{id}");
			$sth->execute;
			my @ids;
			while (my $id = $sth->fetchrow) {
				push(@ids,$id);
			}
			$ids = join(",",@ids);
			$sth->finish;
        } elsif ($filter eq "donotlikeyou") {
			my $sth = $self->{dbh}->prepare("select userId from thumb where type='D' and profileId=$self->{user}{user}{id}");
			$sth->execute;
			my @ids;
			while (my $id = $sth->fetchrow) {
				push(@ids,$id);
			}
			$ids = join(",",@ids);
			$sth->finish;
        }

		my $sql = "SELECT id FROM users WHERE id IN ($ids) ";

        if ($sex) {
			$sql .= " and sex='$sex' ";
        }
		if ($distance) {
			$sql .= " and " . $self->{user}{user}{localQuery};
        }

        $sql .= " ORDER BY popularity desc";


        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;

		my $data;
		while (my $id = $sth->fetchrow) {
			my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $id);

			$data .= $self->hashToXML("profile",$User->profile);
        }

        return $self->generateResponse("ok","printResults",$data);

	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
	
}


sub updateHandle {
	my $self = shift;
	if ($self->{actingUser}) {
        my $sql = "SELECT count(1) FROM profiles WHERE handle=? and userid!=?";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($self->{query}->param('handle'),$self->{actingUser});
        my $c = $sth->fetchrow;
        $sth->finish;
        if ($c > 0) {
			return $self->generateResponse("fail","","Sorry! The handle you specified is already in use.");
        } else {
			$sql = "UPDATE profiles SET handle=? WHERE userid=?";
			$self->{dbh}->do($sql,undef,$self->{query}->param('handle'),$self->{actingUser});
			my $data = "<user>\n<handle>" . $self->protectXML($self->{query}->param('handle')) . "</handle>\n</user>\n";
			return $self->generateResponse("ok","handleUpdated",$data);
        }
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}

}

sub updateTagline {
	my $self = shift;
	if ($self->{actingUser}) {
		my $t = $self->{query}->param('tagline');
		$self->{dbh}->do("UPDATE profiles SET tagline=? WHERE userid=?",undef,$t,$self->{actingUser});
		my $data = "<user>\n<tagline>" . $self->protectXML($self->{query}->param('tagline')) . "</tagline>\n</user>";
		return $self->generateResponse("ok","taglineUpdated",$data);

	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}

}

sub getPhotos {
	my $self = shift;
	if ($self->{actingUser}) {
		my $offset = $self->{query}->param('offset');
		my $sql = "SELECT userId,id FROM photos WHERE userId=$self->{actingUser} order by timestamp desc LIMIT $offset,15;";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		my $data;
		while (my $photo = $sth->fetchrow_hashref) {
			$data .= $self->hashToXML("photo",$photo);
		}
		$sth->finish;
		$sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM photos WHERE userId=$self->{actingUser}");
		$sth->execute;
		my $cnt = $sth->fetchrow;
		$sth->finish;
		if ($cnt > ($offset+15)) {
			$data .= "<more>".($offset+15)."</more>";
		} else {
			$data .= "<more>0</more>";
		}
		if ($offset > 0) {
			$data .= "<less>".($offset-15 > -1 ? $offset-15 : 0)."</less>";
		} else {
			$data .= "<less>-1</less>";
		}


		return $self->generateResponse("ok","displayPhotos",$data);
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub setPhoto {
	my $self = shift;
	if ($self->{actingUser}) {
		my $position = $self->{query}->param('position');
		my $photoId = $self->{query}->param('photoId');
		
		my $swapout = $self->{dbh}->prepare("UPDATE photos SET rank=99 WHERE userId=$self->{actingUser} and rank=?");
		my $swapin = $self->{dbh}->prepare("UPDATE photos SET rank=? WHERE userId=$self->{actingUser} and id=?");
		$swapout->execute($position);
		$swapin->execute($position,$photoId);
		my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{actingUser}, force => 1);
		if ($position == 1) {
			$User->updateField(photoId => $photoId);
			$User->save;
		}
		#$data = "<user>\n<tagline>" . $self->protectXML($self->{query}->param('tagline')) . "</tagline>\n</user>";

		if ($self->{query}->param('dropcontest') == 1) {
			my $cid = $self->{dbh}->selectrow_array("SELECT id FROM photo_contest WHERE itson=1 ORDER BY startDate DESC LIMIT 1");
			my $eid = $self->{dbh}->selectrow_array("SELECT id FROM photo_contest_entry WHERE contestId=? AND userId = ?",undef,$cid,$self->{user}{user}{id});
			$self->{dbh}->do("DELETE FROM photo_contest_entry WHERE contestId = ? AND userId = ?",undef,$cid,$self->{user}{user}{id});

			my $points = $self->{dbh}->selectrow_array("SELECT COUNT(*) * 2 FROM photo_contest_bling WHERE type = 'U' AND entryId=?",undef,$eid);
			$points -= $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM photo_contest_bling WHERE type = 'D' AND entryId=?",undef,$eid);
			$self->{dbh}->do("DELETE FROM photo_contest_bling WHERE entryId = ?",undef,$eid);
			
			$User->updateField('popularity',$User->{profile}->{popularity}-$points);
		}


		return $self->generateResponse("ok","photoSet","<user></user>");

	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub thumb {
	my $self = shift;
	if ($self->{actingUser}) {
		my $pid = $self->{query}->param('userId');
		my $direction = $self->{query}->param('direction');

		my $old = $self->{dbh}->selectrow_array("SELECT type FROM thumb WHERE userId=? AND profileId=?",undef,$self->{actingUser},$pid);

		if ($old ne $direction) {
			$self->{dbh}->do("DELETE FROM thumb WHERE userId=? AND profileId=?",undef,$self->{actingUser},$pid);
			$self->{dbh}->do("INSERT INTO thumb (userId,profileId,type,insertDate) VALUES (?,?,?,NOW());",undef,$self->{actingUser},$pid,$direction);

			my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $pid);
			if (length $old) {
				if ($direction eq 'U') {
					$User->updateField('popularity',$User->{profile}->{popularity}+3);
				} else {
					$User->updateField('popularity',$User->{profile}->{popularity}-3);
				}
			} else {
				if ($direction eq 'U') {
					$User->updateField('popularity',$User->{profile}->{popularity}+2);
				} else {
					$User->updateField('popularity',$User->{profile}->{popularity}-1);
				}
			}
		}

		my $sth = $self->{dbh}->prepare("SELECT count(1) FROM thumb WHERE profileId=? AND type='U';");
		$sth->execute($pid);
		my $up = $sth->fetchrow;
		$sth->finish;
		$sth = $self->{dbh}->prepare("SELECT count(1) FROM thumb WHERE profileId=? AND type='D';");
		$sth->execute($pid);
		my $down = $sth->fetchrow;
		$sth->finish;

		my $data = "<profile><up>$up</up><down>$down</down></profile><thumb>\n<direction>" . $self->protectXML($direction) . "</direction>\n</thumb>";
		return $self->generateResponse("ok","",$data);
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub qowbling {
	my $self = shift;

	if ($self->{actingUser}) {
		my $rid = $self->{query}->param('responseId');
		my $direction = $self->{query}->param('direction');

		# get entryID and old bling
		my $pid = $self->{dbh}->selectrow_array("SELECT userId FROM questionresponse WHERE id = ?",undef,$rid);

		my $old = $self->{dbh}->selectrow_array("SELECT type FROM bling WHERE questionresponseId = ? AND userId = ?",undef,$rid,$self->{actingUser});

		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $pid);
		if (!$old) {
			$self->{dbh}->do("INSERT INTO bling (questionresponseId,userId,type,insertDate) VALUES (?,?,?,NOW())",undef,$rid,$self->{actingUser},$direction);
			if ($direction eq 'U') {
				$U->updateField('popularity',$U->{profile}->{popularity}+2);
			} else {
				$U->updateField('popularity',$U->{profile}->{popularity}-1);
			}
		} elsif ($old ne $direction) {
			$self->{dbh}->do("UPDATE bling SET type = ? WHERE questionresponseId = ? AND userId = ?",undef,$direction,$rid,$self->{actingUser});
			if ($direction eq 'U') {
				$U->updateField('popularity',$U->{profile}->{popularity}+3);
			} else {
				$U->updateField('popularity',$U->{profile}->{popularity}-3);
			}
		}
		my $up = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM bling WHERE questionresponseId = ? AND type = 'U'",undef,$rid);
		my $dn = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM bling WHERE questionresponseId = ? AND type = 'D'",undef,$rid);
		my $data = "<profile><up>$up</up><down>$dn</down></profile><thumb>\n<direction>" . $self->protectXML($direction) . "</direction>\n</thumb>";
		return $self->generateResponse("ok","",$data);
	} else {
		return $self->generateResponse('fail','','Authentication Required');
	}
}
sub photobling {
	my $self = shift;

	if ($self->{actingUser}) {
		my $pid = $self->{query}->param('userId');
		my $direction = $self->{query}->param('direction');

		# get entryID and old bling
		my ($eid,$cid) = $self->{dbh}->selectrow_array("SELECT e.id,c.id FROM photo_contest_entry e INNER JOIN photo_contest c ON e.contestId=c.id WHERE e.userId = ? AND c.itson=1",undef,$pid);
		return $self->generateResponse('fail','',"No entry in active contest for $pid") unless $eid;

		my $old = $self->{dbh}->selectrow_array("SELECT type FROM photo_contest_bling WHERE entryId = ? AND userId = ?",undef,$eid,$self->{actingUser});

		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $pid);
		if (!$old) {
			$self->{dbh}->do("INSERT INTO photo_contest_bling (contestId,entryId,userId,type,insertDate) VALUES (?,?,?,?,NOW())",undef,$cid,$eid,$self->{actingUser},$direction);
			if ($direction eq 'U') {
				$U->updateField('popularity',$U->{profile}->{popularity}+2);
			} else {
				$U->updateField('popularity',$U->{profile}->{popularity}-1);
			}
		} elsif ($old ne $direction) {
			$self->{dbh}->do("UPDATE photo_contest_bling SET type = ? WHERE entryId = ? AND userId = ?",undef,$direction,$eid,$self->{actingUser});
			if ($direction eq 'U') {
				$U->updateField('popularity',$U->{profile}->{popularity}+3);
			} else {
				$U->updateField('popularity',$U->{profile}->{popularity}-3);
			}
		}
		my $up = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM photo_contest_bling WHERE entryId = ? AND type = 'U'",undef,$eid);
		my $dn = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM photo_contest_bling WHERE entryId = ? AND type = 'D'",undef,$eid);
		my $data = "<profile><up>$up</up><down>$dn</down></profile><thumb>\n<direction>" . $self->protectXML($direction) . "</direction>\n</thumb>";
		return $self->generateResponse("ok","thumbed",$data);
	} else {
		return $self->generateResponse('fail','','Authentication Required');
	}
}
			


sub addAnnotation {
	my $self = shift;

         if ($self->{actingUser}) {

			my $pid = $self->{query}->param('userId');
			my $note = $self->{query}->param('note');
			
			$self->{dbh}->do("DELETE FROM annotations WHERE userId=$self->{actingUser} AND profileId=$pid");
			if ($note ne "") {
			my $sth = $self->{dbh}->prepare("INSERT INTO annotations (userId,profileId,note) VALUES (?,?,?);");
			$sth->execute($self->{actingUser},$pid,$note);
			}
			return $self->generateResponse("ok","","");
	} else {
			return $self->generateResponse("fail","","Authentication Required");
	}


}

sub addToHotList {
	my $self = shift;
 	 if ($self->{actingUser}) {
		my $pid = $self->{query}->param('userId');
		my $note = $self->{query}->param('note');
		my $sql = "INSERT INTO hotlist (userId,profileId,dateAdded,note) values (?,?,NOW(),?);";
		$self->{dbh}->do($sql,undef,$self->{actingUser},$pid,$note);
		my $data = "<user>\n<hotlist>true</hotlist></user>>";
		return $self->generateResponse("ok","",$data);
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub removeFromHotList {
	my $self = shift;
	if ($self->{actingUser}) {
		my $sql = "DELETE FROM hotlist WHERE userId=? and profileId=?";
		$self->{dbh}->do($sql,undef,$self->{actingUser},$self->{query}->param('userId'));
		my $data = "<user>\n<hotlist>false</hotlist></user>>";
		return $self->generateResponse("ok","",$data);
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub editHotlistNote {
	my $self = shift;
	if ($self->{actingUser}) {
		my $sql = "UPDATE hotlist SET note = ? WHERE profileId = ? AND userId = ?";
		$self->{dbh}->do($sql,undef,$self->{query}->param('note'),$self->{query}->param('userId'),$self->{actingUser});
		return $self->generateResponse("ok","","");
	} else {
		return $self->generateResponse("fail","","Authentication Required");
	}
}

sub checkMessages {
	my $self = shift;
	my $userId = $self->{query}->param('userId');

	my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM messages WHERE toId = ? AND isread = 0");
	$sth->execute($userId);
	my $count = $sth->fetchrow;
	$sth->finish;

	return $self->generateResponse('ok','updateMessages',"<newmessages>$count</newmessages>");
}

sub saveTagline {
	my $self = shift;
	my $tl = $self->{query}->param('tagline');

warn "TAGLINE $tl";
	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{user}{user}{id});
	util::cleanHtml($tl);
warn "TAGLINE $tl";
	$U->updateField(tagline => $tl);
	my $data = "<user>\n<tagline>" . $self->protectXML($tl) . "</tagline>\n</user>";
	return $self->generateResponse("ok","taglineUpdated",$data);
}

sub addSlideshow {
	my $self = shift;
	my $code = $self->{query}->param('code');
	$code =~ m|instanceid%3D(\d+)|;
	if ($1) {
		$self->{dbh}->do("INSERT INTO slideshow (userid,slideshow) values ($self->{user}{user}{id},$1)");
		return $self->generateResponse('ok','handleAddSlideshow',"<slideshow>$1</slideshow>");
	} else {
		return $self->generateResponse('ok','handleAddSlideshow',"");
	}
}
sub removeSlideshow {
	my $self = shift;
	$self->{dbh}->do("DELETE FROM slideshow WHERE userId = ?",undef,$self->{user}{user}{id});
}

sub sortQOW {
	my $self = shift;

	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{user}{user}{id}) 
		or return $self->generateResponse('fail','',"You're not found!");

warn "OLD ORDER ".join(',',split(/,/,$U->{profile}{qowOrder}));
	my $order = $self->{query}->param('order');
	my @n;
	for my $i (split /&/, $order) {
		my (undef,$n) = split /=/,$i;
		push @n,$n;
	}
warn "NEW ORDER ".join(',',@n);
	$U->updateField(qowOrder => join(',',@n));

	return $self->generateResponse('ok','','');
}
sub changeQowOrder {
	my $self = shift;

	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{actingUser}) 
		or return $self->generateResponse('fail','',"You're not found!");

	my $rid = $self->{query}->param('id');

	return $self->generateResponse('fail','','Missing ID') unless $rid;

	my @order = split /,/,$U->{profile}{qowOrder};
	for (0..$#order) {
		if ($order[$_] eq $rid) {
			splice @order, $_, 1;
			last;
		}
	}
	while (scalar @order > 9) {
		pop @order;
	}
	unshift @order, $rid;

	$U->updateField(qowOrder => join(',',@order));

	return $self->generateResponse('ok','','');
}

sub deleteAnswer {
	my $self = shift;
	my $qrid = $self->{query}->param('questionresponseId');
	my $cnt = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM questionresponse WHERE id = ? AND userId = $self->{user}{user}{id}",undef,$qrid);

	return $self->generateResponse('fail','','This is not your answer!') if $cnt < 1;

	my $QR = QuestionResponse->new(dbh => $self->{dbh}, cache => $self->{cache}, responseId => $qrid);
	$QR->delete();

	# remove from the qowOrder
	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{user}{user}{id});
	$U->updateField(qowOrder => join(',',grep {$_!=$qrid} split /,/,$self->{user}{user}{qowOrder}));

	return $self->generateResponse('ok','','');
}

sub getPeeps {
	my $self = shift;

	my %sphere = sphere::getSphere($self->{dbh},$self->{user});
	my $data;
	for (sort {$sphere{$b}->{actionTime} cmp $sphere{$a}->{actionTime}} keys %sphere) {
		my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $_) or next;
		
		$data .= <<XML;
<user id="$U->{profile}{userId}">
	<photoId>$U->{profile}{photoId}</photoId>
	<handle>$U->{profile}{eschandle}</handle>
	<linkhandle>$U->{profile}{linkhandle}</linkhandle>
</user>
XML
	}
	return $self->generateResponse('ok','handlePeeps',$data);

}

sub invite {
	my $self = shift;
	my $userId = $self->{query}->param('userId');
	my $eventId = $self->{query}->param('eventId');

	my $U = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userId) or return $self->generateResponse('fail','','No user found');
	my $tag = $self->{dbh}->selectrow_array("SELECT tag FROM events WHERE id = ?",undef,$eventId);
	return $self->generateResponse('fail','','No event found') unless $tag;
	$tag .= '_rsvp';

	$self->{query}->param('type','meeting');
	$self->{query}->param('typeId',$eventId);
	$self->{user}{email}{verification} = $self->{util}->encrypt($self->{user}{user}{handle});
	invite::processInvite($self,$U->{profile}{username},$tag);

	return $self->generateResponse('ok','handleInvite','<success>1</success>');
}

sub saveVideo {
	my $self = shift;
	my $path = $self->{query}->param('path');
	my $duration = $self->{query}->param('duration');
	my $src = $self->{query}->param('src');
	my $name = $self->{query}->param('name');
	my $desc = $self->{query}->param('desc');

	$self->{dbh}->do("INSERT INTO videos (userId,name,description,path,duration,source) VALUES (?,?,?,?,?,?)",
		undef,$self->{user}{user}{id},$name,$desc,$path,$duration,$src);
	my $id = $self->{dbh}->selectrow_array("SELECT last_insert_id()");

	return $self->generateResponse('ok','',"<id>$id</id>") if $id;
	return $self->generateResponse('fail','',"<error>NO ID</error>");
}

sub getVideos {
	my $self = shift;
	my $offset = $self->{query}->param('offset') || 0;

	my $sth = $self->{dbh}->prepare("SELECT * FROM videos WHERE userId = $self->{user}{user}{id} ORDER BY id DESC LIMIT $offset,5");
	$sth->execute;

	my $total = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM videos WHERE userId = $self->{user}{user}{id}");
	
	my $data = '<list>';
	while (my $r = $sth->fetchrow_hashref) {
		$data .= qq|<a href="#" onclick="pickVideo($r->{id},'$r->{path}');return false;"><img width="100" src="http://$r->{path}_thumbnail.jpg"/></a>|;
	}
	$data .= '</list>';

	if ($offset + 5 < $total) { 
		$data .= '<more value="'.($offset+5).'"></more>';
	}
	if ($offset - 5 > -1) {
		$data .= '<less value="'.($offset-5).'"></less>';
	}

	return $self->generateResponse('ok','',$data);
}

sub getWeather {
	my $self = shift;

	my $ua = new LWP::UserAgent;
	my $res = $ua->get("http://xml.weather.yahoo.com/forecastrss?p=".$self->{user}{user}{zipcode});
	$res->content =~ m|<yweather:condition text="(.+?)" code="(.+?)".*|s;
	my $cond = lc $1;
	my $code = $2;
	my $condition = $cond;
	if ($cond =~ /cloudy/) {
		$cond = 'cloudy';
	} elsif ($cond =~ /thunder|storm|hail/ || $code < 3) {
		$cond = 'storm';
	} elsif ($cond =~ /snow|freezing|sleet/) {
		$cond = 'snow';
	} elsif ($cond =~ /rain|drizzle|showers/) {
		$cond = 'rain';
	} elsif ($cond =~ /fog/) {
		$cond = 'fog';
	} else {
		$cond = '';
	}


	return $self->generateResponse('ok','',"<condition value='$cond'>$condition</condition>");
}

sub editAnswerText {
	my $self = shift;

	my $rid = $self->{query}->param('id');

	return $self->generateResponse('fail','','Missing Response Id') unless $rid;

	my $QR = QuestionResponse->new(dbh => $self->{dbh}, cache => $self->{cache}, responseId => $rid);
	if (defined $QR) {
		$QR->updateAnswer($self->{query}->param('answer'));
		return "<dat>".$self->{query}->param('answer')."</dat>";
	} else {
		return $self->generateResponse('fail','','Database Error');
	}
}

1;
