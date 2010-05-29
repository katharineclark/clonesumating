package CONFIG;
use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw ($dbServer $dbUser $dbPass $dbName $imgserver $wwwserver $sitename $staticPath $tempPath $templatePath);



$dbServer = ''; # mysql database server
$dbUser = ''; # mysql database user
$dbPass = ''; #mysql database password
$dbName= ''; #mysql database name
$imgserver = ""; # image server as in  images.consumating.com
$wwwserver = ""; # www server as in www.consumating.com
$sitename = "MY SUPER AWESOME SITE"; # site name - only used a few times in code, but hey...
$staticPath = ""; # path to static files (img/ photos/ css/)
$tempPath = ""; # path to temp scratch space
$templatePath = ""; # path to templates (front/)
