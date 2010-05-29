#!/usr/bin/perl

use lib "/var/opt/content-8000/lib";
use profiles;


# kill any tags with commas
$sql = "SELECT * FROM tag WHERE value like '%,%';";

$sth = $dbh->prepare($sql);
$sth->execute;


$findTag = $dbh->prepare("SELECT id FROM tag WHERE value=?;");
$deleteTag = $dbh->prepare("DELETE FROM tag WHERE id=?;");
$updateRef = $dbh->prepare("UPDATE tagRef SET tagId=? WHERE tagId=?");
$updateTag = $dbh->prepare("UPDATE tag SET value=? WHERE id=?;");

while ($tag = $sth->fetchrow_hashref) {

	$val = $tag->{value};
	$val =~ s/\,//gsm;

	$findTag->execute($val);
	if ($id = $findTag->fetchrow) {
		$updateRef->execute($id,$$tag{id});
		$deleteTag->execute($$tag{id});
	} else {
		$updateTag->execute($val,$$tag{id});
	}

}

$sth->finish;


# clean dead tagrefs

$sql = "select tagRef.id from tagRef left join profiles on tagRef.profileId = profiles.userid where profiles.id is null;";
$sth = $dbh->prepare($sql);
$sth->execute;
while ($deadTagref = $sth->fetchrow) {
	$dbh->do("DELETE FROM tagRef WHERE id=$deadTagref;");
}
$sth->finish;


# get list of dupe tag references
if(0){

	$sql = "select distinct t1.profileId,t1.tagId FROM tagRef t1,tagRef t2 WHERE (t1.profileId=t2.profileId AND t1.tagId=t2.tagId) AND (t1.id!=t2.id);";

	$sth = $dbh->prepare($sql);
	$sth->execute;

	while (($p,$t)= $sth->fetchrow_array) {

			$sql = "SELECT id,(source='O') as usercreated FROM tagRef WHERE profileId=$p AND tagId=$t ORDER BY usercreated,dateAdded LIMIT 1;";
			$stx = $dbh->prepare($sql);
			$stx->execute;
			($id,$junk) = $stx->fetchrow_array;
			$stx->finish;
			$dbh->do("DELETE FROM tagRef WHERE profileId=$p AND tagId=$t AND id!=$id");
	} 

	$sth->finish;
}

# load stopwords

open(IN,"/opt/consumating/cron/hourly/stopwords.txt") || die("Unable to open stopwords.txt");
$txt = join("",<IN>);
close(IN);
$txt =~ s/\s+//gsm;
@words = split(/,/,$txt);


$find = $dbh->prepare("SELECT id FROM tag WHERE value=?");
$delete = $dbh->prepare("DELETE FROM tag WHERE id=?");
$purge = $dbh->prepare("DELETE FROM tagRef WHERE tagId=?");


foreach $word (@words) {

	$find->execute($word);
	if ($id = $find->fetchrow) {

		$purge->execute($id);
		$delete->execute($id);
	}
	
}

