package invite;

use strict;

 
use lib qw(../lib lib);
use template2;
use mail;

sub processInvite {
	my $P = shift;
	my $email = shift;
	my $tags = shift;
	
	if ($tags ne "") {
		
		my $ttags = $tags;
		$ttags =~ s/\s+/\+/gsm;
		my @tags = split(/\s+/,$tags);
		my $count = 0;
		foreach (@tags) {
			push(@{ $P->{user}{tags}},{tag => {value=> $_}});
		}

		if ($#tags > 0) {
			$tags[$#tags] = "and $tags[$#tags]";
		}
			
		$tags = join(", ",@tags);
		$P->{user}{email}{tags} = $tags;
		$P->{user}{email}{tagslink} = $ttags;
		
	} else {
		delete $P->{user}{email}{tags};
	}

	my $msg = new mail;
	$msg->set("From",'notepasser@notepasser.consumating.com');
	$msg->set("to",$email);

	if ($P->{query}->param('type') eq 'meeting') {
		$P->{user}{meeting} = $P->{dbh}->selectrow_hashref("SELECT * FROM events WHERE id = ?",undef,$P->{query}->param('typeId'));
		if ($P->{query}->param('yougottagged')) {
			$msg->set("subject","You've been tagged on Consumating.com!");
			$msg->set("body",processTemplate($P->{user},"invite/yougottagged_meeting.txt",1));
		} else {
			$msg->set("subject","$P->{user}{user}{handle} wants you to go to a party!");
			$msg->set("body",processTemplate($P->{user},"invite/email_meeting.txt",1));
		}
	} else {
		if ($P->{query}->param('yougottagged')) {
			$msg->set("subject","You've been tagged on Consumating.com!");
			$msg->set("body",processTemplate($P->{user},"invite/yougottagged.txt",1));
		} else {
			$msg->set("subject","$P->{user}{user}{firstName} $P->{user}{user}{lastName} wants you to join Consumating!");
			$msg->set("body",processTemplate($P->{user},"invite/email.txt",1));
		}
	}
	$msg->send();
}


1;
