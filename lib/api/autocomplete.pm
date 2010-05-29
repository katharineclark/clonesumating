package api::autocomplete;

use strict;
 
use Data::Dumper;

use lib qw(lib ../lib ../../lib);
use api;
use Users;
use util;

our @ISA = qw(api);

sub handle {
	my $self = shift;

	my $s = $self->{query}->param('s');
	my $n = $self->{query}->param('name');
	
	return if $s =~ /@/;

	my ($data,@words);
	@words = $self->{cache}->get("autocompletehandles_$s");
	if (!scalar @words || !defined($words[0]) || !length($words[0])) {
		my $sql = "SELECT handle FROM profiles WHERE handle LIKE '$s%' ORDER BY handle LIMIT 15";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		while (my $h = $sth->fetchrow) {
			$data .= "<li>$h</li>";
			push @words, $h;
		}
		$self->{cache}->set("autocompletehandles_$s",@words,16000);
	} else {
		for (@words) {
			if (index($_,$s) == 0) {
				$data .= "<li>$_</li>";
			}
		}
	}
	return $self->generateResponse('ok','',qq|<body><div id="$n"><ul>$data</ul></div></body>|);
}
sub tag {
	my $self = shift;

	my $text = $self->{query}->param('s');
	my $n = $self->{query}->param('name');

	my $w = $self->{cache}->get("autocompletetags_$text");
	my $data;
	if (!defined $w || ref($w) ne 'ARRAY' || !scalar @$w) {
		$w=[];
		$text =~ s/'/\\'/g;
		my $sth = $self->{dbh}->prepare("SELECT t.value,COUNT(*) FROM tag t, tagRef r WHERE r.tagId=t.id AND t.value LIKE '$text%' GROUP BY t.value ORDER BY 2 DESC LIMIT 10") or warn "db prep error: ".$self->{dbh}->errstr;
		$sth->execute or warn "db exec error: ".$self->{dbh}->errstr;
		while (my ($m,$cnt) = $sth->fetchrow) {
			$data .= "<li>$m</li>";
			push @$w, $m;
		}
		$sth->finish;
		$self->{cache}->set("autocompletetags_$text",$w);
	} else {
		for (@$w) {
			$data .= "<li>$_</li>" if index($_,$text) == 0;
		}
	}
	return $self->generateResponse('ok','',qq|<body><div id="$n"><ul>$data</ul></div></body>|);
}

1;
