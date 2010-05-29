package profmanager;
use Exporter;
use CGI::Carp 'fatalsToBrowser';
use DBUtil;
@ISA    = qw(Exporter);
@EXPORT = qw( HasProfile GetProfileByUserId );
use strict;

sub HasProfile {
    my $dbh = shift;
    my $userid = shift;
    
    my $sql = "select count(*) as c from profiles where userid=$userid;";
    my $res = DoSqlGetSingleRes($dbh,$sql);
    return($$res{c});
}

sub GetProfileByUserId {
    my $dbh = shift;
    my $userid = shift;
    my $sql = "select * from profiles where userid=$userid limit 1;";
    my $profile = DoSqlGetSingleRes($dbh,$sql);
    return($profile);
}