package DBUtil;

use Exporter;
use DBI;
use CGI::Carp 'fatalsToBrowser';

@ISA = qw(Exporter);
@EXPORT = qw( DoSql DoSqlGetRes DoSqlGetSingleRes GetRowById UpdateRowById);


#
# DoSql($dbh,$sql)
#
# assumes database handler is set up fine
# dies if can't exec sql
#
sub DoSql {
    (my $dbh, my $sql) = @_;
    my $sth = $dbh->prepare($sql);
    $sth->execute || die "Couldn't execute $sql";
#    $dbh->commit;
}

#
#  DoSqlGetRes($dbh,$sql)
#
# same as above but returns an *ARRAY OF HASH REFERENCES*
# of the results
#
sub DoSqlGetRes {
    (my $dbh, my $sql) = @_;
    my $sth = $dbh->prepare($sql);
    $sth->execute || die "Couldn't execute $sql";
    my $res = $sth->fetchall_arrayref({}); # returns as refs to hashes
    return $res;
}


#
# DoSqlGetSingleRes($dbh, $sql)
#
# same as above but only fetches a single result, returns hashref
#
sub DoSqlGetSingleRes {
    (my $dbh, my $sql) = @_;
    my $sth = $dbh->prepare($sql);
    $sth->execute || die "Couldn't execute $sql";
    my $res = $sth->fetchrow_hashref();
    return $res;
}


#
# GetRowById
#

sub GetRowById {
    (my $dbh, my $table_name, my $id) = @_;

    $id = $dbh->quote($id);
    my $sql = "select * from $table_name where id=$id;";
    my $row = DoSqlGetSingleRes($dbh, $sql);
    return %$row;
}


sub UpdateRowById {
    (my $dbh, my $table_name, my %r) = @_;

    my @updates;
    foreach my $key (keys(%r)) {
        if($key ne "id") {
            push @updates,"$key=" . $dbh->quote($r{$key});
        }
    }
    my $update = join ' , ', @updates;    
    my $sql = "update $table_name set ";
    $sql .= $update;
    $sql .= " where id=$r{'id'} ";
    DoSql($dbh, $sql);    
}


1;
