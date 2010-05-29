package api::tags;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use CM_Tags;
use template;

our @ISA = qw(api);

sub getUsersByTag {
	my $self = shift;
	my @tags = tagSplit($self->{query}->param('tags'));
	my @tids;

	foreach (0 .. $#tags) {
		$tags[$_] = $self->{dbh}->quote($tags[$_]);
	}
	
	my $sql = "SELECT id FROM tag WHERE value IN (" . join(',',@tags) .");";
	warn $sql;
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	while (my $tid = $sth->fetchrow) {
		push(@tids,$tid);
	}
	$sth->finish;

	$sql = "SELECT profileId,count(tagRef.id) as tags from tagRef WHERE tagId IN (" . join(',',@tids) . ") GROUP BY profileId HAVING tags=" . scalar(@tids) . ";";
	warn $sql;
	$sth = $self->{dbh}->prepare($sql);
	$sth->execute;
	my $count = 0;
	while ($sth->fetchrow) {
		$count++;
	}
	$sth->finish;

	my $data = "<userCount>$count</userCount>";
	return $self->generateResponse('ok','handleGetUsersByTag',$data);


}

sub compare {
	my $self = shift;
	my @tags = tagSplit($self->{query}->param('tags'));
	my $sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM tagRef r, tag t WHERE r.tagId = t.id AND t.value=?");
	my %v;
	my $sum = 0;
	my $subcount = 0;
	my @results;
	for (@tags) {
		$_ = cleanTag($_);
		$sth->execute($_);
		$v{$_} = $sth->fetchrow || 0;
		$sum += $v{$_};
		push @results, $v{$_};
	}
	my %data;
	for (sort {$v{$b} <=> $v{$a}} keys %v) {
		$data{tags}{$subcount++}{tag} = {name => $_, value => $v{$_}, percent => sprintf("%.2f",($v{$_}/$sum)*100) };
	}

	$self->{dbh}->do("INSERT INTO tag_compare(tags,results,userId,date) VALUES (?,?,?,NOW())",undef,join(' ',@tags),join(' ',@results),$self->{user}{user}{id});

	my $data = processTemplate(\%data,'zeitgeist.tag.html',1);
	return $self->generateResponse('ok','handleCompareTags',"<compare><![CDATA[$data]]></compare>");
}

1;
