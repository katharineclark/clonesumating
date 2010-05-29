package users;
use DBI;
use Exporter;
use profiles;

@ISA    = qw(Exporter);
@EXPORT = qw(getUser getUserQuickProfile getUserFullProfile);


sub getUser {

	my ($dbh,$userId) = @_;

	$sql = "SELECT * FROM users WHERE id=$userId;";

	return runSqlAndReturnHashRef($dbh,$sql);
}

sub getUserQuickProfile {

	my ($dbh,$userId) = @_;

	$sql = "SELECT users.*,users.id as userId,profiles.handle,profiles.tagline,photos.id as photoId FROM profiles,users left join photos on (users.id=photos.userId and photos.rank=1) where users.id=$userId and profiles.userId=users.id;";

        my $res = runSqlAndReturnHashRef($dbh,$sql);
	$res->{linkhandle} = linkify($res->{handle});
	return $res;


}

sub getUserFullProfile {

        my ($dbh,$userId) = @_;

        $sql = "SELECT users.*,profiles.*,photos.idas photoId FROM users left join profiles on users.id=profiles.userId,users left join photos on users.id=photos.userId where users.userId=$userId;";

 
        my $res = runSqlAndReturnHashRef($dbh,$sql);
        $res->{linkhandle} = linkify($res->{handle});
        return $res;


}


sub runSqlAndReturnHashRef {
	my ($dbh,$sql) = @_;

	my $sth = $dbh->prepare($sql);
	$sth->execute;
	my $res = $sth->fetchrow_hashref;
	$sth->finish;

	return $res;

}



1;
