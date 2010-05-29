package alerts;

use strict;

 
use lib '.';
use Exporter;
use template;
use Users;
use mail;

our @ISA = qw(Exporter);
our (@EXPORT,@EXPORT_OK);
@EXPORT_OK = qw(getUserAlerts setUserAlerts sendAlert checkUserSubscription);


sub getUserAlerts {
# returns template lib compatible list of all alerts
# subscribed alerts are highlighted.
	my ($dbh,$uid) = @_;
	my (%alertSubs);
	
#load all alert types
	my $sql = qq|SELECT description,name,id FROM alertTypes|;
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	while (my $alert = $sth->fetchrow_hashref) {
		$alertSubs{$alert->{id}}{alert} = $alert;
	}
		
	$sth->finish;

	$sql = qq|SELECT alertId FROM alertSubscriptions WHERE userId=?|;
	$sth = $dbh->prepare($sql);
	$sth->execute($uid);
	while (my $alert = $sth->fetchrow_hashref) {
		$alertSubs{$alert->{alertId}}{alert}{subscribed} = 1;
	}
	$sth->finish;

	return \%alertSubs;
}

sub setUserAlerts {
# take a hash of alert names
# and subscribe user to all of them
# being careful to clear out old subs
	my ($dbh,$uid,$alerts) = @_;

    my (%alertLookup);

#load all alert types
    my $sql = qq|SELECT name,id FROM alertTypes|;
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while (my $alert = $sth->fetchrow_hashref) {
        $alertLookup{$alert->{name}} = $alert->{id};
    }

	$dbh->do("DELETE FROM alertSubscriptions WHERE userId=$uid");
	my $addSub = $dbh->prepare(qq|INSERT INTO alertSubscriptions (userId,alertId) VALUES ($uid,?)|);
	foreach (keys %{$alerts}) {
		$addSub->execute($alertLookup{$_});
	}
	$addSub->finish;	

	return 1;

}


sub checkUserSubscription {
	my ($dbh,$alert,$uid) = @_;


	my $sth = $dbh->prepare(qq|SELECT alertTypes.id FROM alertTypes inner join alertSubscriptions on alertTypes.id=alertSubscriptions.alertId and alertSubscriptions.userId=? WHERE name=? and type='personal'|);
	$sth->execute($uid,$alert);
	if ($sth->fetchrow) {
		$sth->finish;
		return 1;
	} else {
		$sth->finish;
		return 0;
	}
}	

sub sendAlert {
	my ($dbh,$alert,$user) = @_;
	
	if (checkUserSubscription($dbh,$alert,$user->{user}{userId})) {
    	my $msg = new mail;
        $msg->set("From",'notepasser@notepasser.consumating.com');
        $msg->set("to",$user->{user}{username});
        $msg->set("subject",processTemplate($user,"alerts/$alert.subject.txt",1));
        $msg->set("body",processTemplate($user,"alerts/$alert.txt",1));
	    $msg->send();
	}
}


1;
