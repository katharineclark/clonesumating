#================================================================
# VideoEgg Integration Kit
# v1.1.1
#================================================================

use strict;

use Time::Local;
use Digest::MD5;

use vars qw( 
	$VE_uploadTimeframe $VE_downloadTimeframe $VE_KITVER
	$VE_CLIENT_ID $VE_UPLOAD_PASSWORD $VE_DOWNLOAD_PASSWORD
	$VE_HOSTNAME_PREFIX
);

$VE_KITVER = "1.2.0";
$VE_uploadTimeframe = 28800; # In seconds: 28800 = 8 hours
$VE_downloadTimeframe = 3600; # In seconds: 3600 = 60 minutes

sub VE_EmbedPublisher {
	my ( $action, $configuration, $bgcolor, $hidden, $meta, $username, $destinationURL) = @_;

	return VE_EmbedPublisher2($action, $configuration, $bgcolor, $hidden, $meta, $username, $destinationURL, "");
}

sub VE_EmbedPublisher2 {
	my ( $action, $configuration, $bgcolor, $hidden, $meta, $username, $destinationURL, $loadAlt) = @_;

	my $serverPath = "http://update" . $loadAlt . ".videoegg.com/";

	if (! defined("VE_HOSTNAME_PREFIX")) {
	    $VE_HOSTNAME_PREFIX = "";
	}

	# Generate the file prefix
	my $rand_string = '';
	my $dir_string = '';

	my $rand_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
	for (my $i = 0; $i < 4; $i++) {
		$dir_string .= substr($rand_chars, rand(35), 1);
	}
	my $dir1 = substr($dir_string, 0, 2);
	my $dir2 = substr($dir_string, 2, 2);
	
	$rand_chars .= 'abcdefghijklmnopqrstuvwxyz'; # Add the lowercase alphabet for the file name generation
	for ( my $i = 0; $i < 20; $i++) {
		$rand_string .= substr($rand_chars, rand(61), 1);
	}
	my $file_guid = time() . $rand_string;

	my $filename = '/' . $VE_CLIENT_ID . '/' . $dir1 . '/' . $dir2 . '/' . $file_guid;
	
	my $authToken = VE_GenerateUploadAuthToken($filename . '*', (time() + $VE_uploadTimeframe), $VE_UPLOAD_PASSWORD);
	
	my $configuration_string;
	if (substr($configuration, length($configuration) - 3, length($configuration)) eq '.js') {
		$configuration_string = $configuration;
	} else {
		$configuration_string = $serverPath . "js/" . $configuration . '.js';
	}
		
	my $output = '

	<script language="javascript">
	  var VE_SERVER_PATH = "' . $serverPath . '";
	  var VE_LOAD_ALT = "' . $loadAlt . '";
	  var VE_HOSTNAME_PREFIX = "' . $VE_HOSTNAME_PREFIX . '";
	  var VE_KITVER = "' . $VE_KITVER . '";
	</script>

	<script language="javascript" src="' . $configuration_string . '"></script>
	<script language="javascript" src="' . $serverPath . 'js/' . 'Publisher.js"></script>';

	# Player.js is used for the SwapPlayer action where the VE_getPlayerHTML function is required.
	$output .= qq~
	<script language="javascript" src="~ . $serverPath . qq~js/Player.js"></script>~;

	$output .= qq~
	<script language="javascript">
	VE_JSEmbedPublisher('$authToken', '$VE_CLIENT_ID', '$filename', '$action', '$configuration', '$bgcolor', '$hidden', '$meta', '$username', '$destinationURL');
	</script>
	~;
    return $output;
}

sub VE_GenerateUploadAuthToken {
	my ($filename, $expireTime, $password) = @_;

	my $cookiename = "auth";
	my $ip = $ENV{'REMOTE_ADDR'};
	my $expires = $expireTime;
	my @access=($filename);	
	#$values = array();
	my $seed = $password;

	# cookiename  
	my %akacook;
	$akacook{cookiename}=$cookiename;


	# ip
	my @octets = split(/\./, $ip);
	my $octet0 = $octets[0];
	my $octet1 = $octets[1];
	my $octet2 = $octets[2];
	my $octet3 = $octets[3];	

	my (@values, @md5c);

	if(
           ($octet0 == 10) ||
           ($octet0 == 172 && $octet1 >= 16 && $octet1 <= 31) ||
	   ($octet0 == 192 && $octet1 == 168) ||
	   ($octet0 == 169 && $octet1 == 254) ||
	   ($octet0 == 127 && $octet1 == 0 && $octet2 == 0 && $octet3 == 1)) {
	     $ip = "";
	}

        #================================================================
        # 1.0.1 patch
        # temporary fix for AOL browser and Safari buffer issue
        #================================================================
        $ip = ""; # temporary fix for AOL browser and Safari buffer issue
        #================================================================
        # end patch
        #================================================================

	$akacook{ip}=($ip)?"ip=$ip":"";
	push @values, $akacook{ip} if $akacook{ip};
	push @md5c, $ip if $akacook{ip};
	$akacook{ip} = '';

	# expire
	$akacook{expire}="expires=$expires" if ($expires);
	push @values, $akacook{expire} if $akacook{expire};
	push @md5c, $expires if $akacook{expire};


	# access
	$akacook{access}="access=".(join"!",@access);
	push @values, $akacook{access} if ($#access>=0);
	push @md5c, (join"!",@access) if ($#access>=0);


	my $complete=join"~",@values;
	my $md5c=join"",@md5c;

	my $makemd5=$md5c.$seed;

	my $md5=Digest::MD5->new;
	$md5->reset;
	$md5->add($makemd5);
	my $hex_out=$md5->hexdigest;


	my $aka_cookie.="$akacook{cookiename}=$complete~md5=$hex_out";
	return $aka_cookie;
}
