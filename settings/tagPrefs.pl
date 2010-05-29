#!/usr/bin/perl

use lib '../lib';
 
use strict;
use Profiles;
use template2;
use Users;


# main
{

    my $P = Profiles->new();

    if (!$P->verify($P->{user})) {
        exit;
    }


	if ($P->{command} eq "") {
		display($P);
	} elsif ($P->{command} eq "/save") {
		save($P);
	}


}





sub display {
	my ($P) = @_;

		my $sql = "SELECT * FROM profiles WHERE userId=$P->{user}{user}{id}";
		my $sth= $P->{dbh}->prepare($sql);
		$sth->execute;
		my $profile = $sth->fetchrow_hashref;
		%{$P->{user}{profile}} = %{$profile};
		$sth->finish;


	# load all the tags associated with this profile
		$sql = "SELECT value FROM tag,tagRef WHERE tag.id=tagRef.tagId and tagRef.profileId=$P->{user}{user}{id} and source='O';";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		my $count = 0;
		while (my $tag = $sth->fetchrow) {
			$P->{user}{tags}{$count++}{tag}{value}=$tag;
		} 
		$sth->finish;

		$sql = "SELECT value FROM tag,tagRef WHERE tag.id=tagRef.tagId and tagRef.profileId=$P->{user}{user}{id} and source='U';";
		$sth = $P->{dbh}->prepare($sql);
		$sth->execute;
		$count = 0;
		while (my $tag = $sth->fetchrow) {
			$P->{user}{usertags}{$count++}{tag}{value}=$tag;
		}
		$sth->finish;
		$P->{user}{page}{saved} = $P->{query}->param('saved');

	print $P->Header();
	print processTemplate($P->{user},"settings/tagPrefs.html");
}

sub save {
	my($P)=@_;

		$P->{dbh}->do("UPDATE profiles SET allowAnonymousTags=?,tagPublicly=? WHERE userid=?",undef,$P->{query}->param('allowAnonymousTags'),$P->{query}->param('tagPublicly'),$P->{user}{user}{id});

		# update user cache	
		Users->new(dbh => $P->{dbh}, cache => $P->{cache}, userId => $P->{user}{user}{id}, force => 1);

		print $P->{query}->redirect("/settings/tagPrefs.pl?saved=1");
}
