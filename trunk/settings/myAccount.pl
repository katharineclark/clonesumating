#!/usr/bin/perl

use strict;
 
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

use lib "../lib";
use Profiles;
use template2;
use bbDates;
use Users;
use Alerts;




{ 

	my $P = Profiles->new();

	if (!$P->verify($P->{user})) {
        exit;
	}

	$P->{user}{global}{scriptName} = '/settings/myAccount.pl';

	if ($P->{command} eq "/password") {
		password($P);
	} elsif ($P->{command} eq "/save") {
		save($P);	
	} elsif ($P->{command} eq "/alerts") {
		alerts($P);
	} elsif ($P->{command} eq "/savealerts") {
		savealerts($P);
	} elsif ($P->{command} eq "/verifyEmail") {
		verifyEmail($P);
	} elsif ($P->{command} eq '/reVerify') {
		reVerify($P);
	} elsif ($P->{command} eq "/blocklist") {
		blocklist($P);
	} else {
		default($P);
	}

}

sub password {
	my ($P) = @_;
        $P->{user}{global}{requiredPasswordsMatch} = 1;


        print $P->Header();
        print processTemplate($P->{user},"settings/myAccount.password.html");

}


sub alerts {
	my $P = shift;

	my $A = Alerts->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id});
	$P->{user}{alerts} = [map {alert => $_->{alert}} => sort { $a->{alert}{description} cmp $b->{alert}{description} } values(%{$A->getSubs})];

	print $P->Header();
	print processTemplate($P->{user},"settings/myAccount.alerts.html");
}


sub savealerts {

	my ($P) = @_;

	my %subs;
	foreach ($P->{query}->param) {
		if (index($_,'alert') == 0) {
			$subs{substr($_,6)} = $P->{query}->param(substr($_,6).'_target');
		}
	}
	my $A = Alerts->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id});
	$A->setSubs(\%subs);
	
	print $P->{query}->redirect("/settings/myAccount.pl/alerts");

} 


sub default {
	my ($P) = @_;

	$P->{user}{global}{requiredFields} = qq|"firstName","lastName","month","day","year","sex","username"|;
    $P->{user}{global}{requiredFieldsDescriptions} = qq|"YOUR FIRST NAME","YOUR LAST NAME","YOUR BIRTH MONTH","YOUR BIRTH DAY","YOUR BIRTH YEAR","YOUR GENDER","YOUR EMAIL ADDRESS"|;

    $P->{user}{global}{requiredValidEmail} = 1;
    $P->{user}{global}{requireLocation} = 1;

    my ($year,$month,$day) = split(/-/,$P->{user}{user}{birthDate});
    $P->{user}{user}{daySelect} = daySelect($day);
    $P->{user}{user}{monthSelect} = monthSelect($month);
    $P->{user}{user}{yearSelect} = yearSelect($year,1900,1988);
	$P->{user}{user}{countrySelect} = $P->{util}->countrySelect($P->{user}{user}{country});

	$P->{user}{page}{saved} = $P->{query}->param('saved');

	unless ($P->{user}{user}{longitude}) {
		$P->{user}{user}{longitude} = 15.3672;
		$P->{user}{user}{latitude} = 30.5937;
		$P->{user}{map}{zoom} = 16;
	} else {
		$P->{user}{map}{zoom} = 8;
	}

	if (index($P->{user}{user}{cell}, 'teleflip') != -1) {
		$P->{user}{user}{skipCellAuth} = 1;
	}

	$P->{user}{postbody}{javascript} = <<__JS__;
load();
document.body.onunload = function() { GUnload(); };
__JS__

	print $P->Header();
    print processTemplate($P->{user},"settings/myAccount.update.html");

}



sub save {
	my ($P) = @_;

	my %qform;
	foreach ($P->{query}->param) {
		$qform{$_} = $P->{dbh}->quote($P->{query}->param($_));
	}
	$qform{lat} = $P->{query}->param('lat') || $P->{user}{user}{latitude} || 30.5937;
	$qform{lng} = $P->{query}->param('lng') || $P->{user}{user}{longitude}|| 15.3672;
warn "LAT LONG: $qform{lat} - $qform{lng}";

	if ($P->{query}->param('country') ne "US") {
		$qform{'city'} = $qform{'foreigncity'};
		$qform{'state'} = "NULL";
		$qform{'zipcode'} = "NULL";
	}


	if ($qform{cell} ne $P->{user}{user}{cell} && !$qform{skipCellAuth}) {
		# cell changed, re-authenticate
		Alerts::authenticate($P->{user}{user}{cell});
	}
	if ($qform{skipCellAuth} && index($qform{cell},'teleflip') == -1) {
		$qform{cell} = $P->{dbh}->quote($P->{query}->param('cell').'@teleflip.com');
	}

	if (!$P->{query}->param('password')) { 

		my $birthDate = $P->{query}->param('year') . "-" . $P->{query}->param('month') . "-" . $P->{query}->param('day');
		my $optout = $P->{query}->param('optout') ||'Y';
		my $sql = "UPDATE users SET firstName=$qform{'firstName'},lastName=$qform{'lastName'},zipcode=$qform{'zipcode'},city=$qform{'city'},state=$qform{'state'},country=$qform{'country'},username=$qform{'username'},sex=$qform{'sex'},birthDate='$birthDate',optout='$optout',cell=$qform{cell},latitude=$qform{lat},longitude=$qform{lng} where id=$P->{user}{user}{id}";
		$P->{dbh}->do($sql) ||  ErrorOut("Could not update user!");
	}

	# set cache
	{
		my $profile = $P->{cache}->get("cardinfo$P->{user}{user}{id}") || $P->{cache}->get("cardinfo$P->{user}{user}{handle}");
		if ($profile) {
			$profile->{city} = $P->{query}->param('city');
			$profile->{state} = $P->{query}->param('state');
			$profile->{country} = $P->{query}->param('country');
			$P->{cache}->set("cardinfo$profile->{handle}",$profile,3600);
			$P->{cache}->set("cardinfo$profile->{userId}",$profile,3600);
		}
	}

	# generate local query
	#my $latR = $qform{'lat'} * 3.141593 / 180;
	#my $query = "'ACOS(SIN($latR) * SIN(users.latitude * PI()/180) + COS($latR)*COS(users.latitude*PI()/180)*COS($qform{'lng'}-users.longitude)) *60*1.1515 * 180/PI() <= 50'";
	#$P->{dbh}->do("UPDATE users SET localQuery=$query WHERE id=$P->{user}{user}{id}");
	if (1) {
		if ($P->{query}->param('country') eq "US") {
			my @dists = qw(five ten twentyfive fifty);
			my $d = 0;
			my $sth;
			do {
				$sth = $P->{dbh}->prepare("SELECT $dists[$d] FROM zips WHERE zip=$qform{'zipcode'};");
				$sth->execute;
			} while ($sth->rows < 10 && $d++ < $#dists);
			my $zips = $sth->fetchrow;
			my $localquery = $P->{dbh}->quote(qq| users.zipcode in ($zips) |);
			$P->{dbh}->do("UPDATE users SET localQuery=$localquery WHERE id=$P->{user}{user}{id};");
		} else {
			my $query = $P->{dbh}->quote(qq| users.country = $qform{'country'} |);
			$P->{dbh}->do("UPDATE users SET localQuery=$query WHERE id=$P->{user}{user}{id}");
		}
	}


	my $passwordcookie;
	if ($P->{query}->param('password') ne "") {
		my $sql = "UPDATE users SET password=$qform{'password'} where id=$P->{user}{user}{id}";
		$P->{dbh}->do($sql) ||  ErrorOut("Could not update password!");
		$passwordcookie = $P->{query}->cookie(-name=>"password",-value=>md5_hex('csm21000'.$P->{query}->param('password')),-domain=>'.consumating.com'); 
	}

	# update users cache
	my $u = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id}, force => 1);
	$P->{user}{user} = $u->{profile};

	my $usercookie = $P->{query}->cookie(-name=>"username",-value=>$P->{query}->param('username'),-domain=>'.consumating.com');
	print $P->{query}->redirect(-uri=>"/settings/myAccount.pl?saved=1",-cookie=>[$usercookie,$passwordcookie]);
}




sub verifyEmail {
	my ($P) = @_;
	if ($P->{query}->param('authkey')) {
		my $authkey = $P->{dbh}->selectrow_array("SELECT authkey FROM users WHERE id = $P->{user}{user}{id}");

		if (length $authkey) {
			if ($authkey eq $P->{query}->param('authkey')) {
				$P->{dbh}->do("UPDATE users SET authkey = NULL WHERE id = ?",undef,$P->{user}{user}{id});

				# update users cache
				my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id}, force => 1);
				$P->{user}{user} = $U->profile;

				print $P->{query}->redirect('/register.pl/thanks?verified=1');
				return;
			} else {
				$P->{user}{error}{message} = "The code you entered was incorrect!  Please try again!";
			}
		} else {
			print $P->{query}->redirect('/register.pl/thanks?verified=1');
			return;
		}
	}
	print $P->Header();
	print processTemplate($P->{user},"settings/myAccount.verifyEmail.html");
}

sub reVerify {
	my $P = shift;

	$P->{user}{registration}{authkey} = $P->{user}{user}{authkey};

	my $mail = new mail (
		to => $P->{user}{user}{username},
		From => 'welcome@notepasser.consumating.com',
		subject => 'Welcome to Consumating.com!',
		body => processTemplate($P->{user},'emails/register.email.html',1),
	);
	$mail->send or warn "ERROR SENDING MAIL";

	$P->{user}{page}{message} = 1;

	print $P->Header();
	print processTemplate($P->{user},"settings/myAccount.verifyEmail.html");
}

sub blocklist {
	my $P = shift;
	print $P->Header();
	if ($P->{query}->param('submitted')) {
		my @params = $P->{query}->param;
		my %input;
		my ($handle,$userId,@users);
		for my $parm (@params) {
			my ($b,$id) = split /-/,$parm;
warn "PARAM: $b, $id";
			next unless $b && $id;
			if ($id eq 'new') {
				if (!$userId && !$handle) {
					$handle = $P->{query}->param('blockname');
					$userId = $P->{dbh}->selectrow_array("SELECT userId FROM profiles WHERE handle = ?",undef,$handle);
				}
				$id = $userId;
			}
			push @{$input{$id}}, substr($b,5);
		}

		if (ref $P->{cache}->get("block$P->{user}{user}{id}") eq 'ARRAY') {
			for (@{$P->{cache}->get("block$P->{user}{user}{id}")}) {
				$P->{cache}->delete("block$P->{user}{user}{id}-$_");
			}
		}
		$P->{cache}->set("block$P->{user}{user}{id}",[keys %input]);

		$P->{dbh}->do("DELETE FROM blocklist WHERE profileId=?",undef,$P->{user}{user}{id});
		my $ins = $P->{dbh}->prepare("INSERT INTO blocklist (profileId,userId,type) VALUES (?,?,?)");
		for my $uid (keys %input) {
			for (@{$input{$uid}}) {
				$ins->execute($P->{user}{user}{id},$uid,$_);
			}
			$P->{cache}->set("block$P->{user}{user}{id}-$userId",$input{$uid});
		}
	}

	my $sth = $P->{dbh}->prepare("SELECT * FROM blocklist WHERE profileId=?");
	$sth->execute($P->{user}{user}{id});
	my %blocks;
	while (my $r = $sth->fetchrow_hashref) {
		my $u = Users->new(dbh => $P->{dbh},cache => $P->{cache},userId => $r->{userId}) or next;
		$blocks{$r->{userId}}{profile} = $u->profile;
		$blocks{$r->{userId}}{$r->{type}}{value} = 1;
	}
	for my $uid (keys %blocks) {
		push @{$P->{user}{blocklist}}, { profile => $blocks{$uid}{profile}, map { $_ => $blocks{$uid}{$_}||undef}qw(tag conversation message) } ;
	}

	print processTemplate($P->{user},"settings/myAccount.blocklist.html");
}
