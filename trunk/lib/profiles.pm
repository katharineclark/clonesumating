package profiles;
 
use Data::Dumper;
use Email::Valid;
use Exporter;
use DBI;
use Socket;
use CGI;
use FileHandle;
use Image::Magick;
use Digest::MD5 qw(md5_hex);
use Cache;
use template;
use tags;
use Users;
use HTML::Detoxifier qw(detoxify);
use CONFIG;

@ISA    = qw(Exporter);
use vars qw($q %user $dbh);
@EXPORT = qw(OpenDB Redirect readFile Finish $dbh $q %user $memcache $GlobalTagRef $command $scriptName $memcache Header AuthenticateUser ErrorOut  verify linkify wordize countrySelect validateUser validateProfile encrypt decrypt getHandle cleanHtml timesince);


our $memcache = new Cache; #::Memcached { 'servers' => ['127.0.0.1:11211'], 'debug' => 0, 'compress_threshold' => 10_000, };
our $handleLookupSTH;

our @encryption_key = qw(a 4 b N c 8 d A e r f l g 6 h t i o j c k h l V m P n f o k p U q G r x s b t F u 5 v u w X x W y p z y A 1 B g C q D L E a F v G k H 3 I n J Q K R L E M e N 9 O S P z Q 2 R m S 0 T D U w V i W M X j Y I Z O 0 T 1 s 2 C 3 Y 4 7 5 d 6 B 7 H 8 Z 9 J ! / _ ! / _);
our %encryption_codex = (
    in => {@encryption_key},
);
sub _remap {
    my $str = shift;
    my @c = split //,$str;
    for (@c) {
        $_ = $encryption_codex{'in'}{$_};
    }
    return join '',@c;
}
sub encrypt {
    my $str = shift;
    $handle = _remap($str);
    my $t = time();
    my $f = join '', @c;
    return $t.'_'.md5_hex('csm17'.$t.$handle);
}
sub decrypt {
    my $str = shift;
    my $t = substr($str,0,10);
    my $handle = _remap(+shift);
	my $test = $t.'_'.md5_hex('csm17'.$t.$handle);
    return $str eq $test;
}
$datasource = "DBI:mysql:$dbName:$dbServer";


$command = $ENV{'PATH_INFO'};
$scriptName = $ENV{'SCRIPT_NAME'};

$loginUrl = "/login.pl";



sub timesince {
        my ($minutes) = @_;
        if ($minutes > 60) {

                $hours = $minutes / 60;                $minutes = $minutes % 60;
                if ($hours > 24) {                        $days = $hours / 24;
                        $hours = $hours % 24;
                        $str = int($days) . " day";
                        if (int($days) != 1) {
                                $str.="s";
                        }                } else {
                        $str =int($hours) . " hour";
                        if (int($hours) != 1) {
                                $str.="s";
                        }
                }

        } else {

                $str = int($minutes) . " minute";
                        if (int($minutes) != 1) {                                $str.="s";
                        }
        }
        return $str;
}

sub linkify {
	my ($word) = @_;
	$word =~ s/_/_us_/g;
	$word =~ s/\s/_/g;
	$word =~ s/&/_amp_/g;
	$word =~ s/;/_sc_/g;
	$word =~ s/#/_lb_/g;
	$word =~ s/\//_fs_/g;
	$word =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
	return $word;
}

sub verify {
	my ($user) = @_;
	if ($user->{user}{id} !~ /\d+/) {
		forcelogin();	
		return 0;
	}

	my %allowedScripts = qw(
		/myAccount.pl/verifyEmail 1 
		/profiles/Feedback_Zombie/messages 1
		/messages.pl/inbox 1
		/messages.pl/sendMessage 1
		/login.pl/logout 1
		/register.pl/thanks 1
		/tagPrefs.pl 1
	);
	if (length $user->{user}{authkey} && !$allowedScripts{$scriptName.$command}) {
		print $q->header;
		print processTemplate(\%user,'myAccount.verifyEmail.html');
		exit;
	}
	return 1;
}

sub forcelogin() {

              my $redirect = $q->cookie(-name=>'redirect',-value=>$ENV{'SCRIPT_NAME'} . $ENV{'PATH_INFO'} . "?" . $ENV{'QUERY_STRING'});

	
		print $q->redirect(-uri=>"$loginUrl",-cookie=>[$redirect]);


}

sub OpenDB() {

    $dbh = DBI->connect($datasource, $dbUser, $dbPass) ||  ErrorOut("Uh oh!  We're having trouble connecting to the database. Please try again in a few moments.");

    return( $dbh );
};


sub countrySelect {
	my ($dbh,$mycountry) = @_;


	my ($sth,$c,$res) = "";

	$sth = $dbh->prepare("SELECT iso,printable_name FROM country ORDER BY printable_name");
	$sth->execute;
	while ($c = $sth->fetchrow_hashref) {

		if ($c->{iso} eq $mycountry) {
			$res .= qq|<option value="$$c{iso}" selected>$$c{printable_name}</option>\n|;
		} else {
                        $res .= qq|<option value="$$c{iso}">$$c{printable_name}</option>\n|;
                }

	}

	return $res;

}
			
	



sub AuthenticateUser {

	my ($dbh,$username,$password) = @_;

	my %user;

	if (!$username) {
		return 0;
	}

	
	my $User = Users->new(dbh => $dbh, cache => $memcache, username => $username);


	if ($User && md5_hex('csm21000'.$User->{profile}->{password}) eq $password) {
		$userHash = $User->{profile};
#		if ($userHash->{lastActive} lt '2006-01-31 17:25:00') {
#			$dbh->do("UPDATE users SET lastActive = NOW() WHERE id = ?",undef,$user{user}{id});
#			print $q->redirect(-uri => 'http://www.consumating.com/tagPrefs.pl');
#			exit;
#		}

		%{$user{user}} = %{$userHash};

		# load unread msg count
		$sql = "SELECT COUNT(1) FROM messages WHERE toId=$user{user}{id} AND isread=0;";
		$stx = $dbh->prepare($sql);
		$stx->execute;
		$user{user}{msgcount} = $stx->fetchrow;
		$stx->finish;

		my $rank = $User->rank;
		$user{user}{rank} = $rank->[0];
		$user{user}{rankword} = $rank->[1];


		return \%user;

	} else {
		return 0;
	}

}

sub Redirect {

   my ($url) = @_;
        print "Status: 302 Moved Temporarily\n";
        print "Location: $url\n\n";
	exit;

}


sub readFile {

	my ($filename) = @_;

	open(IN,$filename);
	my @IN = <IN>;
	close(IN);
	my $results = join("",@IN);

	return($results);
};



sub Header {

print "Cache-Control: no-cache, must-revalidate\n";
print "Pragma: no-cache\n";
	return "Content-type: text/html\n\n";
}

sub ErrorOut {

	my ($msg) = @_;

	$dbh->disconnect();

	print Header();
	print qq|<center>
		<a href="/"><img src="/img/consumating.gif" border=0></a><br />
		<h2>$msg</h2>
		|;

	exit;	

}

sub validateUser {
	# check user table values
	my %form = map {$_ => $q->param($_)||''}qw(firstName lastName username password sex year month day optout);
	$form{birthDate} = join '-',@form{qw(year month day)};
	$form{optout} ||= 'N';

	if ($q->param('country') eq 'US') {
		$form{$_} = $q->param($_) for (qw(city state zipcode));
		
	} else {
		$form{city} = $q->param('foreigncity');
		delete $form{zipcode};
		delete $form{state};
	}
	my @err = grep {!length $form{$_}} keys %form;

	if (length $form{zipcode} && !($form{zipcode} =~ /\d{5}/)) {
		push @err, 'zipcode';
	}
	if (length $form{state} > 2) {
		push @err, 'state';
	}


	my $sth = $dbh->prepare("SELECT COUNT(*) FROM users WHERE username = ?");
	my $badusername = undef;
	$sth->execute($form{username});
	if ($sth->fetchrow > 0) {
		$badusername = $form{username};
	}
	$sth->finish;

	if (!$badusername && length $form{username} && !Email::Valid->address($form{username})) {
		$badusername = $form{username};
	}

	return ($badusername,@err);
}

sub validateProfile {
	# check profile table values
	my %form = map {$_ => $q->param($_)||''}qw(handle tagline relationshipStatus);
	for (qw(wantsMen wantsWomen relationship1 relationship2 relationship3 relationship4 relationship5)) {
		$form{$_} = $q->param($_) || 0;
	}

	my @err = grep{!length $form{$_}} keys %form;

	my $sth = $dbh->prepare("SELECT COUNT(*) FROM profiles WHERE handle = ?");
	$sth->execute($form{handle});
	my $badhandle = undef;
	if ($sth->fetchrow > 0) {
		$badhandle = $form{handle};
	}
	$sth->finish;

	return ($badhandle,@err);

}

sub getHandle {
	my $userId = shift;

	my $handle = $memcache->get("handleById$userId");
	if (!$handle || $handle eq '<i>missing profile</i>') {
		unless ($handleLookupSTH) {
			$handleLookupSTH = $dbh->prepare("SELECT handle FROM profiles WHERE userId = ?");
		}
		$handleLookupSTH->execute($userId);
		$handle = $handleLookupSTH->fetchrow || '<i>missing profile</i>';
		$memcache->set("handleById$userId",$handle);
	}
	return $handle;
}

sub cleanHtml(\$;@) {
	my $str = shift;

	$$str = detoxify($$str, disallow => [qw(dynamic document comments images annoying forms )]);
}

# this is the stuff that happens before everythign else.

$dbh = OpenDB();
if (!$dbh) { ErrorOut("Connection to database failed."); }
$q = new CGI;
my $username = $q->cookie('username');
my $password = $q->cookie('password');


$user{system}{timestamp} = time;

if (!$ENV{'SCRIPT_NAME'}) {
	return 1;
}

	if ($user = AuthenticateUser($dbh,$username,$password)) {
	%user = %{$user};
	if ($user{user}{id} > 0) {
		$user{system}{authenticated} = 1;
		exit unless verify(\%user);
	}
} else {
	$user{user}{username} = "";
} 


# session stuff

#if ($user{user}{lastActive} lt '2006-01-31 17:07:00') {
#	$q->redirect(-uri => 'http://www.consumating.com/tagPrefs.pl');
#}
if ($q->cookie('session')) {

	$s = $q->cookie('session');
	$uid = $user{user}{id} || "NULL";
	#$dbh->do("UPDATE userSessions SET userId=$uid,lastAction=NOW(),pageCount=pageCount+1 Where id=$s");
	$user{global}{session} = $s;

} elsif (0) {
	
	$uid = $user{user}{id} || "NULL";
	$ip = $dbh->quote($ENV{'REMOTE_ADDR'});
	$fl = $dbh->quote($ENV{'SCRIPT_NAME'});
	$ua = $dbh->quote($ENV{'HTTP_USER_AGENT'});
	#$sql = "INSERT INTO userSessions (userId,startDate,lastAction,firstLoad,ip_address,user_agent) values ($uid,NOW(),NOW(),$fl,$ip,$ua);";
	$sth = $dbh->prepare($sql);
	$sth->execute;
	$s = $sth->{mysql_insertid};
	$sth->finish;
	
	$user{global}{session} = $s;

}



# force data cleanup
if ($ENV{'SCRIPT_NAME'} !~ /myAccount/) {
	if ($user{user}{id} ne "") {
		if (   (($user{user}{zipcode} eq "") && ($user{user}{country} eq "USA"))  || ($user{user}{country} eq "") || $user{user}{localQuery} eq "") {

			Redirect("/myAccount.pl?msg=Due to a recent upgrade of the system, we need more (or clearer) information about where you are located.  Please update your settings below!");

		}
	}
}


# if this user came from a search query and we have a tag or tags that match, suggest this!
if ($ENV{'HTTP_REFERER'} =~ m/q\=(.*)/gi) {
	$query = $1;
	($query,$nothing) = split(/\&/,$query);
	$query =~ s/%20/ /gsm;
	$query =~ s/\+/ /gsm;

	foreach $word (split(/\s+/,$query)) {
		$word= $dbh->quote($word);
		push(@match,"value=$word");
	}
	push(@match,"value=" . $dbh->quote($query));
	
	$sql = "SELECT value,COUNT(tagRef.profileId) AS count FROM tag,tagRef WHERE tag.id=tagRef.tagId AND (" .  join(" OR ",@match) .") GROUP BY tag.id ORDER BY count DESC";
	$sth = $dbh->prepare($sql);
	$sth->execute;
	$count = 0;
	while ($tag = $sth->fetchrow_hashref) {
		%{$user{searchtags}{$count++}{tag} } = %{$tag};
	}
	$sth->finish;

}


foreach ($q->param) {
	$user{form}{$_} = $q->param($_);
}

$user{global}{loginUrl} = $loginUrl;
$user{global}{scriptName} = $scriptName;
$user{global}{servername} = $ENV{'SERVER_NAME'};
    if ($ENV{'SERVER_NAME'} =~ /dev/) {        $user{global}{dev} =1;
        $user{global}{imgserver} = 'dev.consumating.com';
    } else {
        $user{global}{imgserver} = 'img.consumating.com';
    } 
$cobrand = $ENV{'SERVER_NAME'};

$cobrand =~ s/personals\.(\w+)\..*/$1/gsm;
if ($cobrand eq "") {
	$cobrand = "uber";
}
$user{global}{cobrand} = $cobrand;

$user{global}{sitename} = qq|Consumating|;


$GlobalTagRef = tags->new($memcache,$dbh);



1;
