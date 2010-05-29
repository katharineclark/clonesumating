#!/usr/bin/perl

use lib "lib";
use strict;
use Profiles;
use template2;
use bbDates;
use photos;
use CM_Tags;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Users;
use points;
use Alerts;
use items;

my $freePoints = 10;



{ 

	my $P = Profiles->new();

	if ($P->{command} eq "") {
			default($P);
	} elsif ($P->{command} eq "/create") {
			create($P);
	} elsif ($P->{command} eq "/checkHandle") {
			checkHandle($P);
	} elsif ($P->{command} eq "/checkEmail") {
			checkEmail($P);
	} elsif ($P->{command} eq "/thanks") {
			thanks($P);
	} else {
			print $P->Header();
			ErrorOut("Unknown Command");
	}

}




sub prepareFields {
	my $P = shift;
	my %args = @_;
	$P->{user}{global}{requiredFields} = qq|"handle","tagline","do","firstName","lastName","month","day","year","sex","username","password"|;
	$P->{user}{global}{requiredFieldsDescriptions} = qq|"Your Consumating Name","Your Witty One-Liner","Your Tags","Your First Name","Your Last Name","Your Birth Month","Your Birth Day","Your Birth Year","Your Sex","Your E-Mail Address","Your Password"|;

	$P->{user}{global}{requiredValidEmail} = 1;
	$P->{user}{global}{requireLocation} = 1;
	$P->{user}{global}{suggestPhoto} = 1;
	$P->{user}{global}{checkTos} = 1;


	$P->{user}{login}{monthSelect} =  monthSelect($args{month});
	$P->{user}{login}{daySelect} = daySelect($args{day});
	$P->{user}{login}{yearSelect} = yearSelect($args{year}||1988,1900,1988);
	$P->{user}{login}{countrySelect} = $P->{util}->countrySelect($args{country}||"US");


}



sub default {
	my ($P) = @_;
	prepareFields($P);


	if (my $itemId = $P->{query}->param('item')) {
		my $I = items->new($P->{cache},$P->{dbh},0);
		if ($I->{allItems}{$itemId}) {
			$P->{user}{item} = $I->{allItems}{$itemId};
			($P->{user}{item}{handle},$P->{user}{item}{linkhandle}) = $P->{util}->getHandle($I->{allItems}{$itemId}{previousOwnerId});
		}
	}


	print $P->Header();
	print processTemplate($P->{user},"register.html");

}



sub create {
	my ($P) = @_;

	my %qform;

	foreach ($P->{query}->param) {
		$qform{$_} = $P->{dbh}->quote($P->{query}->param($_));
	}
	$qform{lat} = $P->{query}->param('lat');
	$qform{lng} = $P->{query}->param('lng');

    my @checkboxes = ('wantsMen','wantsWomen','relationship1','relationship2','relationship3','relationship4','relationship5');
    foreach my $cb (@checkboxes) {
    	if(!defined($qform{$cb})) {
        	$qform{$cb} = qq|0|;
   		}
    }

	my $birthDate = $P->{query}->param('year') . "-" . $P->{query}->param('month') . "-" . $P->{query}->param('day');


# create user
	my ($bu,$bh,@uerr,@perr);
	($bu,@uerr) = validateUser($P);
	($bh,@perr) = validateProfile($P);
	
	my @errmsg;
	push @errmsg, "Email address is already being used or is invalid" if $bu;
	push @errmsg, "Handle is already being used" if $bh;
	push @errmsg, map {"$_ is invalid"}grep{length $_}(@uerr,@perr);
	if (scalar @errmsg) {
		$P->{user}{global}{errmsg} = join "<br/>",@errmsg;

		prepareFields(map{$_ => $P->{query}->param($_)||undef}qw(month day year country));

		for ($P->{query}->param) {
			$P->{user}{form}{$_} = $P->{query}->param($_);
		}
		for (qw(wantsMen wantsWomen relationshipStatus relationship1 relationship2 relationship3 relationship4 relationship5)) {
			$P->{user}{profile}{$_} = $P->{query}->param($_) || 0;
		}


		print $P->Header();
		print processTemplate($P->{user},'register.html');
		return;
	}
		

	if ($P->{query}->param('country') ne "US") {
                $qform{'city'} = $qform{'foreigncity'};
		$qform{'state'} = "NULL";
		$qform{'zipcode'} = "NULL";
        }
	
	my $authkey = md5_hex(time().$qform{'firstName'}.$qform{'zipcode'});
	$P->{user}{registration}{authkey} = $authkey;
	

    my $sql = "INSERT INTO users (firstName,lastName,zipcode,city,state,country,username,password,sex,birthDate,createDate,lastLogin,points,partner,authkey) VALUES ($qform{'firstName'},$qform{'lastName'},$qform{'zipcode'},$qform{'city'},$qform{'state'},$qform{'country'},$qform{'username'},$qform{'password'},$qform{'sex'},'$birthDate',NOW(),NOW(),$freePoints,'$P->{user}{global}{cobrand}','$authkey')";
	# uncomment to enable latitude / longitude storing
	#my $sql = "INSERT INTO users (firstName,lastName,zipcode,city,state,country,username,password,sex,birthDate,createDate,lastLogin,points,partner,authkey,latitude,longitude) VALUES ($qform{'firstName'},$qform{'lastName'},$qform{'zipcode'},$qform{'city'},$qform{'state'},$qform{'country'},$qform{'username'},$qform{'password'},$qform{'sex'},'$birthDate',NOW(),NOW(),$freePoints,'$P->{user}{global}{cobrand}','$authkey',$qform{'lat'},$qform{'lng'})";



	my $sth = $P->{dbh}->prepare($sql);
	$sth->execute || ErrorOut("Could not create user!  This is most likely due to your e-mail address already being in the system, which means you don't have to register again!  <A href='/login.pl'>Login!</a>.  Error: " . $DBI::errstr);
	my $userId = $sth->{mysql_insertid};
	$sth->finish;

	if ($P->{query}->param('alerts')) {
		my $A = Alerts->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $userId);
		$A->setSubs({
			'newmessage' => 'email',
			'newcontest' => 'email',
			'newquestion' => 'email'
		});
	}

	if ($P->{query}->param('consume')) {
		$sql = "INSERT INTO newsletterSubscriptions (email,newsletter,date,userId) VALUES (?,?,NOW(),?);";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute($P->{query}->param('username'),'consume',$userId);
		$sth->finish;
	}

# generate local query
	#my $latR = $qform{'lat'} * 3.141593 / 180;
	#my $query = "'ACOS(SIN($latR) * SIN(users.latitude * PI()/180) + COS($latR)*COS(users.latitude*PI()/180)*COS($qform{'lng'}-users.longitude)) *60*1.1515 * 180/PI() <= 50'";
	#$P->{dbh}->do("UPDATE users SET localQuery=$query WHERE id=$userId");
	if (1) {
		if ($P->{query}->param('country') eq "US") {

			$sth = $P->{dbh}->prepare("SELECT fifty FROM zips WHERE zip=$qform{'zipcode'};");
			$sth->execute;
			if (my $zips = $sth->fetchrow) {
				my $query = $P->{dbh}->quote(qq| users.zipcode in ($zips) |);
				$P->{dbh}->do("UPDATE users SET localQuery=$query WHERE id=$userId;");
			}

		} else {

			my $query = $P->{dbh}->quote(qq| users.country = $qform{'country'} |);
			$P->{dbh}->do("UPDATE users SET localQuery=$query WHERE id=$userId");
			

		}
	}



	if (0) {
	my @day = localtime;
	if ($day[4] == 2 && $day[3] == 17) {
		# insert valentines candies
		#my @types = ('ASL Heart','EmotoHeart',"I'd Do You Heart",'Thumb Heart','X X X Heart','Ugh Heart','OMG Heart');
		my @types = ('lucky clover','Genius Draught','leprechaun','clover');
		my $sth = $P->{dbh}->prepare("INSERT INTO user_items (name,ownerId,creatorId,createDate,previousOwnerId,lastGiveDate,location) VALUES (?,$userId,9656,now(),9656,now(),'pocket')");
		for (@types) {
			$sth->execute($_);
			$sth->execute($_);
		}
		$sth->finish;
	}
	}

# create profile


	$sql = "INSERT INTO profiles (userid,handle,tagline,wantsMen,wantsWomen,relationship1,relationship2,relationship3,relationship4,relationship5,relationshipStatus,modifyDate) VALUES ($userId,$qform{'handle'},$qform{'tagline'},$qform{'wantsMen'},$qform{'wantsWomen'},$qform{'relationship1'},$qform{'relationship2'},$qform{'relationship3'},$qform{'relationship4'},$qform{'relationship5'},$qform{'relationshipStatus'},NOW());";
	warn "register.pl - CREATING PROFILE - $sql;";
	$sth = $P->{dbh}->prepare($sql);
	$sth->execute || do {ErrorOut("Could not create profile!");warn $P->{dbh}->errstr;};
	$sth->finish;

# now, add tags
	my @tags = split(" ",$P->{query}->param('looklike') . " " . $P->{query}->param('like') . " " . $P->{query}->param('do'));
	foreach my $tag (@tags) {

		if ($tag eq "") { next; }
		addTag($P->{dbh},$tag,$userId,$userId);

	}

	my $redir = "/register.pl/thanks";


	if ($P->{query}->param('photo')) {
		if (savePhoto($P->{query},$userId,$P->{dbh})) {
			$P->{dbh}->do("UPDATE users SET firstUpload='Y',points=points+1 WHERE id=$userId");
		} else {
		#	$redir = "/photos.pl";
		}
	}
	

# add thumbs, tags, hotlist if this person was invited


	my $invitedBy = $P->{query}->param('invitedBy');


	if ($invitedBy =~ /\d+/) {

		if ($P->{query}->param('thumb')) {
# this is only a thumb, so just do it and proceed.
			my $type;
			if ($P->{query}->param('thumb') eq "up") {
				$type = 'U';
			} else {
				$type='D';
			}	
			$P->{dbh}->do("INSERT INTO thumb (userId,profileId,type,insertDate) VALUES ($userId,$invitedBy,'$type',NOW());");
		} else {
# this is a straight invite, thumb both, hotlist both, add tags if any
			$P->{dbh}->do("INSERT INTO thumb (userId,profileId,type,insertDate) VALUES ($invitedBy,$userId,'U',NOW())");
			$P->{dbh}->do("INSERT INTO thumb (userId,profileId,type,insertDate) VALUES ($userId,$invitedBy,'U',NOW())");
			$P->{dbh}->do("INSERT INTO hotlist (userId,profileId,dateAdded) VALUES ($userId,$invitedBy,NOW());");
			$P->{dbh}->do("INSERT INTO hotlist (userId,profileId,dateAdded) VALUES ($invitedBy,$userId,NOW());");
			if ($P->{query}->param('invitetags')) {
				my @tags = split(/\s+/,$P->{query}->param('invitetags'));
        			foreach my $tag (@tags) {
                			if ($tag eq "") { next; }
                			addTag($P->{dbh},$tag,$userId,$invitedBy);
        			}
			}
		}


		# credit the inviter
		my $Points = points->new(dbh => $P->{dbh}, cache => $P->{cache});
		$Points->storeTransaction({
			userid	=> $invitedBy,
			points	=> $Points->{system}{goodinvite}{amount},
			type	=> 'system',
			desc	=> "$Points->{system}{goodinvite}{desc}"
			}
		);

	}


	# give gifted item
	if (my $itemId = $P->{query}->param('itemId')) {
		my $I = items->new($P->{cache},$P->{dbh},0);
		warn "GIVE ITEM $itemId FROM 0 TO $userId: ".$I->giveItem($userId,$itemId);
		$redir = "/profiles/".util::linkify($P->{query}->param('handle'))."/inventory";
	}

	# load user cache for the first time
	my $u = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $userId, force => 1);
	$P->{user}{user} = $u->profile;

    $P->{user}{registration}{authkey} = $authkey;

	# credit for registration
	my $Points = points->new(dbh => $P->{dbh}, cache => $P->{cache});
	$Points->storeTransaction({
		userid	=> $userId,
		points	=> (ref $Points->{system}{register}{amount} eq 'CODE' ? $Points->{system}{register}{amount}->() : $Points->{system}{register}{amount}),
		type	=> 'system',
		desc	=> "$Points->{system}{register}{desc}"
		}
	);

	
	my $usernamecookie = $P->{query}->cookie(-name=>"username",-value=>$P->{query}->param('username'),-domain=>'.consumating.com');
	my $passwordcookie = $P->{query}->cookie(-name=>"password",-value=>md5_hex('csm21000'.$P->{query}->param('password')),-domain=>'.consumating.com');


	print $P->{query}->redirect(-uri=>$redir,-cookie=>[$usernamecookie,$passwordcookie]);


		use mail;
		my $mail = new mail (
			to => $P->{query}->param('username'),
			From => 'welcome@notepasser.consumating.com',
			subject => 'Welcome to Consumating.com!',
			body => processTemplate($P->{user},'emails/register.email.html',1),
		);
		$mail->send;

}


sub thanks {
	my ($P) = @_;

	$P->{user}{page}{verified} = $P->{query}->param('verified');
    $P->{user}{email}{verification} = $P->{util}->encrypt($P->{user}{user}{handle});
	print $P->Header();
	print processTemplate($P->{user},"register.thanks.html");

} 

sub checkHandle {
	my ($P) = @_;
	my ($h,$sql,$sth,$c);
 
	        $h = $P->{dbh}->quote($P->{query}->param('test'));

        $sql = "SELECT count(1) FROM profiles WHERE handle=$h;";
        $sth = $P->{dbh}->prepare($sql);
        $sth->execute;
        $c = $sth->fetchrow;
        $sth->finish;
        if ($c > 0) {
                print $P->{query}->header();
                print "NO";
        
        } else {
                print $P->{query}->header();
                print "YES";
        }

} 


sub checkEmail {
	my ($P) = @_;
	my ($e,$sql,$sth,$c);
        $e = $P->{dbh}->quote($P->{query}->param('test'));
        
        $sql = "SELECT count(1) FROM users WHERE username=$e;";
        $sth = $P->{dbh}->prepare($sql);
        $sth->execute;
        $c = $sth->fetchrow;
        $sth->finish;
        if ($c > 0) {
                print $P->{query}->header();
                print "NO";
        
        } else {
                print $P->{query}->header();
                print "YES";
        }


} 




sub validateUser {

	my ($P) = @_;
    # check user table values
    my %form = map {$_ => $P->{query}->param($_)||''}qw(firstName lastName username password sex year month day);
    $form{birthDate} = join '-',@form{qw(year month day)};

    if ($P->{query}->param('country') eq 'US') {
        $form{$_} = $P->{query}->param($_) for (qw(city state zipcode));

    } else {
        $form{city} = $P->{query}->param('foreigncity');
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


    my $sth = $P->{dbh}->prepare("SELECT COUNT(*) FROM users WHERE username = ?");
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
	my ($P) = @_;
    # check profile table values
    my %form = map {$_ => $P->{query}->param($_)||''}qw(handle tagline relationshipStatus);
    for (qw(wantsMen wantsWomen relationship1 relationship2 relationship3 relationship4 relationship5)) {
        $form{$_} = $P->{query}->param($_) || 0;
    }

    my @err = grep{!length $form{$_}} keys %form;

    my $sth = $P->{dbh}->prepare("SELECT COUNT(*) FROM profiles WHERE handle = ?");
    $sth->execute($form{handle});
    my $badhandle = undef;
    if ($sth->fetchrow > 0) {
        $badhandle = $form{handle};
    }
    $sth->finish;

    return ($badhandle,@err);

}
