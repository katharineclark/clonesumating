package cache;
use DBI;
use Exporter;

@ISA    = qw(Exporter);
@EXPORT = qw(checkCache invalidateCache storeCache);

	$cacheDir = "/var/opt/consucache";

#warn $cacheDir;

sub checkCache {
	my ($file) = @_;

	if (-e "$cacheDir/$file") {

		#warn "Found cache for $file";
		open(IN,"$cacheDir/$file");
		$res = join("",<IN>);
		close(IN);
		return $res;

	} else {

		return "";
	}

}


sub invalidateCache {
	my ($file) = @_;
	
	if (-e "$cacheDir/$file") {

		#warn "Removing cache $file";
		unlink("$cacheDir/$file");
	}
}


sub storeCache {
	my ($file,$txt) = @_;

        invalidateCache($file);
	#warn "Storing cache $file";
	open(OUT,">$cacheDir/$file");
	print OUT $$txt;
	close(OUT);

}
