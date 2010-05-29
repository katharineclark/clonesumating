#!/usr/bin/perl
use lib "../lib";
 
use Profiles;
use template2;
use strict;
use Net::LiveJournal;
use Net::Blogger;


{

my $P = Profiles->new();


	if ($P->{command} eq "") {
		mySettings($P);
	} elsif ($P->{command} eq "/save") {
		save($P);
	} elsif ($P->{command} eq "/ljtest") {
		ljtest($P);
	} elsif ($P->{command} eq "/store") {
		store($P);
	} elsif ($P->{command} eq "/update") {
		update($P);
	} elsif ($P->{command} eq "/disconnect") {
		disconnect($P);
	}

}


sub disconnect {
	my ($P) = @_;

	my $blogId = $P->{query}->param('blogId');
	my $userId = $P->{user}{user}{id};
	my $delete = $P->{dbh}->prepare("DELETE FROM blogapi WHERE id=? and userId=?");
	warn "Delete blog: $blogId $userId";
	$delete->execute($blogId,$userId);
	$delete->finish;
	print $P->{query}->redirect("/settings/myBlog.pl?saved=1");		
}

sub update {
	my ($P) = @_;

	my $update = $P->{dbh}->prepare("UPDATE blogapi SET postQow=?,postTopic=?,postPhoto=? WHERE id=?");
	foreach my $param ($P->{query}->param) {

		if ($param =~ /blog(\d+)/) {
			my $blogId = $1;
			my $qow = $P->{query}->param("postQow_$blogId")	|| 'N';
			my $topic = $P->{query}->param("postTopic_$blogId") || 'N';
			my $photo = $P->{query}->param("postPhoto_$blogId") || 'N';
			warn "Update $blogId $qow $topic $photo";
			$update->execute($qow,$topic,$photo,$blogId);
		}
	}
	$update->finish;

	print $P->{query}->redirect("/settings/myBlog.pl?saved=1");
}

sub mySettings {

	my ($P) = @_;

    $P->{user}{global}{requiredFields} = qq|"username","password"|;
    $P->{user}{global}{requiredFieldsDescriptions} = qq|"YOUR BLOG USERNAME","YOUR BLOG PASSWORD"|;

	if ($P->{user}{user}{id}) {	
		my $sql = "SELECT * FROM blogapi WHERE userId=? ORDER BY id DESC";
		my $getblogs = $P->{dbh}->prepare($sql);
		$getblogs->execute($P->{user}{user}{id});
		while (my $blog = $getblogs->fetchrow_hashref) {
			push(@{$P->{user}{blogs}},{blog => $blog});
		}
	}
	
	$P->{user}{page}{saved} = $P->{query}->param('saved');
	$P->{user}{page}{error} = $P->{query}->param('error');

	print $P->Header();
	print processTemplate($P->{user},"settings/myBlog.html");

}


sub save {
	my ($P) = @_;

	my $type = $P->{query}->param('type');
	my $un = $P->{query}->param('username');
	my $pw = $P->{query}->param('password');
	my $url = $P->{query}->param('apiurl');
	my $wpurl = $P->{query}->param('wpapiurl');
	my $engine;

	if ($type eq "movabletype") {
		$engine= "Movabletype";
		if ($url =~ /\/$/) {
			$url .= "mt/mt-xmlrpc.cgi";
		} else {
			$url .= "/mt/mt-xmlrpc.cgi";
		}
	} elsif ($type eq "wordpress") {
		$engine="Movabletype";
		$url = $wpurl;
	} elsif ($type eq "blogger") {
		$engine = "blogger";
		$url = "http://www.blogger.com/api";
	} elsif ($type eq "typepad") {
		$engine = "Movabletype";
		#$engine = "blogger";
		$url = "http://www.typepad.com/t/api";
	}


	$P->{user}{page}{un} = $un;
	$P->{user}{page}{pw} = $pw;
	$P->{user}{page}{url} = $url;
	$P->{user}{page}{type} = $type;

	if ($type eq "livejournal") {



	} else {

	   my $b = Net::Blogger->new;
    	$b->Username($un);
    	$b->Password($pw);
    	$b->Proxy($url);

		warn "hitting $url with $un/$pw";

		if ($url !~ /^http/) {
                print $P->{query}->redirect("/settings/myBlog.pl?error=1");
				return;
		}

    	my $res = $b->getUsersBlogs();

		if ($#{$res} > 0) {
    		foreach my $blog (0 .. $#{$res}) {
       			push(@{$P->{user}{blogs}},{blog =>  $res->[$blog] });
    		}
		} elsif ($#{$res} == 0) {
			my $blogName = $res->[0]{blogName};
			my $blogId = $res->[0]{blogid};
			my $blogUrl = $res->[0]{url};
			my $sql = "INSERT INTO blogapi (username,password,userId,apiurl,blogurl,blogid,blogname,type,engine) VALUES (?,?,?,?,?,?,?,?,?);";
			my $sth = $P->{dbh}->prepare($sql);
			$sth->execute($un,$pw,$P->{user}{user}{id},$url,$blogUrl,$blogId,$blogName,'blogger',$engine);
			print $P->{query}->redirect("/settings/myBlog.pl?saved=1");	
			return;
		} else {
		    print $P->{query}->redirect("/settings/myBlog.pl?error=1");	
			return;
		}

	}

	print $P->Header();
	print processTemplate($P->{user},"settings/myBlog.verify.html");

}

sub store {

	my ($P) = @_;

			my $sql = "INSERT INTO blogapi (username,password,userId,apiurl,blogurl,blogid,blogname,type) VALUES (?,?,?,?,?,?,?,?);";
            my $sth = $P->{dbh}->prepare($sql);
            $sth->execute($P->{query}->param('un'),$P->{query}->param('pw'),$P->{user}{user}{id},$P->{query}->param('apiurl'),$P->{query}->param('blogurl'),$P->{query}->param('blogid'),$P->{query}->param('blogname'),'blogger');
            print $P->{query}->redirect("/settings/myBlog.pl?saved=1");
            return;

}

sub ljtest {
	my ($P) = @_;
	my $un = $P->{query}->param('un');
	my $pw = $P->{query}->param('pw');


	warn "Check LJ with $un $pw";
	my $lj = Net::LiveJournal->new(user => $un, password => $pw);

 	# make an entry object...
 	my $entry = Net::LiveJournal::Entry->new(subject => "Hello from Consumating!",
                                       body    => "Your LiveJournal is now connected to your Consumating account.  (You can delete this post.)");

 	if (my $url = $lj->post($entry)) {
			$url =~ s/(.*)\/.*/$1/;
		  my $sql = "INSERT INTO blogapi (username,password,userId,apiurl,blogurl,blogid,blogname,type) VALUES (?,?,?,?,?,?,?,?);";
          my $sth = $P->{dbh}->prepare($sql);
			$sth->execute($un,$pw,$P->{user}{user}{id},'',$url,'','My LiveJournal','livejournal');
		    print $P->{query}->redirect("/settings/myBlog.pl?saved=1");
            return;
 	} else {
		warn "posting failed";
		print $P->{query}->redirect("/settings/myBlog.pl?error=1");
 	}


}


#+----------+--------------+------+-----+---------+----------------+
#| userId   | bigint(12)   | YES  |     | NULL    |                |
#| username | varchar(50)  | YES  |     | NULL    |                |
#| password | varchar(50)  | YES  |     | NULL    |                |
#| uid      | varchar(50)  | YES  |     | NULL    |                |
#| apiurl   | varchar(255) | YES  |     | NULL    |                |
#| blogurl  | varchar(255) | YES  |     | NULL    |                |
#| blogid   | varchar(255) | YES  |     | NULL    |                |
#| blogname | varchar(255) | YES  |     | NULL    |                |
#| id       | bigint(12)   |      | PRI | NULL    | auto_increment |
#| type     | enum('blogger','livejournal') | YES  |     | NULL    |            
#| postQow   | enum('Y','N')                 | YES  |     | Y       |                |
#| postTopic | enum('Y','N')                 | YES  |     | Y       |                |
#| postPhoto | enum('Y','N')                 | YES  |     | Y       |                |

