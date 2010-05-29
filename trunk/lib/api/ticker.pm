package api::ticker;

use strict;
 
use lib qw(lib ../lib ../../lib);
use api;
use thumbticker;
use tagticker;
use template;

our @ISA = qw(api);

sub getThumbs {
	my $self = shift;

	my $T = new thumbticker($self->{dbh},undef,undef,$self->{query}->param('widget')||0);
	%{$self->{user}{thumbticker}} = %{$T->build};

	my $content = processTemplate($self->{user},"thumbticker.html",1);
	return $self->generateResponse("ok","handleThumbTickerResponse","<content><![CDATA[$content]]></content>");
}
sub getTags {
	my $self = shift;
	my $T = new tagticker($self->{dbh},undef,undef,$self->{query}->param('widget')||0);
	%{$self->{user}{ticker}} = %{$T->build};

	my $content = processTemplate($self->{user},"tagticker.html",1);
	return $self->generateResponse("ok","handleTagTickerResponse","<content><![CDATA[$content]]></content>");
}

1;
