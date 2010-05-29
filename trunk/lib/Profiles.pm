package Profiles;
use strict;
 
use lib qw(../lib lib .);
use Data::Dumper;
use Email::Valid;
use DBI qw(:sql_types);
use Socket;
use FileHandle;
use Digest::MD5 qw(md5_hex);
use Digest::SHA1 qw(sha1_hex);
use HTML::Detoxifier qw(detoxify);
use Apache2::RequestRec;
use Apache2::Const qw(OK REDIRECT);
use CGI;
use CGI::Cookie;

use Cache;
use template2;
use tags;
use Users;
use util;
use CONFIG;


sub new {
	my $class = shift;
	my %args = @_;

	my $self = {
		dbh 	=> undef,
		req		=> $args{request} || undef,
		cache 	=> $args{cache} || new Cache,
		user 	=> (),
	};

	bless $self, ref($class) || $class;
	if (defined $args{query}) {
		$self->{query} = $args{query};
	} else {
		$self->{query} = CGI->new($self->{req});
	}

	return $self->init($args{dbh});
}

sub ErrorOut {
	my $self = shift;
	my $msg = shift;

	print header();

    print processTemplate($self,'errorout.html');
    exit(0);
}


sub init {
	my $self = shift;
	my $dbh = shift;

	if (defined $dbh && $dbh->ping) {
		$self->{dbh} = $dbh;
	} else {
		my $datasource = "DBI:mysql:$dbName:$dbServer";
		$self->{dbh} = DBI->connect($datasource, $dbUser,$dbPass) ||  $self->ErrorOut("Uh oh!  We're having trouble connecting to the database. Please try again in a few moments.");
	}

	$self->{util} = util->new(dbh => $self->{dbh}, cache => $self->{cache});

	$self->{scriptName} = $ENV{SCRIPT_NAME};

	my %user;

	#my %c = Apache::Cookie->fetch;
	my %c;
	my $username = $self->{query}->cookie('username');
	my $password = $self->{query}->cookie('password');


    $user{global}{loginUrl} = '/login.pl';
	$self->{command} = $ENV{'PATH_INFO'};
	$user{command} = $ENV{'PATH_INFO'};
	$user{scriptName} = $ENV{'SCRIPT_NAME'};
	$user{system}{timestamp} = time;
    $user{global}{servername} = $ENV{'SERVER_NAME'};
        $user{global}{imgserver} = $imgserver;
		$user{global}{wwwserver} = $wwwserver;
		$user{global}{mapsapikey} = $ENV{'SERVER_NAME'} =~ /www/ 
				? ''  # http://www.consumating.com
			 	: ''; # http://consumating.com
		$user{global}{ajaxSearchApiKey} = $ENV{'SERVER_NAME'} =~ /www/
				? ''
				: '';
    my $cobrand = $ENV{'SERVER_NAME'};

    $cobrand =~ s/personals\.(\w+)\..*/$1/gsm;
    if ($cobrand eq "") {
        $cobrand = "uber";
    }
    $user{global}{cobrand} = $cobrand;

    $user{global}{sitename} = $sitename;


    # get a snippet of the most recent conversation post
    {   
		my $dat = $self->{cache}->get('justoverheard');
		my $T = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $dat->[3]);

		util::cleanHtml($dat->[1],'everything');
		$dat->[1] = util::shortenString($dat->[1],80);

		$user{overheard}{response} = $dat->[1];
		$user{overheard}{linkhandle} = $T->{profile}{linkhandle};
    }


	$self->{user} = \%user;
	if (my $user = $self->AuthenticateUser($username,$password)) {
		$self->{user}{user} = $user;
		if ($self->{user}{user}{id} > 0) {
			$self->{user}{system}{authenticated} = 1;
			if ($self->{req}) {
				return undef unless $self->verify($self->{user});
			} else {
				exit unless $self->verify($self->{user});
			}
		}
	} else {
		$self->{user}{user}{username} = "";
	} 

	$user{dbh} = $self->{dbh};
	$user{cache} = $self->{cache};



	# if this user came from a search query and we have a tag or tags that match, suggest this!
	if ($ENV{'HTTP_REFERER'} =~ m/q\=(.*)/gi) {
		my $query = $1;
		my $nothing;
		($query,$nothing) = split(/\&/,$query);
		$query =~ s/%20/ /gsm;
		$query =~ s/\+/ /gsm;

		my @match;
		foreach my $word (split(/\s+/,$query)) {
			$word = $self->{dbh}->quote($word);
			push(@match,"value=$word");
		}
		push(@match,"value=" . $self->{dbh}->quote($query));
		
		my $sql = "SELECT value,COUNT(tagRef.profileId) AS count FROM tag,tagRef WHERE tag.id=tagRef.tagId AND (" .  join(" OR ",@match) .") GROUP BY tag.id ORDER BY count DESC";
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute;
		my $count = 0;
		while (my $tag = $sth->fetchrow_hashref) {
			%{$user{searchtags}{$count++}{tag} } = %{$tag};
		}
		$sth->finish;

	}


	$self->{user} = \%user;

	$self->{user}{global}{random} = rand() * 21000;

	return $self;
}




sub verify {
	my $self = shift;
	my $user = shift;

	if ($user->{user}{id} !~ /\d+/) {
		return $self->forcelogin;
	}

	my %allowedScripts = qw(
		/myAccount.pl 1 
		/myAccount.pl/verifyEmail 1 
		/myAccount.pl/reVerify 1 
		/myAccount.pl/save 1 
		/myAccount.pl/password 1 
		/profiles/Feedback_Zombie/messages 1
		/profiles/feedback_zombie/messages 1
		/messages.pl 1
		/messages.pl/inbox 1
		/messages.pl/sendMessage 1
		/messages.pl/sent 1
		/messages.csm 1
		/messages.csm/inbox 1
		/messages.csm/sendMessage 1
		/messages.csm/sent 1
		/login.pl/logout 1
		/register.pl 1
		/register.pl/thanks 1
		/tagPrefs.pl 1
		/about/help/index.pl 1
		/index.csm 1
	);

	if ($user->{user}{status} == -2) {
		# this user is deleted
		warn "USER IS DELETED";
		delete $self->{user}{user};
		delete $self->{user}{system};
		print $self->Header($self->{req});
		print template2::processTemplate($self->{user},'user_deleted.html');
		return 0;
	}

	if (length $user->{user}{authkey} > 0 && !$allowedScripts{$self->{scriptName}.$self->{command}}) {
		if ($self->{req}) {
			print template2::processTemplate($self->{user},'myAccount.verifyEmail.html');
			return OK;
		} else {
			print $self->Header($self->{req});
			print template2::processTemplate($self->{user},'myAccount.verifyEmail.html');
			return 0;
		}
	} elsif ($user->{user}{status} == -1  && !$allowedScripts{$self->{scriptName}.$self->{command}}) {
		# this user is in timeout
		print $self->Header($self->{req});
		print template2::processTemplate($self->{user},'user_on_timeout.html');
		return 0;
	} elsif ($user->{user}{status} == 0) {
		# this user is on pause, log them out.
		warn "this user is on pause, log them out.";
		my $usercookie = $self->{query}->cookie(-name=>'username',-value=>'',-domain=>'.consumating.com');
		my $passcookie = $self->{query}->cookie(-name=>'password',-value=>'',-domain=>'.consumating.com');
		print $self->{query}->redirect(-uri=>"/login.pl",-cookie=>[$usercookie,$passcookie]);
	}

	return 1;
}

sub forcelogin {
	my $self = shift;

	my $cookie = CGI::Cookie->new(
		-name 	=> 'redirect',
		-value	=> $self->{scriptName} . $self->{path_info} . '?' . $self->{query_string},
		-path	=> '/',
	);
	print $self->{query}->redirect(-url => '/', -cookie => [$cookie]);
	exit;
}

sub Header {
	my $self = shift;
	my $req = shift;

	if ($req) {
		$req->headers_out->add('Cache-Control' => 'no-cache, must-revalidate');
		$req->headers_out->add('Pragma' => 'no-cache');
		return;
	} else {
warn "PL HEADER";
		print "Cache-Control: no-cache, must-revalidate\n";
		print "Pragma: no-cache\n";
		return "Content-type: text/html\n\n";
	}
}

sub process {
	my $self = shift;

	return template2::processTemplate($self->{user},@_);
}

sub AuthenticateUser {
	my $self = shift;
	my ($username,$password) = @_;

	my %user;

	my $User;

	if (my $authenHash = $self->{query}->param('authenHash')) {
		my $userId = $self->{query}->param('actingUser');
#warn "TRY $userId, $authenHash";
		$User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, userId => $userId) or warn "Failed to load user object";
		return 0 unless ($User);

		my $hash = sha1_hex($User->{profile}{username}.'apple$#%pudding!*$^cheesecake');
		return 0 unless $hash eq $authenHash;

		$username = $User->{profile}{username};
		$password = md5_hex('csm21000'.$User->{profile}{password});
	} elsif (!$username) {
		return 0;
	} else {
		$User = Users->new(dbh => $self->{dbh}, cache => $self->{cache}, username => $username) or warn "Failed to load user object";
	}

	if ($User && md5_hex('csm21000'.$User->{profile}->{password}) eq $password) {
	
		my $userHash = $User->{profile};

		%{$user{user}} = %{$userHash};

		# load unread msg count
		my $sql = "SELECT COUNT(1) FROM messages m inner join users u on u.id=m.fromid WHERE u.status != -2 AND toId=$user{user}{id} AND isread=0";
		my $stx = $self->{dbh}->prepare($sql);
		$stx->execute;
		$user{user}{msgcount} = $stx->fetchrow;
		$stx->finish;

		my $rank = $User->rank;
		$user{user}{rank} = $rank->[0];
		$user{user}{rankword} = $rank->[1];

		return $user{user};

	} else {
		return 0;
	}

}

1;
