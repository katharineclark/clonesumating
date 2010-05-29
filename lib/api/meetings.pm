package api::meetings;

use strict;
 
use Data::Dumper;

use lib qw(lib ../lib ../../lib);
use api;
use Users;
use template2;
use CM_Tags;

our @ISA = qw(api);

our @fields = qw(name description tag street city state zipcode date approved);

sub save {
	my $self = shift;
	my $id;

# set unrequired parameters to blank if they aren't passed in
	foreach ('venue','street','city','state','zipcode','date') {
		if (!$self->{query}->param($_)) {
			$self->{query}->param($_,'');
		}
	}



	if ($self->{query}->param('id')) {
		my $sql = "UPDATE events SET name=?,description=?,tag=?,venue=?,street=?,city=?,state=?,zipcode=?,date=? WHERE id=? AND sponsorId=?";		
    	my $sth = $self->{dbh}->prepare($sql);
		$sth->execute($self->{query}->param('name'),$self->{query}->param('description'),$self->{query}->param('tag'),$self->{query}->param('venue'),$self->{query}->param('street'),$self->{query}->param('city'),$self->{query}->param('state'),$self->{query}->param('zipcode'),$self->{query}->param('date'),$self->{query}->param('id'),$self->{user}{user}{id});
		$sth->finish;
		$id = $self->{query}->param('id');
	} else {
		my $sql = "INSERT INTO events (name,description,tag,venue,street,city,state,zipcode,date,sponsorId) VALUES (?,?,?,?,?,?,?,?,?,?);";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($self->{query}->param('name'),$self->{query}->param('description'),$self->{query}->param('tag'),$self->{query}->param('venue'),$self->{query}->param('street'),$self->{query}->param('city'),$self->{query}->param('state'),$self->{query}->param('zipcode'),$self->{query}->param('date'),$self->{user}{user}{id});
        $id = $sth->{mysql_insertid};
		$sth->finish;
	
   		 $self->{dbh}->do("INSERT INTO profileTopic (userId,question,type,enabled) VALUES (?,?,'meeting',1)",undef,$id,$self->{query}->param('description'));
        my $tid = $self->{dbh}->selectrow_array("SELECT last_insert_id()");
   		 $self->{dbh}->do("INSERT INTO profiletopicwatch (userId,topicId,date) VALUES (?,?,NOW())",undef,$self->{user}{user}{id},$tid);

    	my $tid = CM_Tags::addTag($self->{dbh},$self->{query}->param('tag') . "_rsvp",$self->{user}{user}{id},9656);

	}

	my $data = "<event><id>$id</id></event>";
	return $self->generateResponse('ok','',$data);

}

sub add {
	my $self = shift;

	my %parms = map {$_ => $self->{query}->param($_) || ''} @fields;

	my $sql = "INSERT INTO events (sponsorId,city,date,description";
	if ($parms{enddate}) {
		$sql .= ",enddate";
	}
	$sql .= ") VALUES (?,?,?,?".($parms{enddate} ? ',?' : '').")";
	my $sth = $self->{dbh}->prepare($sql);

	if ($parms{enddate}) {
		$sth->execute($self->{user}{user}{id},(map{$parms{$_}}qw(city date description enddate)));
	} else {
		$sth->execute($self->{user}{user}{id},(map{$parms{$_}}qw(city date description)));
	}
	my $id = $self->{dbh}->selectrow_array("SELECT last_insert_id()");

	my $data = $self->{dbh}->selectrow_hashref("SELECT * FROM meetings WHERE id = (SELECT last_insert_id())");
	$data->{enddate} = template2::timeformat($data->{enddate}) if $data->{enddate};
	$data->{date} = template2::timeformat($data->{date}) if $data->{date};

	$self->{dbh}->do("INSERT INTO profileTopic (userId,question,type) VALUES (?,?,'meeting')",undef,$id,$parms{description});
	my $tid = $self->{dbh}->selectrow_array("SELECT last_insert_id()");
	$self->{dbh}->do("INSERT INTO profiletopicwatch (userId,topicId,date) VALUES (?,?,NOW())",undef,$self->{user}{user}{id},$tid);

	warn $self->generateResponse('ok','',$self->hashToXML('meeting',$data));
	return $self->generateResponse('ok','',$self->hashToXML('meeting',$data));
}

sub edit {
	my $self = shift;
	
	my $id = $self->{query}->param('id');
warn "GOT EDIT ID $id";
	my $meeting = $self->{dbh}->selectrow_hashref("SELECT * FROM events WHERE id = ?",undef,$id);
	if ($meeting->{sponsorId} != $self->{user}{user}{id}) {
		return $self->generateResponse('fail','','');
	}

	my %parms = map {$_ => length $self->{query}->param($_) ? $self->{query}->param($_) : ''} @fields;
	my %u;
	for (keys %parms) {
warn "PARM $_: $parms{$_} vs $meeting->{$_}";
		if (length $parms{$_} && $parms{$_} ne $meeting->{$_}) {
			$u{$_} = $parms{$_};
		}
	}
	if (scalar keys %u) {
		if ($id) {
			warn "UPDATE events SET ".(join',',map{"$_ = ?"}sort(keys %u))." WHERE id = ?".join('; ',(map{$u{$_}}sort(keys %u)),$id);
			$self->{dbh}->do("UPDATE events SET ".(join',',map{"$_ = ?"}sort(keys %u))." WHERE id = ?",undef,(map{$u{$_}}sort(keys %u)),$id);
		} else {
			delete $u{id};
			warn "INSERT INTO events (".join(',',sort keys %u).") VALUES (".('?' x scalar keys %u).") ;".join('; ',map{$u{$_}}sort keys %u);
			$self->{dbh}->do("INSERT INTO events (".join(',',sort keys %u).") VALUES (".('?' x scalar keys %u).")",undef,map{$u{$_}}sort keys %u);
		}
	}
	if ($parms{approved} == 1) {
		$self->{dbh}->do("INSERT INTO profileTopic (userId,question,type) VALUES (?,?,'meeting')",undef,$id,$u{city}||$meeting->{city});
		my $tid = $self->{dbh}->selectrow_array("SELECT last_insert_id()");
		$self->{dbh}->do("INSERT INTO profiletopicwatch (userId,topicId,date) VALUES (?,?,NOW())",undef,$meeting->{sponsorId},$tid);
	}
	return $self->generateResponse('ok','','');
}

sub rsvp {
	my $self = shift;
	my $tag = $self->{query}->param('tag');

	$tag = lc($tag.'_rsvp');

	my $tid = CM_Tags::addTag($self->{dbh},$tag,$self->{user}{user}{id},9656);
	
	return $tid 
		? $self->generateResponse('ok','',"<tag><id>$tid</id></tag>")
		: $self->generateResponse('fail','','Something went wrong!');
}

sub de_rsvp {
	my $self = shift;
	my $tag = $self->{query}->param('tag');

	# get tagId
	my $tid = $self->{dbh}->selectrow_array("SELECT id FROM tag WHERE value = ?",undef,lc($tag.'_rsvp'));
	if ($tid) {
		removeTag($self->{dbh},$tid,$self->{user}{user}{id});
		return $self->generateResponse('ok','','<msg>Tag removed</msg>');
	} else {
		return $self->generateResponse('fail','','No tag found.');
	}
}

sub cancel {
	my $self = shift;
	my $id = $self->{query}->param('id');

	my $cnt= $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM events WHERE id = ? AND sponsorId = $self->{user}{user}{id}",undef,$id);
	if ($cnt) {
		$self->{dbh}->do("UPDATE events SET approved=0 WHERE id = ?",undef,$id);
	}
	return $self->generateResponse('ok','','<ok>good</ok>');
}
	

1;
