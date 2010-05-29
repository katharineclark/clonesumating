#!/usr/bin/perl

use lib qw(../lib lib);
 
use Profiles;
use Users;
use util;


my $P = Profiles->new();

print $P->Header;
print $P->process("admin/admin.index.html");

exit;
