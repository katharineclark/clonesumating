#!/usr/bin/perl

 

if ($ENV{'REQUEST_URI'} =~ /\.jpg/) {
	Redirect("/img/nophoto.jpg");
} elsif ($ENV{'PATH_INFO'} eq "/error") {
	Redirect("/faq.pl?topic=500");
} else {
	Redirect("/faq.pl?topic=404");
}


sub Redirect {

   my ($url) = @_;
        print "Status: 302 Moved Temporarily\n";
        print "Location: $url\n\n";
        exit;

}
