package items;
use strict;
 
use Data::Dumper;
use POSIX qw(strftime);
use List::Util qw(first);
use File::Copy;

use lib qw(. lib);
use util;
use CONFIG;

our %user = %profilesmodperl::user;


my $useritemdir   = "$staticPath/img/items/user";
my $systemitemdir = "$staticPath/img/items/system";

my %unique_behaviors = (
	wallpaper 	=> 1,
	header		=> 1,
);

sub new {
	my $class = shift;
	my $memcache = shift;
	my $db = shift;
	my $userId = shift;

	my $self = {
		db => $db,
		cache => $memcache,
		userId => $userId,
		allItems	=> {},
		pocketItems => {},
		drawerItems => {},
		createdItems => {},
		util		=> util->new(dbh => $db, cache => $memcache),
	};
	bless $self, ref($class) || $class;

	$self->load();
	
	$self;
}
sub itemInfo {
	my $self = shift;
	my $itemId = shift;

	unless ($self->{infoSTH}) {
		$self->{infoSTH} = $self->{db}->prepare("SELECT points,behavior FROM user_item_info WHERE itemId = ?");
	}
	$self->{infoSTH}->execute($itemId);
	return $self->{infoSTH}->fetchrow;
}
sub itemBehavior {
	my $self = shift;
	my $itemId = shift;

	unless ($self->{behaviorSTH}) {
		$self->{behaviorSTH} = $self->{db}->prepare("SELECT behavior FROM user_item_info WHERE itemId = ?");
	}
	$self->{behaviorSTH}->execute($itemId);
	return $self->{behaviorSTH}->fetchrow;
}

sub enableItem {
	my $self = shift;
	my $itemId = shift;

	my $item = $self->{allItems}{$itemId};
	$item->{enabled} = 1;
	$self->{db}->do("UPDATE user_items SET enabled = 1,lastUpdate = NOW() WHERE id = ?",undef,$itemId) or warn "CANNOT UPDATE ITEM (enableItem) $itemId: ".$self->{db}->errstr;
	$self->{"$item->{location}Items"}{$itemId}->{enabled} = 1;
	$self->save();

	my ($bh,undef) = split /,/,$self->itemBehavior($itemId);

	# if this behavior can only be enabled once per profile,
	# disable other items of the same behavior
	if ($unique_behaviors{$bh}) {
		for my $id (keys %{$self->{allItems}}) {
			next if $id == $itemId;
			my ($ibh,undef) = split /,/,$self->itemBehavior($id);
			if ($ibh eq $bh) {
warn "DISABLE $id";
				$self->disableItem($id);
			}
		}
	}
}
sub disableItem {
	my $self = shift;
	my $itemId = shift;

	my $item = $self->{allItems}{$itemId};
	$item->{enabled} = 1;
	$self->{db}->do("UPDATE user_items SET enabled = 0,lastUpdate = NOW() WHERE id = $itemId");
	$self->{"$item->{location}Items"}{$itemId}->{enabled} = 0;
	$self->save();
}

sub load {
	my $self = shift;

	$self->{ownedItems} = $self->{cache}->get("ownedItems_".$self->{userId});
	$self->{createdItems} = $self->{cache}->get("createdItems_".$self->{userId});
	if (1 || !scalar keys %{$self->{allItems}} || !scalar keys %{$self->{pocketItems}} || !scalar keys %{$self->{drawerItems}}) {
		my $sth = $self->{db}->prepare("SELECT * FROM user_items WHERE ownerId = ?");
		$sth->execute($self->{userId});
		while (my $i = $sth->fetchrow_hashref) {
			for (qw(owner creator previousOwner)) {
				($i->{$_},$i->{"link$_"}) = $self->{util}->getHandle($i->{$_.'Id'});
				if (index($i->{$_},'missing') > -1) {
					$i->{$_} = 'Feedback Zombie';
					$i->{"link$_"} = 'Feedback_Zombie';
				}
			}
			$self->{allItems}{$i->{id}} = $i;
			if ($i->{location} eq "pocket") {
				#warn "pocket item";
				$self->{pocketItems}{$i->{id}} = $i;
			} elsif ($i->{location} eq "drawer") {
				#warn "Drawer item";
				$self->{drawerItems}{$i->{id}} = $i;
			}
		}
		$sth->finish;
		$self->save();
	}
	$self;
}

sub save {
	my $self = shift;
	$self->{cache}->set("pocketItems_".$self->{userId},$self->{pocketItems},0);
	$self->{cache}->set("createdItems_".$self->{userId},$self->{createdItems},0);
	$self->{cache}->set("drawerItems_".$self->{userId},$self->{drawerItems},0);
}
	

sub giveItem {
	my $self = shift;
	my $recipient = shift;
	my $itemId = shift;

	my $R = items->new($self->{cache},$self->{db},$recipient);
	my $item = $self->give($itemId);

warn "ITEM? $item";
	return unless $item;

	$item->{previousOwnerId} = $self->{userId};
	for (qw(previousOwner owner)) {
		($item->{$_},$item->{"link$_"}) = $self->{util}->getHandle($item->{$_.'Id'});
	}

	$item->{lastGiveDate} = strftime("%F %H:%M:%S",localtime);

	my $dash = $self->getdashboard;
	for my $pos (1 .. 7) {
		if ($dash->{"item$pos"} == $itemId) {
			$self->setdashboard($pos,0);
			last;
		}
	}


	$R->take($item);
	$self->save();
	$R->save();

	my $location = $recipient == 0 ? 'gift' : 'drawer';

	my $sth = $self->{db}->prepare("UPDATE user_items SET ownerId = ?,previousOwnerId=?,location=?,lastGiveDate=?, lastUpdate = NOW() WHERE id = ?");
	$sth->execute($recipient,$self->{userId},$location,$item->{lastGiveDate},$itemId);
	$sth->finish;
}


sub pickItem {
        my $self = shift;
        my $itemId = shift;

        my $sth = $self->{db}->prepare("UPDATE user_items SET lastUpdate=NOW(), location=? WHERE id = ?");

        #my $R = items->new($self->{cache},$self->{db},$self->{userId});
        my $item = $self->pick($itemId);
        $self->pocket($item);
		if (scalar keys %{$self->{pocketItems}} > 6) {
			my @order = sort {$self->{pocketItems}{$a}{lastUpdate} cmp $self->{pocketItems}{$b}{lastUpdate} || $self->{pocketItems}{$a}{lastGiveDate} cmp $self->{pocketItems}{$b}{lastGiveDate}} keys %{$self->{pocketItems}};
			my $moveId = shift @order;
			my $toDrawer = $self->pick($moveId);
			$self->take($toDrawer);
			$sth->execute('drawer',$moveId);
		}

		my $dash = $self->getdashboard;
		for my $pos (1 .. 7) {
			if ($dash->{"item$pos"} == $itemId) {
				$self->setdashboard($pos,0);
				last;
			}
		}


        $self->save();
        #$R->save();
        $sth->execute('pocket',$itemId);
        $sth->finish;
}
sub pick {
        my $self = shift;
        my $itemId = shift;

        my $item = $self->{drawerItems}{$itemId};
        delete $self->{drawerItems}{itemId};

        return $item;
}
sub pocket {
        my $self = shift;
        my $item = shift;


        $self->{pocketItems}{$item->{id}} = $item;
        $self->save();
}


sub give {
	my $self = shift;
	my $itemId = shift;

	my $item = $self->{allItems}{$itemId} || $self->{pocketItems}{$itemId} || $self->{drawerItems}{$itemId};
warn "$self->{userId} == $item->{ownerId} give item $itemId? ".Dumper($item);

	return unless $self->{userId} == $item->{ownerId};

warn "Deleting item $itemId FROM giver $self->{userId}";
	delete $self->{pocketItems}{$itemId};
	delete $self->{drawerItems}{$itemId};
	delete $self->{allItems}{$itemId};

	
	return $item;
}

sub take {
	my $self = shift;
	my $item = shift;


	$self->{drawerItems}{$item->{id}} = $item;
	$self->save();
}

sub createdItems {
	my $self = shift;

	return sort {$b->{lastGiveDate} cmp $a->{lastGiveDate}} map {$self->{createdItems}{$_}} keys %{$self->{createdItems}};
}
sub pocketItems {
	my $self = shift;

	return sort {$b->{lastGiveDate} cmp $a->{lastGiveDate}} map {$self->{pocketItems}{$_}} keys %{$self->{pocketItems}};
}
sub drawerItems {
        my $self = shift;

        return sort {$b->{lastGiveDate} cmp $a->{lastGiveDate}} map {$self->{drawerItems}{$_}} keys %{$self->{drawerItems}};
}

sub checkItemPermission {
	my $self = shift;
	my $item = shift;

	return 1 if first {$_ eq $item} map {$self->{pocketItems}{$_}->{name}} keys %{$self->{pocketItems}};
	return 1 if first {$_ eq $item} map {$self->{drawerItems}{$_}->{name}} keys %{$self->{drawerItems}};
	return 0;
}

sub clone {
	my $self = shift;
	my $itemId = shift;

	$self->{db}->do("INSERT INTO user_items (name,description,ownerId,creatorId,type,location,createDate,enabled,lastUpdate) SELECT name,description,ownerId,creatorId,type,location,NOW(),0,NOW() FROM user_items WHERE id = ?",undef,$itemId);
	my $newId = $self->{db}->selectrow_array("SELECT last_insert_id()");

warn "CLONE NEW $newId";
	# copy the behavior
	my @info = $self->itemInfo($itemId);
	if (scalar @info) {
		if (index($info[1],'wallpaper') == 0) {
			$info[1] =~ s/(.+?),.*/$1,$newId/;
		}

		$self->{db}->do("INSERT INTO user_item_info (itemId,points,behavior) VALUES (?,?,?)",undef,$newId,@info) or warn "DB ERROR: ".$self->{db}->errstr;
	}

	my $type = $self->{db}->selectrow_array("SELECT type FROM user_items WHERE id = $newId");
warn "TYPE $type";
	if ($type eq 'user') {
		copy("$useritemdir/$itemId.gif","$useritemdir/$newId.gif");
	}

	# copy the data structure
	$self->{allItems}{$newId} = \%{$self->{allItems}{$itemId}};

	return $newId;
}

sub setdashboard {
	my $self = shift;
	my $position = shift;
	my $itemId = shift;

	my $dashboard = $self->getdashboard;

	if ($dashboard->{"item$position"} && $dashboard->{"item$position"} != $itemId) {
		# disable existing item
		$self->disableItem($dashboard->{"item$position"});
	}

	$dashboard->{"item$position"} = $itemId;
	$self->{db}->do("UPDATE user_dashboard SET item$position = $itemId WHERE userId = $self->{userId}");
	$self->{cache}->set("dashboard".$self->{userId},$dashboard);
	return $dashboard;
}

sub getdashboard {
	my $self = shift;

	my $dashboard = $self->{cache}->get("dashboard".$self->{userId});
	unless (0 && $dashboard) {
		my $sth = $self->{db}->prepare("SELECT * FROM user_dashboard WHERE userId = ?");
		$sth->execute($self->{userId});
		if ($sth->rows) {
			$dashboard = $sth->fetchrow_hashref;
		} else {
			$self->{db}->do("INSERT INTO user_dashboard (userId) values ($self->{userId})");
			$dashboard = {
				userId => $self->{userId},
				id => $self->{db}->selectrow_array("SELECT last_insert_id()"),
			};
		}
	}
	$self->{cache}->set("dashboard".$self->{userId},$dashboard);

	return $dashboard;
}

1;
