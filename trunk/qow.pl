#!/usr/bin/perl

use strict;

use lib "lib";
 
use strict;
use Profiles;
use template2;
use Users;
use Cache;
use blings;
use QuestionResponse;
use points;
use blog;
use video::videoEgg;

# main 

{ 

	my $P = Profiles->new();
	
	$P->{user}{system}{tab} = "Questions";


	if ($P->{command} eq "") {
		default($P);
	} elsif ($P->{command} eq "/bling") {
		bling($P);
	} elsif ($P->{command} eq "/save") {
		save($P);
	} elsif ($P->{command} eq "/myresponse") {
		myresponse($P);
	}

}


sub default {
	my ($P) = @_;

	# get previous question and most popular response
	my $sql;
	if ($P->{query}->param('question')) {
		$sql = "select * from questionoftheweek where id=" . $P->{query}->param('question');
	} else {
		$sql = "select * from questionoftheweek order by date desc limit 1,1";
	}
	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	%{ $P->{user}{previousquestion} } = %{ $sth->fetchrow_hashref };
	$sth->finish;

	my $offset = $P->{query}->param('offset') || 0;
	# show the most recent question of the week, and all the responses.
	# if the user has responded, highlight it at the bottom and allow dynamic editing.
	# if user is not logged in, offer login / register links

	my $qget = sub {
		$sth = $P->{dbh}->prepare("SELECT * FROM questionoftheweek $_[0]");
		$sth->execute;
		%{$P->{user}{question}} = %{$sth->fetchrow_hashref};
		$sth->finish;
	};

	if ($P->{user}{question}{id} == 103) {
		print $P->{query}->redirect('/contest.pl');
	}

	if ($P->{query}->param('question')) {
		$qget->("WHERE id=".$P->{query}->param('question'));
	} elsif (!$P->{query}->param('question')) {
		$qget->("ORDER BY date DESC LIMIT 1");
	}



	if ($P->{user}{question}{suggestedById}) {
		my $S = Users->new(dbh => $P->{dbh},cache=>$P->{cache},userId => $P->{user}{question}{suggestedById});
		$P->{user}{question}{suggestedBy} = $S->{profile}->{handle};
		$P->{user}{question}{suggestedBylink} = $S->{profile}->{linkhandle};
	}

	my $Blings = new blings (dbh => $P->{dbh}, cache => $P->{cache});
		
	$sth = $P->{dbh}->prepare("SELECT COUNT(*) FROM questionresponse WHERE questionId=?");
	$sth->execute($P->{user}{question}{id});
	my $cnt = $P->{cache}->get("Q$P->{user}{question}{id}ResponseCount");
	my $lastResponse = 0;
	my $count = 0;
	if (1 || $cnt < $sth->fetchrow || !$P->{cache}->get("Q$P->{user}{question}{id}Responses$offset") ) {	
		my $i=0;
		while ($i <= $cnt) {
			$P->{cache}->set("Q$P->{user}{question}{id}Responses$i",'',1);
			$i += 20;
		}
		my $sql;
		if ($P->{user}{user}{id}) {	
			# get votes on this answer
			$sql = "SELECT questionresponse.* FROM questionresponse,profiles WHERE questionresponse.userId=profiles.userid AND questionId=$P->{user}{question}{id} AND ((answer IS NOT NULL AND answer != '') OR photoId > 0) ORDER BY date DESC limit $offset,20;";
		} else {
			$sql = "SELECT questionresponse.* FROM questionresponse,profiles WHERE questionresponse.userId=profiles.userid AND questionId=$P->{user}{question}{id} AND ((answer IS NOT NULL AND answer != '') OR photoId > 0) ORDER BY date DESC limit $offset,20;";
		}

		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$count = 0;


		my $getSize = $P->{dbh}->prepare("SELECT height,width FROM photos WHERE id=?");

		while (my $response = $sth->fetchrow_hashref) {
			if ($response->{id} > $lastResponse) {
				$lastResponse = $response->{id};
			}

			if ($P->{user}{user}{id}) {
				my $bling = $Blings->getBling($response->{id},$P->{user}{user}{id});
				$response->{type} = $bling->{type} || undef;
			}

			util::cleanHtml($response->{answer});

			if ($response->{videoId} > 0) {
				my $ve = video::videoEgg->new(dbh => $P->{dbh},user => $P->{user});
				$response->{videoPath} = $ve->video;
			}

			if ($response->{photoId} > 0) {
				$getSize->execute($response->{photoId});
				my ($height,$width) = $getSize->fetchrow_array;
				($response->{photoHeight},$response->{photoWidth}) = ($height,$width);
				 if ($width == 400) {
					$response->{answer} =  qq|<a onclick="return expandPhoto($response->{id},$height);" href="#"><div class="inlineQOW" onmouseover="hoverlink(this,1)" onmouseout="hoverlink(this,0)" id="qowPhoto$$response{id}" style="background: url('http://img.consumating.com/photos/$$response{userId}/large/$$response{photoId}.jpg') 0% 50% repeat;" /></div></a><br clear="all" />| . $response->{answer};
				} else {
					$response->{answer} =  qq|<a href='/picture.pl?id=$response->{photoId}'><img src="http://img.consumating.com/photos/$$response{userId}/large/$$response{photoId}.jpg" class="qow_illustration" height='$height' width='$width'/></a><br clear="all" />| . $response->{answer};
				}
				#$response->{answer} = "<a href='/picture.pl?id=$response->{photoId}'><img id='responsePhoto$response->{photoId}' src='/photos/$response->{userId}/large/$response->{photoId}.jpg' height='$response->{height}' width='$response->{width}'/></a><br/>$response->{answer}";
			}
			if ($response->{videoId} > 0) {
				my $ve = video::videoEgg->new(dbh => $P->{dbh},user => $P->{user});
				my $path = $ve->video($response->{videoId});
				$response->{answer} = qq|<script language="javascript">videoEgg.drawMovie("$path");</script><br clear="all"/>$response->{answer}|;
			}

			my $User = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $$response{userId}) or next;

			push(@{ $P->{user}{responses} },{response => $response,user => $User->profile, system => $P->{user}{system} });
			$count++;
		}
		$sth->finish;

		$P->{cache}->set("Q$P->{user}{question}{id}ResponseCount$offset",$count,10);
		$P->{cache}->set("Q$P->{user}{question}{id}Responses$offset",$P->{user}{responses});
	} else {
		$P->{user}{responses} = $P->{cache}->get("Q$P->{user}{question}{id}Responses$offset");
		$count = $P->{cache}->get("Q$P->{user}{question}{id}ResponseCount$offset");
	}

	$P->{user}{page}{lastmessage} = defined $P->{user}{responses}[0] ? $P->{user}{responses}[0]{response}{id} : $lastResponse;

	$offset += $count;
	$P->{user}{offset}{next} = $offset;


	if ($P->{user}{user}{id} && $P->{user}{user}{profileId}) {
		$P->{user}{qow}{readytopost} = 1;
	}

	if ($P->{user}{user}{id}) {
		$sql = "SELECT * FROM questionresponse WHERE questionId=$P->{user}{question}{id} AND userId=$P->{user}{user}{id};";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		if (my $response = $sth->fetchrow_hashref) {
			%{$P->{user}{response} } = %{ $response };
		}
		$P->{user}{response}{photoId} ||= 0;
		$P->{user}{response}{videoId} ||= 0;
		$sth->finish;
	}

	videoPicker($P);
	videoPicked($P);

	print $P->Header();
	print processTemplate($P->{user},"play/questions/qow.html");


}


sub bling {
	my ($P) = @_;
	my $qrid = $P->{query}->param('qr');
	my $type = $P->{query}->param('t');
	my $uid = $P->{user}{user}{id};

warn "BLING $qrid,$type,$uid";

	my $bling = blings->new(dbh => $P->{dbh}, cache => $P->{cache});
    my $quserid = $P->{dbh}->selectrow_array("SELECT userid FROM questionresponse WHERE id = ?",undef,$qrid);
	if ($type eq 'D' && $bling->checkAbuse($uid,$quserid)) {
		my $blings = $bling->getResponseBlings($qrid);
		my @ups = grep {$blings->{$_}->{type} eq 'U'} keys %$blings;
		my @dns = grep {$blings->{$_}->{type} eq 'D'} keys %$blings;
		print $P->Header();
		print "$type;U-".scalar(@ups).";D-".scalar(@dns);
		return 0;
	}

	$bling->updateBling(
		userId => $uid,
		questionresponseId => $qrid,
		type => $type
	);


    for my $timeframe (qw(1DAY 24HOUR 3DAY 7DAY lastView)) {
        $P->{cache}->set("updatesTemplate$P->{user}{user}{id}-$quserid-$timeframe",'',0) or warn "\n\n$$ CANNOT CLEAR $P->{user}{user}{id}-$quserid-$timeframe TEMPLATE\n\n";
        $P->{cache}->set("updatesLastupdate$P->{user}{user}{id}-$quserid-$timeframe",'',0) or warn "\n\n$$ CANNOT CLEAR $P->{user}{user}{id}-$quserid-$timeframe last update\n\n";
    }


	my $QR = $P->{cache}->get("Qresponse$qrid");
	if (defined $QR) {
		$QR->{response}{type} = $type;
		$P->{cache}->set("Qresponse$qrid",$QR);
	}

	my $blings = $bling->getResponseBlings($qrid);
	my @ups = grep {$blings->{$_}->{type} eq 'U'} keys %$blings;
	my @dns = grep {$blings->{$_}->{type} eq 'D'} keys %$blings;

	print $P->Header();
	print "$type;U-".scalar(@ups).";D-".scalar(@dns);

}

sub save {
	my ($P) = @_;

	my $answer = $P->{query}->param('answer');
	my $qid = $P->{query}->param('questionId');
	my $rid = $P->{query}->param('responseId');
	my $photoId = $P->{query}->param('photoId') || 0;
	my $videoId = $P->{query}->param('videoId') || 0;
	
	util::cleanHtml($answer);

	my $qanswer = $P->{dbh}->quote($answer);

	my $aid;
	if ($rid) {
		my $QR = QuestionResponse->new(dbh => $P->{dbh}, cache => $P->{cache}, responseId => $rid);
		$QR->updatePhoto($photoId);
		$QR->updatevideo($videoId);
		$QR->updateAnswer($answer);
	} else {
		my $QR = QuestionResponse->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id}, questionId => $qid, force => 1);
		if (defined $QR) {
			$QR->delete;
		} else {
			# get question for the description
			my $q = $P->{dbh}->selectrow_array("SELECT question FROM questionoftheweek WHERE id = $qid");

			# add points
			my $Points = points->new(dbh => $P->{dbh}, cache => $P->{cache});
			$Points->storeTransaction({
				userid 	=> $P->{user}{user}{id},
				points	=> $Points->{system}{questionanswer}{amount},
				type	=> 'system',
				desc	=> "$Points->{system}{questionanswer}{desc} $q"
				}
			);
		}
		my $sql = qq|INSERT INTO questionresponse (date,answer,userId,questionId,photoId,videoId) VALUES (NOW(),$qanswer,$P->{user}{user}{id},$qid,$photoId,$videoId);|;
		my $sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$aid = $sth->{mysql_insertid};
		$sth->finish;
		$QR = QuestionResponse->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id}, questionId => $qid, force => 1);

        my $blog = blog->new(db => $P->{dbh});
		if ($blog->blogthis($P->{user}{user}{id},'qow')) {
			my $sql = "SELECT question FROM questionoftheweek WHERE id=$qid";
			my $getQ = $P->{dbh}->prepare($sql);
			$getQ->execute;
			$P->{user}{blog}{question} = $getQ->fetchrow;
			$P->{user}{blog}{questionId} = $qid;
			$P->{user}{blog}{answer} = $answer;
			$P->{user}{blog}{answerId} = $aid;
			if ($photoId ne "0") {
				$P->{user}{blog}{photoId} = $photoId;
			}
			if ($videoId ne "0") {
				$P->{user}{blog}{videoId} = $videoId;
			}
			my $blogpost = processTemplate($P->{user},"blog/qow.html",1);
			$blog->post($P->{user}{user}{id},'qow','Consumating\'s Question of the Week',$blogpost);
		}



	}

	$P->{dbh}->do("UPDATE profiles SET modifyDate=NOW() where userId=$P->{user}{user}{id};");
	$answer =~ s/\n/<BR \/>/gsm;

	my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id});
	my @order;
	if ($U->{profile}{qowOrder} && !$rid) {
		@order = split /,/,$U->{profile}{qowOrder};
		unshift @order, $aid;
		$U->updateField(qowOrder => join(',',@order));
	} elsif (!length $U->{profile}{qowOrder}) {
		my $sth = $P->{dbh}->prepare("SELECT id FROM questionresponse WHERE userId = $P->{user}{user}{id} ORDER BY date DESC");
		$sth->execute;
		my @order;
		while (my $id = $sth->fetchrow) {
			push @order, $id;
		}
		$U->updateField(qowOrder => join(',',@order));
	}

	$P->{cache}->set("Q$qid"."ResponseCount",0);
	
	print $P->{query}->redirect("/qow.pl/myresponse?question=$qid&saved=1");	
	
}


sub myresponse {
	my ($P) = @_;

	my $qid = $P->{query}->param('question');
	$P->{user}{page}{saved} = $P->{query}->param('saved');

# load the question 
	my $q = $P->{dbh}->prepare("SELECT question,id FROM questionoftheweek WHERE id = $qid");
	$q->execute;
	$P->{user}{question} = $q->fetchrow_hashref;

# load my response
	$q = $P->{dbh}->prepare("SELECT * FROM questionresponse WHERE questionId=$qid AND userId=$P->{user}{user}{id};");
	$q->execute;
	$P->{user}{response} = $q->fetchrow_hashref;
	
	$P->{user}{response}{htmlanswer} = $P->{user}{response}{answer};
	$P->{user}{response}{htmlanswer} =~ s/\n/<br \/>/gsm;
	$P->{user}{response}{answer} =~ s/\</&lt;/gsm;
    $P->{user}{response}{answer} =~ s/\>/&gt;/gsm;

# prepare for presentation
    util::cleanHtml($P->{user}{response}{answer});
    
    if ($P->{user}{response}{photoId} > 0) {

	     my $getSize = $P->{dbh}->prepare("SELECT height,width FROM photos WHERE id=?");
    	 $getSize->execute($P->{user}{response}{photoId});
    	 my ($height,$width) = $getSize->fetchrow_array;
   		 if ($width == 400) {
     	 	$P->{user}{response}{htmlanswer} =  qq|<a onclick="expandPhoto($P->{user}{response}{id},$height)" href="#"><div class="inlineQOW" onmouseover="hoverlink(this,1)" onmouseout="hoverlink(this,0)" style="background: url('http://img.consumating.com/photos/$P->{user}{response}{userId}/large/$P->{user}{response}{photoId}.jpg') 0% 50% repeat;" /></div></a><br clear="all" />| . $P->{user}{response}{htmlanswer};
		} else {
     		$P->{user}{response}{htmlanswer} =  qq|<a href='/picture.pl?id=$P->{user}{response}{photoId}'><img src="http://img.consumating.com/photos/$P->{user}{response}{userId}/large/$P->{user}{response}{photoId}.jpg" class="qow_illustration" height='$height' width='$width'/></a><br clear="all" />| . $P->{user}{response}{htmlanswer};
		}
	}
	if ($P->{user}{response}{videoId} > 0) {
		my $ve = video::videoEgg->new(dbh => $P->{dbh},user => $P->{user});
		my $path = $ve->video($P->{user}{response}{videoId});
		$P->{user}{response}{htmlanswer} = qq|<script language="javascript">videoEgg.drawMovie("$path");</script><br clear="all"/>$P->{user}{response}{htmlanswer}|;
	}

	videoPicker($P);
	videoPicked($P);

	print $P->Header();
	print processTemplate($P->{user},"play/questions/qow.myresponse.html");
}


sub videoPicker {
	my ($P) = @_;

	my $show = $P->{query}->param('show') || 5;
	my $offset = $P->{query}->param('offset') || 0;
	if ($offset < 0) { $offset = 0; }
	my ($sql,$sth,$count);
	$sql = "SELECT count(1) FROM videos WHERE userId=$P->{user}{user}{id}";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	my $count = $sth->fetchrow;
	$sth->finish;
    $sql = "SELECT * FROM videos WHERE userId=$P->{user}{user}{id} ORDER BY id DESC LIMIT $offset,$show;";
    $sth = $P->{dbh}->prepare($sql);
    $sth->execute;
	my $shown = 0;

    while (my $video = $sth->fetchrow_hashref) {
		push(@{$P->{user}{videos}},{video => $video});
		$shown++;
    }

	if ($count > ($offset+$shown)) {
		$P->{user}{page}{more} =  $offset + $shown;
	} 
	if ($offset > 0) {
		my $less =$offset - $show;
		$less = 0 if ($less < 0); 
		$P->{user}{page}{less} = $less;
	}

	my $mode = $P->{query}->param('mode');


	my $ve = video::videoEgg->new(dbh => $P->{dbh}, user => $P->{user}, cache => $P->{cache});
	$P->{user}{page}{videoPublisher} = $ve->publisher;

	return;

    print $P->Header();
	if ($mode eq "" || $mode eq "qow") {
    	return processTemplate($P->{user},"play/videopicker/videos.minipicker.html",1);
	} elsif ($mode eq "videocontest") {
		return processTemplate($P->{user},"play/videopicker/videos.minipicker-videocontest.html",1);
	}

}
sub videoPicked {
	my ($P) = @_;

	$P->{user}{video} = $P->{dbh}->selectrow_hashref("SELECT * FROM videos WHERE id = ?",undef,$P->{user}{response}{videoId});

	$P->{user}{page}{contest} = $P->{query}->param('contest');
	$P->{user}{page}{remind} = $P->{query}->param('remind');
	$P->{user}{entry}{ups} = $P->{query}->param('ups');
	$P->{user}{entry}{downs} = $P->{query}->param('downs');
	return;
}
