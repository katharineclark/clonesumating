package sphere;

 
use DBI;
use Exporter;
use Geo::Distance qw(:all);

use lib qw(. ../lib lib);
use Users;
use tags;
use teams;

@ISA    = qw(Exporter);
@EXPORT = qw(getSphere generateRelated getMinisphere);


my $sametags = 10;
my $metacount = 5;
my $relatedcount = 20;
my $quirkyindex = 98;
my $likesthesamecount = 4;


sub getSphere {
	my ($dbh,$user) = @_;

	my %sphere;
	if (!$$user{user}{id}) {
		return %sphere;
	}
# hot list
        {
			my $sql = "SELECT profileId FROM hotlist WHERE hotlist.userId=$$user{user}{id}";
			my $sth = $dbh->prepare($sql);
			$sth->execute;
			while (my($uid) = $sth->fetchrow) {
				$sphere{$uid}{days} = 999999;
				$sphere{$uid}{reason} = 'hotlist';
			}
			$sth->finish;
        }


# also show people from whom you have new messages waiting


        {
                my $sql = "SELECT fromId FROM messages WHERE toId=$$user{user}{id} and isread=0;";
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                while (my($uid) = $sth->fetchrow) {
					$sphere{$uid}{days} = 999999;
					$sphere{$uid}{reason} ||= 'newmessage';
					$sphere{$uid}{actionTime} = 999999;
                }
                $sth->finish;
        }


#thumbs 
        {
                my $sql = "SELECT profileId,DATEDIFF(NOW(),insertDate) as days,insertDate FROM thumb WHERE thumb.userId=$$user{user}{id} and type='U' and insertDate > DATE_SUB(NOW(),INTERVAL 8 DAY);";
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                while (my($uid,$days,$actionTime) = $sth->fetchrow) {
                        if (!ref($sphere{$uid}) || ($sphere{$uid}{days} != 999999 && $sphere{$uid}{days} > $days)) {
                                $days = $days * 1;
                                $sphere{$uid}{days} = $days;
								$sphere{$uid}{reason} ||= 'profilethumb';	
								$sphere{$uid}{actionTime} = $actionTime;
                        }
                }
                $sth->finish;
        }

# photo contest thumbs

        {
                my $sql = "SELECT distinct(photo_contest_entry.userId),DATEDIFF(NOW(),photo_contest_bling.insertDate) as days,photo_contest_bling.contestId,photo_contest_entry.photoId,photo_contest_bling.insertDate FROM photo_contest_bling, photo_contest_entry WHERE photo_contest_bling.entryId=photo_contest_entry.id AND photo_contest_bling.userId=$$user{user}{id} and type='U' and photo_contest_bling.insertDate > DATE_SUB(NOW(),INTERVAL 8 DAY);";
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                while (my($uid,$days,$qid,$eid,$actionTime) = $sth->fetchrow) {
                        $days = $days * 1;
						if (!ref($sphere{$uid}) || ($sphere{$uid}{days} != 999999 && $sphere{$uid}{days} > $days)) {
                                $sphere{$uid}{days} = $days;
                                $sphere{$uid}{reason} ||= 'photocontest';
                                $sphere{$uid}{contestId} = $qid;
								$sphere{$uid}{photoId} = $eid;
								$sphere{$uid}{actionTime} = $actionTime;
                        }
                }
                $sth->finish;
        }

# question thumbs

        {
                my $sql = "SELECT distinct(questionresponse.userId),DATEDIFF(NOW(),bling.insertDate) as days,questionresponse.questionId,questionresponse.id,bling.insertDate FROM bling inner join questionresponse on bling.questionresponseId=questionresponse.id WHERE bling.userId=$$user{user}{id} and type='U' and bling.insertDate > DATE_SUB(NOW(),INTERVAL 8 DAY);";
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                while (my($uid,$days,$qid,$qrid,$actionTime) = $sth->fetchrow) {
                        $days = $days * 1;
                        if (!ref($sphere{$uid}) || ($sphere{$uid}{days} != 999999 && $sphere{$uid}{days} > $days)) {
                                $sphere{$uid}{days} = $days;
								$sphere{$uid}{reason} ||= 'question';
								$sphere{$uid}{questionId} = $qid;
								$sphere{$uid}{responseId} = $qrid;
								$sphere{$uid}{actionTime} = $actionTime;
                        }
                }
                $sth->finish;
        }



#tags  
       {
                my $sql = "SELECT profileId,DATEDIFF(NOW(),dateAdded) as days,tagRef.tagId,dateAdded FROM tagRef WHERE tagRef.addedById=$$user{user}{id} and dateAdded > DATE_SUB(NOW(),INTERVAL 8 DAY);";
                my $sth = $dbh->prepare($sql);
                $sth->execute;                
				while (my($uid,$days,$tid,$actionTime) = $sth->fetchrow) {
                        if (!ref($sphere{$uid}) || ($sphere{$uid}{days} != 999999 && $sphere{$uid}{days} > $days)) {
                                $days = $days * 1;
                                $sphere{$uid}{days} = $days;
								$sphere{$uid}{reason} ||= 'tag';
								$sphere{$uid}{tagId} = $tid;
								$sphere{$uid}{actionTime} = $actionTime;
                        }
                }                $sth->finish;
        }

# get rid of people who have been explicitly thumbed down full stop
# since being thumbed up or tagged
        {
                my $sql = "SELECT profileId,DATEDIFF(NOW(),insertDate) as days FROM thumb WHERE thumb.userId=$$user{user}{id} and type='D';";
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                while (my($uid,$days) = $sth->fetchrow) {
                        if ($days < $sphere{$uid}) {
                                delete $sphere{$uid};      
     	                  }
                }
                $sth->finish;        

	}

# pull yourself out, cause we're gonna pull that stuff by itself.
        delete $sphere{$$user{user}{id}};


	return %sphere;


}

sub generateRelated {
	my ($dbh,$uid) = @_;

	my (@params,@bad,@taglist,@quirky,@similar,@recommended,@lookups,@meta,@thumbs,@stopwords,@poptags,@ups,@peoplewholike,@final) = ();
	my (%foo);
	# load dating prefs


	$sql = "SELECT peoplePref,wantsMen,wantsWomen,localQuery,relationship1,relationship2,relationship3,relationship4,relationship5 FROM users,profiles WHERE users.status != -2 AND userId=$uid and users.id=profiles.userId;";
	$sth = $dbh->prepare($sql);
	$sth->execute;
	$profile = $sth->fetchrow_hashref;
	$sth->finish;

	if ($profile->{peoplePref} eq "friends") {

		push(@params,$$profile{localQuery});

	} elsif ($profile->{peoplePref} eq "dates") {
		push(@params,$$profile{localQuery});
		if ($profile->{wantsMen} && !$profile->{wantsWomen}) {
			push(@params,"sex='M'");
		} 
		if ($profile->{wantsWomen} && !$profile->{wantsMen}) {
			push(@params,"sex='F'");
		} 
		$relationshipTypes = "";
		foreach $i (1 .. 5) {
			if ($profile->{'relationship' . $i}) {
				$relationshipTypes .= "relationship$i=1 OR ";
			}
		}

		$relationshipTypes =~ s/ OR $//gsm;
		if ($relationshipTypes ne "") {
			push(@params,"($relationshipTypes)");
		}
	}

	if (scalar(@params) > 0) {
		$params = " AND " . join(" AND ",@params);
	}

	$insert = $dbh->prepare("INSERT INTO related (lookup,userId,type) VALUES (?,?,?);");

	$dbh->do("DELETE FROM related WHERE userId=$uid;");

	@bad = ();
	$sql = "SELECT profileId FROM thumb WHERE userId=$uid AND type='D';";
	$stx = $dbh->prepare($sql);
	$stx->execute;
	while ($id = $stx->fetchrow) {
		push(@bad,$id);
		$bad{$id} = 1;
	}
	$stx->finish;

	push(@bad,$uid);


	# get all my tags

	$sql = "SELECT value FROM tag,tagRef WHERE tag.id=tagRef.tagId and tagRef.profileId=$uid AND tagRef.source='O';";

	$stx = $dbh->prepare($sql);
	$stx->execute;
	while ($tag = $stx->fetchrow) {
		push(@taglist,$dbh->quote($tag));
	}
	$stx->finish;

	if (scalar(@taglist) > 0) {


		# FIND QUIRKY RELATIONS

		$sql = "SELECT distinct sum(tag.quirkyness) as quirkyness,handle,tagRef.profileId as userId "
			 . "FROM tag, tagRef,profiles,users inner join photos on users.id=photos.userId and photos.rank=1 "
			 . "where  users.status != -2 AND tagRef.tagId=tag.id AND tag.value in (" . join(",",@taglist) . ") and tagRef.profileId=profiles.userId "
			 . "and profiles.userId=users.id AND users.id not in (" . join(",",@bad) . ")  $params "
			 . "GROUP BY tagRef.profileId having quirkyness > $quirkyindex order by quirkyness desc limit 20";


		$sty=$dbh->prepare($sql);
		$sty->execute;
		$count = 0;
		while ($rec = $sty->fetchrow_hashref) {
			push (@quirky,$rec->{userId});
		}


		if (scalar(@quirky) > 0) {
			$insert->execute(join(",",@quirky),$uid,"quirky");
		}





		# FIND LOTS OF SIMILAR TAGS

		$sametags = int(scalar(@taglist) / 2);

		$sql = "SELECT distinct handle,city,state,country,tagRef.profileId as userId,photos.id as photoId,count(tagRef.tagId) as count FROM tag, tagRef,profiles,users inner join photos on users.id=photos.userId and photos.rank=1 where users.status != -2 AND  tagRef.tagId=tag.id AND tag.value in (" . join(",",@taglist) . ") and tagRef.profileId=profiles.userId and profiles.userId=users.id AND users.id not in (" . join(",",@bad) . ") $params GROUP BY tagRef.profileId having count > $sametags order by count desc";


		$sty=$dbh->prepare($sql);
		$sty->execute;
		$count = 0;
		while ($rec = $sty->fetchrow_hashref) {
			push (@similar,$rec->{userId});
		}

		if (scalar(@similar) > 0) {
			$insert->execute(join(",",@similar),$uid,"similar");
		}





		# FIND SIMILAR TO THOSE I LIKE

		$sql = "SELECT lookup FROM related,thumb WHERE thumb.userId=$uid and thumb.type='U' and thumb.profileId=related.userId and related.type='similar' and thumb.profileId!=$uid;";
		$stx = $dbh->prepare($sql);
		$stx->execute;
		while ($pid = $stx->fetchrow) {
			@lookups = split(/\,/,$pid);
			foreach (@lookups) {
				$foo{$_}++;
			}
		}
		$stx->finish;

		foreach (keys %foo) {
			if (!$bad{$_} && $foo{$_} >= $metacount) {
				push(@meta,$_);
			}
		}


		$sql = "SELECT distinct users.id FROM users,profiles WHERE users.status != -2 AND users.id in (" . join(",",@meta) . ")  and users.id not in (" . join(",",@bad) . ") and profiles.userId=users.id $params;";

		if (scalar(@meta) > 0) {
			@meta = ();
			$sty=$dbh->prepare($sql);
			$sty->execute;
			$count = 0;
			while ($rec = $sty->fetchrow_hashref) {
				push (@meta,$rec->{id});
			}

			if (scalar(@meta) > 0) {
				$insert->execute(join(",",@meta),$uid,"metasimilar");
			}
		}

		# FIND RELATED BY THUMBS

		$sql = "SELECT distinct(profileId) FROM thumb WHERE userId=$uid and type='U'";
		$stx = $dbh->prepare($sql);
		$stx->execute;
		while ($pid = $stx->fetchrow) {
			push(@thumbs,$pid);
		}
		$stx->finish;



		# GET THE TAGS THAT ARE POPULAR WITH THE PEOPLE YOU LIKE
		# THIS WILL PROBABLY BE APPEARANCE TAGS, MOSTLY

		$sql = "select value,tag.id,count(profileId) as count from tag,tagRef where tag.id=tagRef.tagId group by tag.id having count > 1000 order by count desc;";
		$sth = $dbh->prepare($sql);
		$sth->execute;
		while ($tag = $sth->fetchrow_hashref) {
			push(@stopwords,$tag->{id});
		}
		$sth->finish;

		$tagcount = 3;


		if (scalar(@thumbs) > 0) {
			$sql = "SELECT tag.id,count(profileId) count FROM tag inner join tagRef on tag.id=tagRef.tagId and tagRef.profileId in (" . join(",",@thumbs) . ") WHERE tagRef.source='O' AND tag.id NOT IN (" . join(",",@stopwords) . ") GROUP BY tagId HAVING count >= " . $tagcount . " ORDER BY COUNT desc limit 10";
			$sth = $dbh->prepare($sql);
			$sth->execute;
			$count = 0;
			while ($tag = $sth->fetchrow_hashref) {
				push(@poptags,$tag->{id});
			}
			$sth->finish;

		}  # end if any thumbs up



		push(@thumbs,$uid);

		$likesthesamepeople = int(scalar(@thumbs) / 3);
		if ($likesthesamepeople < 3) {
			$likesthesamepeople = 3;
		}

		$sql = "SELECT distinct(profileId) FROM thumb WHERE userId=$uid and type='D'";
		$stx = $dbh->prepare($sql);
		$stx->execute;
		while ($pid = $stx->fetchrow) {
			push(@thumbs,$pid);
		}
		$stx->finish;




		# GET THE PEOPLE WHO LIKE THE SAME PEOPLE AS YOU
		# WE'lL CALL THESE YOUR PEERS
		$sql = "SELECT t2.userId,count(t2.profileId) as count FROM thumb t1,thumb t2 WHERE t1.userId=$uid and t1.profileId=t2.profileId and t1.type='U' and t2.type='U' and t2.userId!=$uid group by t2.userId having count >= $likesthesamepeople  order by count desc;";


		$stx = $dbh->prepare($sql);
		$stx->execute;
		while (($pid,$count) = $stx->fetchrow_array) {
		push(@ups,$pid);
		}
		$stx->finish;




		if (scalar(@ups) > 0) {
			$relatedcount = int(scalar(@ups) / 2);
			if ($relatedcount < 3) {
				$relatedcount = 3;
			}
			if ($relatedcount > 25) {
				$relatedcount = 25;
			}

			# GET THE PEOPLE TAHT AT LEAST 1/2 OF YOUR PEERS LIKE.

			$sql = "SELECT thumb.profileId,count(thumb.userId) as count FROM thumb,users,profiles WHERE users.status != -2 AND thumb.userId IN (" . join(",",@ups) . ") and thumb.type='U' and thumb.profileId not in (" . join(",",@thumbs) . ") and thumb.profileId=profiles.userId and profiles.userId=users.id $params GROUP BY thumb.profileId having count >= $relatedcount order by count desc;";



			$sty=$dbh->prepare($sql);
			$sty->execute;
			$count = 0;
			while ($rec = $sty->fetchrow_hashref) {
				push (@peoplewholike,$rec->{profileId});
			}


			if (scalar(@peoplewholike) > 0) {
				# INCREASE RELEVANCE BY ADDING IN TGS

				if (scalar(@poptags) > 0) {
					$tagcount = int(scalar(@poptags) / 2);
					if ($tagcount > 3) {
						$tagcount = 3; 
					}



					$sql = "SELECT profiles.userId,count(tagRef.tagId) count FROM profiles inner join tagRef on profiles.userId=tagRef.profileId WHERE profiles.userId IN (" . join(",",@peoplewholike) .") AND tagRef.tagId IN (" . join(",",@poptags) . ") GROUP BY profiles.id HAVING count >= $tagcount ORDER BY COUNT desc;";

					$sth = $dbh->prepare($sql);
					$sth->execute;
					while (($pid,$count) = $sth->fetchrow_array) {
						push(@final,$pid);
					}
					$sth->finish;
				} # if any poptags

				if (scalar(@final) > 0) {
					$insert->execute(join(",",@final),$uid,"highlyrecommended");
				}

				if (scalar(@peoplewholike) > 25) {
					$relatedcount += 2;
					@peoplewholike2 = ();

					# GET THE PEOPLE TAHT AT LEAST 1/2 OF YOUR PEERS LIKE.

					$sql = "SELECT thumb.profileId,count(thumb.userId) as count FROM thumb,users,profiles WHERE users.status != -2 AND thumb.userId IN (" . join(",",@ups) . ") and thumb.type='U' and thumb.profileId not in (" . join(",",@thumbs) . ") and thumb.profileId=profiles.userId and profiles.userId=users.id $params GROUP BY thumb.profileId having count >= $relatedcount order by count desc;";

					$sty=$dbh->prepare($sql);
					$sty->execute;
					$count = 0;
					while ($rec = $sty->fetchrow_hashref) {
						push (@peoplewholike2,$rec->{profileId});
					}


				}

				if (scalar(@peoplewholike2) > 0) {
					$insert->execute(join(",",@peoplewholike2),$uid,"recommended");
				} else {
					$insert->execute(join(",",@peoplewholike),$uid,"recommended");
				}
			}

		} # if peoplewholike

	}

}	


sub getMinisphere {
    my ($spherepeople,$P) = @_;
    my $minisphere;
		if (!$P->{user}{user}{id}) {
			return $minisphere;
		}
		if ($spherepeople eq "") {
			return $minisphere;
		}
        my $sql = "SELECT users.id,(TIME_TO_SEC(TIMEDIFF(NOW(),users.lastActive)) / 60) as minutes FROM users inner join profiles on users.id=profiles.userId WHERE users.status != -2 AND users.id IN ($spherepeople) ORDER BY lastActive desc;";
        my $sth = $P->{dbh}->prepare($sql);
        $sth->execute;
        my $count = 0;
        my $onnow = 0;
        while (my ($id,$minutes) = $sth->fetchrow) {
            $minisphere->{$id} = $minutes;
            if ($minutes > 15) {
                $count++;
            } else {
                $onnow++;
            }

            last if ($count > 5);
        }
        $sth->finish;

        $P->{user}{page}{onlinenow} = $onnow;

        $minisphere->{$P->{user}{user}{id}} = 1;
    return $minisphere;
}


sub getSuperSphere {
	my $P = shift;
	my $dbh = $P->{dbh};
	my $lookup = $P->{user}{user}{id};
	my $sth = $dbh->prepare("SELECT sphereId FROM user_sphere WHERE userId = ?");
	$sth->execute($lookup);
	unless ($sth->rows) {
		warn "NO SPHERE!";
		return undef;
	}

	my @list;
	my $id;
	while ($id = $sth->fetchrow_arrayref) {
		push @list, $id->[0];
	}
	my %list = map {$_ => 1} @list;

	#print "LIST: @list\n";
	# find users that have sphere people in common;
	my $sel = $dbh->prepare("SELECT userId FROM user_sphere WHERE sphereId = ? AND userId != $lookup");
	my %sharedUsers;
	for my $uid (@list) {
		#print "Looking for people that like $uid\n";
		$sel->execute($uid);
		my $sid;
		$sel->bind_columns(\$sid);
		while ($sel->fetchrow_arrayref) {
			#print "FOUND $sid for $uid\n";
			$sharedUsers{$sid}{count}++;
		}
	}

	#print "You share sphere-sumaters with ".(scalar keys %sharedUsers)." people.\n";

	# this loops over users that have people in common with you, starting with the people that have the most in common
	my %finalResults;
	$sel = $dbh->prepare("SELECT sphereId FROM user_sphere WHERE userId = ?");
	for my $user (sort {$sharedUsers{$b}{count} <=> $sharedUsers{$a}{count}} keys %sharedUsers) {

		# diff their list against yours.

		# first, get their list
		$sel->execute($user);
		my $sid;
		$sel->bind_columns(\$sid);
		my @slist;
		while ($sel->fetchrow_arrayref) {
			push @slist, $sid;
		}

		# find users in @slist (their sphere) that are not in @list (your sphere) and add them to the final results
		for (@slist) {
			$finalResults{$_}++ if !$list{$_};
		}
	}

	my $sql = "SELECT t.profileId AS id FROM thumb t WHERE t.userId=$lookup AND t.type = 'D' UNION "
	. "SELECT qr.userId AS id FROM questionresponse qr INNER JOIN bling b ON b.questionresponseId = qr.id WHERE b.type='D' AND b.userId = $lookup UNION "
	. "SELECT pe.userId AS id FROM photo_contest_entry pe INNER JOIN photo_contest_bling pb ON pb.entryId = pe.id WHERE pb.type='D' AND pb.userId = $lookup "
	;
	my $bads = $P->{dbh}->selectall_hashref($sql,'id');


	# are we doing a tag search?
	if ($P->{query}->param('tags')) {
		my @tags = grep{!$stoplist{$_}} split / /,$P->{query}->param('tags');

		my $taglookup = $P->{dbh}->prepare("SELECT * FROM tagRef r INNER JOIN tag t ON t.id=r.tagId WHERE t.value IN ('".join("','",@tags)."') AND r.profileId = ?");
		for my $uid (keys %finalResults) {
			$taglookup->execute($uid);
			delete $finalResults{$uid} unless $taglookup->rows;
		}
	}


	# prepare tags in common query
	my @subResults;
	my $trsth = $P->{dbh}->prepare("SELECT tagId FROM tagRef WHERE profileId = ?");
	$trsth->execute($P->{user}{user}{id});
	my @mytags;
	while (my $id = $trsth->fetchrow) { push @mytags, $id }


	my $mypref = [$P->{user}{user}{sex},$P->{user}{user}{wantsMen},$P->{user}{user}{wantsWomen}];
	my $relpref = [map{$P->{user}{user}{"relationship$_"}}(1..5)];
	for (sort {$finalResults{$b} <=> $finalResults{$a}} keys %finalResults) {
		#skip people that are on your downer list
		next if $bads->{$_};
		next if $_ == $P->{user}{user}{id};

		#print "With a total of $finalResults{$_} people liking them besides you, take a gander at $h ($_)\n";
		my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $_) or next;

		$U->{profile}{resultCount} = $finalResults{$_};


		# go by their gender prefs
		if (($U->{profile}{wantsMen} && $mypref->[0] ne 'M') || ($U->{profile}{wantsWomen} && $mypref->[0] ne 'F')) {
			next;
		}
		# go by MY gender prefs
		unless (($mypref->[1] && $U->{profile}{sex} eq 'M') || ($mypref->[2] && $U->{profile}{sex} eq 'F')) {
			next;
		}

		# go by relationship prefs
		my $ok = 0;
		for (1 .. 5) {
			$ok++ if ($U->{profile}{"relationship$_"} == $relpref->[$_=1]);
		}
		next unless $ok;

		# go by my relationship status.  i.e. don't match if I'm taken and they want to date
		next if ($P->{user}{user}{relationshipStatus} == 3 && ($U->{profile}{relationship3} || $U->{profile}{relationship4} || $U->{profile}{relationship5}));

		# go by their relationship status.  i.e. don't match if they're taken and I want to date
		next if ($U->{profile}{relationshipStatus} == 3 && ($P->{profile}{relationship3} || $P->{profile}{relationship4} || $P->{profile}{relationship5}));

		# find tags in common between you and them
		$trsth->execute($U->{profile}{id});
		my ($id,@tags);
		$trsth->bind_columns(\$id);
		while ($trsth->fetchrow_arrayref) { push @tags, $id }

		my $tic = compare_arrays(\@mytags,\@tags);
		next if $tic == 0;

		my $distance = $P->{user}{user}{longitude} && $P->{user}{user}{latitude} && $U->{profile}{longitude} && $U->{profile}{latitude} 
			? sprintf("%0.2f",geo_distance_dirty('mile',$P->{user}{user}{longitude},$P->{user}{user}{latitude},$U->{profile}{longitude},$U->{profile}{latitude}))
			: 9999;

		push @subResults, [$U->profile,$tic,$distance];
	}

	# now sort by people and tags in common
	my @distResults;
	for (
		sort {
			$b->[0]->{profile}{resultCount} <=> $a->[0]->{profile}{resultCount}  # people in common
			|| $b->[1] <=> $a->[1]  # tags in common
		} 
		@subResults) 
	{
		$_->[0]->{tagsInCommon} = $_->[1];
		$_->[0]->{distance} = $_->[2];
		push @distResults,$_;
		last if $#distResults > 50;
	}

	# distance sort
	@{$P->{user}{superResults}} = map {user => $_->[0]} => sort {$a->[2] <=> $b->[2]} @distResults;


	return 1;
}

sub compare_arrays {
	my ($a1,$a2) = @_;
	my $int=0;
	my %count = ();
	foreach my $element (@{$a1}, @{$a2}) { $count{$element}++ }
	foreach my $element (keys %count) {
		if ($count{$element} > 1) {
			$int++;
		}
	}
	return $int;
}

1;
