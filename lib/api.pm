package api;

use strict;
 
use Data::Dumper;
use lib qw(. ../lib);
use util;
use Cache;

our %public = qw(
	ticker_getThumbs 1
	ticker_getTags 1
);

sub new {
	my ($class,%args) = @_;
	
	my $self = {%args};
	$self->{cache} ||= new Cache;
	$self->{util} = new util(dbh => $self->{dbh},cache => $self->{cache});

	bless $self, ref($class) || $class;

	return $self;
}




sub buildProfile {
	my ($self,$sth) = shift;
	my $data;
	while (my $profile = $sth->fetchrow_hashref) {
		$profile->{linkhandle} = util::linkify($profile->{handle});
		$data .= $self->hashToXML('profile',$profile);
	}

	return $data;
}

sub userLogin {
	my $self = shift;
	my $username = $self->{query}->param('username');
	my $password = $self->{query}->param('password');
	my $sth = $self->{dbh}->prepare("SELECT id FROM users u WHERE u.status != -2 AND username=? AND password=?");
	$sth->execute($username,$password);
	my $userId = $sth->fetchrow if ($sth->rows);
	$sth->finish;
	unless ($userId) {
		print "Cache-Control: no-cache, must-revalidate\n";
		print "Pragma: no-cache\n";
		print "Content-type: text/xml\n\n";
		print $self->generateResponse('fail','','') unless $userId;
		exit;
	}

	return $userId;
}


sub hashToXML {
	my $self = shift;
	my ($type,$hash) = @_;
	my $xml = '';
	foreach my $key (keys %{$hash}) {
		next if ($key eq 'password' || $key eq 'username' || $key eq 'lastname');
		$xml .= "<$key>" . $self->protectXML($hash->{$key}) . "</$key>\n";
	}

	return qq|<$type>
					$xml
			</$type>|;
}






sub generateResponse {
	my $self = shift;
	my ($ok,$function,$data) = @_;

	if ($ok eq "ok") {
		my $rsp = qq|<rsp stat="ok" version="1.0">
						<handler>$function</handler>
								$data
				</rsp>|;

		return $rsp;
	} elsif ($ok eq "fail") {
		return qq|<rsp stat="fail">
						<error msg="$data" />
				 </rsp>|;
	}
}

sub protectXML {
	my $self = shift;
	my ($str) = @_;

	my @c = split //,$str;
	for (@c) {
		next unless ord($_) > 0x7F;
		$_ = '&#'.ord($_).';';
	}
	$str=join'',@c;
	if ($str =~ /</ || $str =~ />/ || $str =~ /&/) {
			$str = "<![CDATA[$str]]>";
	}
	return $str;
}

sub openUser {
	my $self = shift;
	my $uid = shift;

	return Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $uid);
}

1;
