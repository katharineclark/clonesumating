#!/usr/bin/perl

use lib "../lib";
 
use Digest::SHA1 qw(sha1_hex);
use strict;
use Profiles;
use template2;
use profmanager;
use CGI::Carp 'fatalsToBrowser';
use CM_Tags;
use Users;




# main
{   

    my $P = Profiles->new();

    if (!$P->verify($P->{user})) {
        exit;
    }

	if ($P->{command} eq "") {
		default($P);
	} elsif ($P->{command} eq "/docreate") {
		docreate($P);
	} elsif ($P->{command} eq "/delete") {
		deleteUser($P);
	} elsif ($P->{command} eq "/confirmDelete") {
		confirmDelete($P);
	}


}


sub default {
	my($P) = @_;

# set required fields for javascript validation
  	$P->{user}{global}{requiredFields} = qq|"handle","tagline"|;
        $P->{user}{global}{requiredFieldsDescriptions} = qq|"A HANDLE","A TAGLINE"|;

		for my $k (keys %{$P->{user}{user}}) {
			($P->{user}{form}{$k} = $P->{user}{user}{$k} ) =~ s/"/&quot;/g;
		}

		$P->{user}{page}{saved} = $P->{query}->param('saved');


		print $P->Header();
     	print processTemplate($P->{user},"settings/createProfile.html");

		return 1;

}


sub docreate {
	my ($P) = @_;	

	my $sql;

        # default the checkboxes to ZERO
                my @checkboxes = ('wantsMen','wantsWomen','relationship1','relationship2','relationship3','relationship4','relationship5');
                foreach my $cb (@checkboxes) {
                        if(!defined($P->{query}->param($cb))) {
                                $P->{query}->param($cb,0);
                	}
        	}


			$sql = "UPDATE profiles SET handle=?,tagline=?,relationshipStatus=?,wantsMen=?,wantsWomen=?, relationship1=?,relationship2=?,relationship3=?,relationship4=?,relationship5=?,auto_overheard=?,auto_topics=?,modifyDate=NOW() WHERE userid=?;";
		
	my $sth = $P->{dbh}->prepare($sql); 

	# strip html from the tagline and handle
	$P->{user}{tagline} = $P->{query}->param('tagline');
	util::cleanHtml($P->{user}{tagline},'everything');

	$P->{user}{handle} = $P->{query}->param('handle');
	util::cleanHtml($P->{user}{handle},'everything');

	$sth->execute($P->{user}{handle} , $P->{user}{tagline} , $P->{query}->param('relationshipStatus') , $P->{query}->param('wantsMen') , $P->{query}->param('wantsWomen') , $P->{query}->param('relationship1') , $P->{query}->param('relationship2') , $P->{query}->param('relationship3') , $P->{query}->param('relationship4') , $P->{query}->param('relationship5') , $P->{query}->param('auto_overheard')||undef,$P->{query}->param('auto_topics')||undef,$P->{user}{user}{id}) || die ("There was a problem saving your profile. Please click the back button and try again.  Sorry!");

	my $did = $sth->{mysql_insertid};
	$sth->finish;

	my $norank = $P->{query}->param('norank');
warn "NEW NORANK FOR $P->{user}{user}{id}: $norank";

	$P->{dbh}->do("UPDATE users SET norank = ? WHERE id = ?",undef,$norank,$P->{user}{user}{id});
	# reload the cache for the user
	my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id},force => 1);



	print $P->{query}->redirect("/settings/manageProfiles.pl?saved=1");
	return 1;

} 

sub deleteUser {
	my ($P) = @_;


	my $t = time();
	$P->{user}{page}{deleteKey} = $t.'_'.sha1_hex('foo^#*@bar'.$P->{user}{user}{password}.$t);


	print $P->Header();
	print processTemplate($P->{user},"settings/confirmDelete.html");
} 

sub confirmDelete {
	my $P = shift;

	# validate key so we know where this came from
	my $key = $P->{query}->param('key');
	my @key = split /_/,$key;
	my $t = time();
	if (sha1_hex('foo^#*@bar'.$P->{user}{user}{password}.$key[0]) ne $key[1] || $t - $key[0] > 300) {
		return default($P);
	}

	my $U = Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id});
	$U->updateField(status => -2);

	# purge the user cache
	warn "manageProfiles.pl: DELETING USER $P->{user}{user}{id}, $P->{user}{user}{status}";
	$P->{cache}->delete("userByName$P->{user}{user}{username}");
	$P->{cache}->delete("userById$P->{user}{user}{id}");
	$P->{cache}->delete("Popularity$P->{user}{user}{id}");
	$P->{cache}->delete("handleById$P->{user}{user}{id}");


	my @cookies = (
		$P->{query}->cookie(-name=>'username',-value=>'',-domain=>'.consumating.com',-expires => '-1d'),
		$P->{query}->cookie(-name=>'password',-value=>'',-domain=>'.consumating.com',-expires => '-1d'),
	);
	print $P->{query}->redirect(-location => "/",-cookie=>[@cookies]);
}
