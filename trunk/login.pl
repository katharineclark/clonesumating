#!/usr/bin/perl

use lib "lib/";
 
use Digest::MD5 qw(md5_hex);
#use profiles;
use Profiles;
use template2;
use mail;

my ($dbh);


sub dispatch {

	my $P = Profiles->new(dbh=>$dbh);
	if ($P->{command} eq "") {
		showLogin($P);
	} elsif ($P->{command} eq "/authenticate") {
		authenticate($P);
	} elsif ($P->{command} eq "/logout") {
		logout($P);
	} elsif ($P->{command} eq "/forgotPassword") {
		forgotPassword($P);
	} elsif ($P->{command} eq "/sendPassword") {
		sendPassword($P);
	}	

}


sub showLogin {
	my ($P) = @_;
	print $P->Header();

		
        if ($user->{redirect} ||  $P->{query}->param('redirect') || $P->{query}->cookie('redirect')) {
            $redirect = $user->{redirect} || $P->{query}->param('redirect') || $P->{query}->cookie('redirect');
		}
        if ($redirect eq "") {
        	if ($ENV{'HTTP_REFERER'} =~ /consumating.com/) {
                $redirect = $ENV{'HTTP_REFERER'};
            }
        }
		if ($redirect =~ /login.pl/) {
			$redirect = "/";
		}
		$P->{user}{page}{msg} = $P->{query}->param('msg');
		$P->{user}{page}{redirect} = $redirect;
	print $P->{query}->param('mobile')
		? processTemplate($P->{user},'mobile/login.html',1)
		: processTemplate($P->{user},"login.html");
}


sub authenticate {
	my ($P) = @_;

	$user = $P->AuthenticateUser($P->{query}->param('username'),md5_hex('csm21000'.$P->{query}->param('password')));
	if ($user->{id}) {

		if ($user->{status} == 0) {
			# unpause them
			warn "UNPAUSE";
			$P->{dbh}->do("UPDATE users SET status=1 where id=$user->{id}");
			my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $user->{id}, force => 1);
		}

		$P->{dbh}->do("UPDATE users SET lastLogin=NOW() where id=$$user{id}");
		my $usercookie = $P->{query}->cookie(-name=>'username',-value=>$P->{query}->param('username'),-domain=>'.consumating.com');
		my $passcookie = $P->{query}->cookie(-name=>'password',-value=>md5_hex('csm21000'.$P->{query}->param('password')),-domain=>'.consumating.com');
		if($P->{query}->param('rememberme')) {
			$usercookie->expires('+10y');
			$passcookie->expires('+10y');
		} else {
            $usercookie->expires('+72h');
            $passcookie->expires('+72h');
		}

		if ($user->{redirect} || $P->{query}->param('redirect') || $P->{query}->cookie('redirect')) {
			$redirect = $user->{redirect} || $P->{query}->param('redirect') || $P->{query}->cookie('redirect');
			if ($redirect =~ /register/ || $redirect =~ /login/) {
				$redirect = "/";
			} 
			$redirectcookie = $P->{query}->cookie(-name=>'redirect',-value=>'',-domain=>'.consumating.com');
			print $P->{query}->redirect(-uri=>$redirect,-cookie=>[$usercookie,$passcookie,$redirectcookie]);
		} else {
			print $P->{query}->redirect(-uri=>"/",-cookie=>[$usercookie,$passcookie]);
		}
	
	} else {

                my $usercookie = $P->{query}->cookie(-name=>'username',-value=>'',-domain=>'.consumating.com');
                my $passcookie = $P->{query}->cookie(-name=>'password',-value=>'',-domain=>'.consumating.com');
                print $P->{query}->redirect(-uri=>"/login.pl?msg=Username+and+password+combination+not+found+in+database.",-cookie=>[$usercookie,$passcookie]);

	}
} 

sub logout {
	my ($P) = @_;
	my $usercookie = $P->{query}->cookie(-name=>'username',-value=>'',-domain=>'.consumating.com');
    my $passcookie = $P->{query}->cookie(-name=>'password',-value=>'',-domain=>'.consumating.com');
    print $P->{query}->redirect(-uri=>"/login.pl",-cookie=>[$usercookie,$passcookie]);

} 

sub forgotPassword {
	my ($P) = @_;
	print $P->Header();
	print processTemplate($P->{user},"login.forgotPassword.html");

} 

sub sendPassword {
	my ($P) = @_;
	$username = $P->{dbh}->quote($P->{query}->param('username'));
	$sql = "SELECT password FROM users WHERE username=$username";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute;
	if ($password = $sth->fetchrow_array) {
		$sth->finish;
		$P->{user}{user}{username} = $username;
		$P->{user}{user}{password} = $password;
		$text = processTemplate($P->{user},"forgotPassword.mail",1);
		$msg = new mail;
        $msg->set("From",'support@notepasser.consumating.com');
        $msg->set('to',$P->{query}->param('username'));
        $msg->set('subject',"Your Consumating Password");
		$msg->set('body',$text);
		$msg->send();	
	}
  	print $P->Header();
	print processTemplate($P->{user},"login.sendPassword.html");
}




dispatch();

# FIN
