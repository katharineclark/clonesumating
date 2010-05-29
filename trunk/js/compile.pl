#!/usr/bin/perl


@files = ("xmlhttp.js","infoBox.js","peoplecart.js","cardtools.js","corners.js","tips.js");

open(OUT,"> compiled.js") or die "Can't open complied.js! $!";
`chmod 666 compiled.js`;
	
	foreach $file (@files) {

		open(IN,"$file") or die "can't open file $file: $!";
		$txt = join("",<IN>);
		print OUT "\n\n// IMPORTED FROM $file\n\n" or die "can't write file $file: $!";
		print OUT $txt or die "can't write file $file: $!";
		close IN or die "can't close file $file: $!";
	}
close OUT;

