package api::item;

use strict;
 
use Image::Magick;
use File::Copy;
use Data::Dumper;

use lib qw(lib ../lib ../../lib);
use api;
use items;
use template2;
use Users;
use CONFIG;

our @ISA = qw(api);

my $useritemdir   = "$staticPath/img/items/user";
my $systemitemdir = "$staticPath/img/items/system";

sub getInfo {
	my $self = shift;
	my $userId = $self->{query}->param('userId');
	my $itemId = $self->{query}->param('itemId');
	my $I = new items($self->{cache},$self->{dbh},$userId);

	my $item = $I->{allItems}{$itemId};
	($item->{points},$item->{behavior}) = $I->itemInfo($itemId);
	($item->{behavior},$item->{behaviorcolor}) = split /,/,$item->{behavior};

	my $u = Users->new(dbh => $self->{dbh},cache => $self->{cache}, userId => $item->{ownerId});
	$item->{ownerPhotoId} = $u->{profile}{photoId} || 0;
	
	if (scalar keys %{$item}) {
		my $data = $self->hashToXML('item',$item);
		return $self->generateResponse('ok','showItemInfo',$data);
	} else {
		return $self->generateResponse('fail','','We can\'t find that item!  It may have already been picked up!');
	}
}

sub giveInfo {
	my $self = shift;
	my $userId = $self->{query}->param('userId');
	my $itemId = $self->{query}->param('itemId');
	my $I = new items($self->{cache},$self->{dbh},$self->{user}{user}{id});
	my $item = $I->{pocketItems}{$itemId};
	if (scalar keys %{$item}) {
		$item->{recipientId} = $userId;
		my $sth = $self->{dbh}->prepare("SELECT handle FROM profiles WHERE userId = ?");
		$sth->execute($userId);
		$item->{recipient} = $sth->fetchrow;
		$item->{linkrecipient} = $self->{util}->linkify($item->{recipient});

		$item->{giverId} = $self->{user}{user}{id};
		$sth->execute($self->{user}{user}{id});
		$item->{giver} = $sth->fetchrow;
		$sth->finish;
		$item->{linkgiver} = $self->{util}->linkify($item->{giver});

		$sth = $self->{dbh}->prepare("SELECT id FROM photos WHERE userid=? AND rank=1");
		$sth->execute($self->{user}{user}{id});
		$item->{giverPhotoId} = $sth->fetchrow if $sth->rows;
		$sth->execute($userId);
		$item->{recipientPhotoId} = $sth->fetchrow if $sth->rows;


		my $data = $self->hashToXML('item',$item);
		warn $self->generateResponse('ok','giveItemInfo',$data);
		return $self->generateResponse('ok','giveItemInfo',$data);
	} else {
		warn $self->generateResponse('fail','','No Items');
		return $self->generateResponse('fail','','No Items');
	}
}
sub give {
	my $self = shift;
	my $userId = $self->{query}->param('userId');
	my $itemId = $self->{query}->param('itemId') || $self->{user}{newtoy}{id};

	my $I = new items ($self->{cache},$self->{dbh},$self->{user}{user}{id});

	unless ($userId) {
		# try handle
		my $handle = $self->{query}->param('handle') || $self->{query}->param('sendAddress');
		$userId = $self->{dbh}->selectrow_array("SELECT userid FROM profiles WHERE handle = ?",undef,$handle);
		unless ($userId) {
			# try email
			$userId = $self->{dbh}->selectrow_array("SELECT id FROM users WHERE username=?",undef,$handle);
		}
		unless ($userId) {
			# send invite
			warn "Sending toy invite: item $itemId, email $handle";
			$userId = 0;

			$self->{user}{item} = $I->{allItems}{$itemId};

			my $msg = new mail;
			$msg->set("From",'notepasser@notepasser.consumating.com');
			$msg->set('to',$handle);
			$msg->set("subject","You've been given a toy on Consumating.com!");
			$msg->set("body",processTemplate($self->{user},"invite/toy.txt",1));
			$msg->send;
		}
	}
	warn "GIVING $itemId TO $userId";


	unless ($I->giveItem($userId,$itemId)) {
		warn "ITEM giveItem FAILED";
		return $self->generateResponse('fail','',"You can't do that!") unless $self =~ /Profiles/;
	}

	my $R = new items ($self->{cache},$self->{dbh},$userId);

	# send alert
	my $A = Alerts->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userId);
	if ($A->checkSub('newtoy')) {
		my %data;
		my $User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userId);
		$data{user} = $User->profile;
		$User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $self->{user}{user}{id});
		$data{giver} = $User->profile;

		$data{toy} = $R->{drawerItems}{$itemId};
		
		$A->send('newtoy',\%data);
	}
	

	if ($self =~ /Profiles/) {
		return 1;
	}
	my $data = $self->hashToXML('item',$R->{drawerItems}{$itemId});
	return $self->generateResponse('ok','tradeItem',$data);
}

sub take {
	my $self = shift;
	my $itemId = $self->{query}->param('itemId');
	my $I = new items ($self->{cache},$self->{dbh},$self->{user}{user}{id});
	$I->pickItem($itemId);
	my $data = $self->hashToXML('pitem',$I->{pocketItems}{$itemId});
	$data .= $self->hashToXML('ditem',$I->{drawerItems}{$itemId});
	return $self->generateResponse('ok','restockItems',$data);
}

sub autosave {
	my $self = shift;

	my $pixels = $self->{query}->param('pixels');
	my $asId = $self->{query}->param('autosaveId');

#warn "ITEM AUTOSAVE $asId, $pixels";
		
	if ($asId > 0) {
#warn "UPDATING $asId, $self->{user}{user}{id},$pixels";
		$self->{dbh}->do("UPDATE item_autosave SET pixels=?,updated=NOW() WHERE id=?",undef,$pixels,$asId);
	} else {
#warn "INSERTING $self->{user}{user}{id},$pixels";
		$self->{dbh}->do("INSERT INTO item_autosave (userId,pixels,updated) VALUES (?,?,NOW())",undef,$self->{user}{user}{id},$pixels);
		$asId = $self->{dbh}->selectrow_array("SELECT last_insert_id()");
	}

	return $self->{dbh}->errstr || $asId == 0 
		? $self->generateResponse('fail','',$self->{dbh}->errstr || 'Failed to save!')
		: $self->generateResponse('ok','handleAutosave',"<autosaveId>$asId</autosaveId>");
}

sub loadTemplate {
	my $self = shift;
	my $name = $self->{query}->param('name');

	my $image = Image::Magick->new;
	my $x = $image->read("$systemitemdir/$name.gif");
	if (!$x) {
		my $data;
		for my $i (0..24) {
			my $i2 = $i*2;
			for my $j (0..24) {
				my $j2 = $j*2;
				my $c = "rgb(".join(',',@{[ map{int($_/256)} split(',',$image->Get("pixel[$i2,$j2]"))]}[0..2]).")";
				$data .= qq|<pixel i="$j" j="$i">$c</pixel>|;
			}
		}
		return $self->generateResponse('ok','handleLoadTemplate',$data);
	}

	return $self->generateResponse('fail','',"Couldn't find the template!");
}
	
sub enable {
	my $self = shift;
	my $itemId = $self->{query}->param('itemId');

	my $I = items->new($self->{cache},$self->{dbh},$self->{user}{user}{id});
	unless ($I->{allItems}{$itemId}) {
		return $self->generateResponse('fail','',"This isn't your item!");
	}

	if ($I->{allItems}{$itemId}->{enabled}) {
		$I->disableItem($itemId);
	} else {
		$I->enableItem($itemId);
	}
	my $data = map {qq|<item id="$_" enabled="$I->{allItems}{$_}->{enabled}"/>|} keys %{$I->{allItems}};
	return $self->generateResponse('ok','handleEnableItem',$data);
}

sub clone {
	my $self = shift;
	my $itemId = $self->{query}->param('itemId');

	my $I = items->new($self->{cache},$self->{dbh},$self->{user}{user}{id});
warn "CLONING $itemId";
	unless ($I->{allItems}{$itemId}) {
		return $self->generateResponse('fail','',"This isn't your item!");
	}

	# check for points
	if ($self->{user}{user}{popularity} < 3) {
	#	return $self->generateResponse('fail','',"You don't have enough points!");
	}

	# clone the item
	my $newId = $I->clone($itemId);

	# give item
	$I->take($self->{dbh}->selectrow_hashref("SELECT * FROM user_items WHERE id = ?",undef,$newId));

	# spend points
	my $points = points->new(dbh => $self->{dbh}, cache => $self->{cache});
	$points->storeTransaction({
		userid 	=> $self->{user}{user}{id},
		points	=> -3,
		type	=> 'item',
		desc	=> "Cloned item $I->{allItems}{$itemId}->{name}",
	});

	return $self->generateResponse('ok','handleCloneItem',qq|<id>$newId</id><oldid>$itemId</oldid>|);
}

sub toss {
	my $self = shift;
	my $itemId = $self->{query}->param('itemId');

	my $I = items->new($self->{cache}, $self->{dbh},$self->{user}{user}{id});
	unless ($I->{allItems}{$itemId}) {
		return $self->generateResponse('fail','',"This isn't your item!");
	}

	$self->{dbh}->do("DELETE FROM user_items WHERE id = ?",undef,$itemId);
	$self->{dbh}->do("DELETE FROM user_item_info WHERE itemId = ?",undef,$itemId);
	delete $I->{allItems}{$itemId};
	delete $I->{pocketItems}{$itemId};
	delete $I->{drawerItems}{$itemId};
	$I->save();

	warn $self->generateResponse('ok','handleTossItem',qq|<itemId>$itemId</itemId>|);
	return $self->generateResponse('ok','handleTossItem',qq|<itemId>$itemId</itemId>|);
}

sub purchase {
	my $self = shift;

	my $itemId = $self->{query}->param('itemId');
	my $points = int($self->{query}->param('points')) || 0;
	my $ownerId = $self->{query}->param('ownerId');

	# make sure the giver has the item
	my $giver = items->new($self->{cache}, $self->{dbh}, $ownerId);
warn "PURCHASE $itemId FROM $ownerId BY $self->{user}{user}{id} FOR $points";
	unless ($giver->{allItems}{$itemId}) {
		return $self->generateResponse('fail','',"Item owner information mismatch!");
	}
	# and make sure they are purchasing for the correct amount
	my @info = $giver->itemInfo($itemId);
	# get rid of the 1|| to enable real purchasing again
	unless (1 || $info[0] == $points) {
		warn $self->generateResponse('fail','',"Item point information mismatch!");
		return $self->generateResponse('fail','',"Item point information mismatch!");
	}
	# check purchaser's point balance
	if ($points > $self->{user}{user}{popularity}) {
		warn "$self->{user}{user}{id} purchasing item $itemId for $points points. point balance insufficient";
		#return $self->generateResponse('fail','',"You don't have enough points!");
	}

	warn "$self->{user}{user}{id} purchasing item $itemId for $points points.";

	# copy the item
	my $newId = $giver->clone($itemId);


	# give the item to the purchaser
	$giver->giveItem($self->{user}{user}{id},$newId);


	# deduct points
	my $PTS = points->new(dbh => $self->{dbh}, cache => $self->{cache});
	$PTS->storeTransaction({
		userid	=> $self->{user}{user}{id},
		points	=> -1 * $points,
		type	=> 'item',
		desc	=> "Purchased item ".$giver->{allItems}{$itemId}->{name}." (# $itemId)",
	});

	return $self->generateResponse('ok','handlePurchaseItem',qq|<itemId>$newId</itemId>|);
}

sub dashboardPosition {
	my $self = shift;
	my $position = $self->{query}->param('position');
	my $itemId = $self->{query}->param('itemId');

	my $items = items->new($self->{cache}, $self->{dbh}, $self->{user}{user}{id});
	unless ($items->{allItems}{$itemId}) {
#warn "NOT MY ITEM: item $itemId, user $self->{user}{user}{id}";
		return $self->generateResponse('fail','',"This isn't your item!");
	}
	if ($position eq 'theme' && $items->{allItems}{$itemId}{name} !~ /theme/) {
#warn "NOT A THEME";
		return $self->generateResponse('fail','',"This isn't a theme item!");
	}

#warn "SET item$position TO $itemId";
	$items->enableItem($itemId);
	$items->setdashboard($position,$itemId);
	
	return $self->generateResponse('ok','','ok');
}

sub storeMore {
	my $self = shift;
	my $type = $self->{query}->param('type');
	my $offset = $self->{query}->param('offset') || 0;

	my $sth;
	my $cnt;
	if ($type eq 'popular') {
		$sth = $self->{dbh}->prepare("SELECT description,COUNT(*) FROM point_transaction WHERE type='item' AND description LIKE 'Purchase%' GROUP BY 1 ORDER BY 2 DESC LIMIT $offset,30");
		$cnt = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM point_transaction WHERE type='item' AND description LIKE 'Purchase%'");
	} elsif ($type eq 'recent') {
		$sth = $self->{dbh}->prepare("SELECT ui.id,0 FROM user_items ui LEFT JOIN user_item_info uii ON uii.itemId = ui.id  ORDER BY createDate DESC LIMIT $offset,30");
		$cnt = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM user_items ui LEFT JOIN user_item_info uii ON uii.itemId = ui.id WHERE points > 0");
	} else {
		return qq|<a href="#" onclick="seeall();return false;">Return to main display</a></span>|;
	}

	$sth->execute;
	my ($id,$count);
	$sth->bind_columns(\$id,\$count);
	my $isth = $self->{dbh}->prepare("SELECT * FROM user_items WHERE id = ?");
	while ($sth->fetchrow_arrayref) {
		$id =~ s/\D+//g;
		$isth->execute($id);
		if ($isth->rows) {
			push @{$self->{user}{itemlist}}, {item => $isth->fetchrow_hashref};
		}
	}
	if (defined $self->{user}{itemlist} && scalar(@{$self->{user}{itemlist}}) % 30 != 0) {
		for (1 .. 30-(scalar(@{$self->{user}{itemlist}}) % 30)) {
			push @{$self->{user}{blanks}}, {};
		}
	} elsif (!defined $self->{user}{itemlist}) {
		for (1 .. 30) {
			push @{$self->{user}{blanks}}, {};
		}
	}

	$self->{user}{items}{type} = $type;
	if ($cnt > 30 && $offset + 30 <= $cnt) {
		$self->{user}{items}{next} = $offset+30;
	}
	if ($offset >= 30) {
		$self->{user}{items}{prev} = $offset-30;
	}
warn "OFFSET $offset, NEXT $self->{user}{items}{next}, PREV $self->{user}{items}{prev}";

	return processTemplate($self->{user},"items/storeMore.html",1);
}

sub pocket {
	my $self = shift;
	my $itemId = $self->{query}->param('itemId');

	my $I = new items($self->{cache},$self->{dbh},$self->{user}{user}{id});

	$I->pickItem($itemId);

	return $self->generateResponse('ok','',"<dat>$itemId</dat>");
}

sub store {
	my $self = shift;
	my $itemId = $self->{query}->param('itemId');

	my $I = new items($self->{cache},$self->{dbh},$self->{user}{user}{id});
	my $dash = $I->getdashboard;
	for (0..7) {
		if ($dash->{"item$_"} == $itemId) {
			$I->disableItem($itemId);
			$I->setdashboard($_,0);
			last;
		}
	}
	$I->save();
	
	return $self->generateResponse('ok','',"<dat>$itemId</dat>");
}


1;
