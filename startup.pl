use strict;

 
use lib qw(/var/opt/content-8000-open/lib /var/opt/content-8000-open);



use Apache2::Const -compile => ':common';
use APR::Const -compile => ':common';

use Apache2::Reload;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Connection ();
use Apache2::Log ();
use APR::Table ();

use CGI;
use List::Util;
use HTML::Detoxifier;
use Socket;
use Data::Dumper;
use Email::Valid;
use Digest::MD5;
use FileHandle;
use Image::Magick;
use Apache::DBI();

use CONFIG;


DBI->install_driver("mysql");
Apache::DBI->connect_on_init("DBI:mysql:$dbName:$dbServer",$dbUser,$dbPass, {
      PrintError => 1, # warn() on errors
      RaiseError => 0, # don't die on error
      AutoCommit => 1, # commit executes
     # immediately
    }
) or warn "Cannot connect to database: $DBI::errstr";
$Apache::DBI::DEBUG = 0;


use template;
use template2;
use Users;
use tags;
use blings;
use Cache;
use sphere;
use CM_Tags;
use QuestionResponse;
use Profiles;
use query;
use util;
use teams;



1;
