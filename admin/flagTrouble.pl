#!/usr/bin/perl

use lib "/var/opt/content-8000/lib";
use profiles;

# check tos ee if someone is tagging lots of people with the same tag
if ($command eq "") {

$sql = qq|SELECT handle,userId,value,tag.id as tagId,count(tagRef.profileId) as timesTagged FROM profiles,tagRef,tag WHERE profiles.userId=tagRef.addedById and tagRef.tagId=tag.id AND tagRef.profileId!= tagRef.addedById and tagRef.dateAdded > DATE_SUB(NOW(),INTERVAL 50 DAY) group by tag.value having timesTagged >= 2 order by timesTagged desc;|;

$sth = $dbh->prepare($sql);
$sth->execute;
print Header();
while ($res = $sth->fetchrow_hashref) {

	print qq|$$res{handle} added the tag <B>$$res{value}</B> to $$res{timesTagged} people.  <a href="$scriptName/toad?userId=$$res{userId}&tagId=$$res{tagId}">Toad this tag</a>.<BR /><BR />\n\n|;

}
$sth->finish;

} elsif ($command eq "/toad") {

	$tagId = $q->param('tagId');
	$userId =$q->param('userId');
	$dbh->do("DELETE FROM tagRef where tagId=$tagId and addedById=$userId");
	$dbh->do("UPDATE users SET trouble='Y' WHERE id=$userId");
	print $q->redirect($scriptName);
}
