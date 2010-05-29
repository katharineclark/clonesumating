package bbDates;
use Exporter;

@ISA    = qw(Exporter);
@EXPORT = qw(monthSelect yearSelect daySelect @months @weekdays);


@months = ("January","February","March","April","May","June","July","August","September","October","November","December");
#@years = ("2003","2004","2005");
$curYear = 2003;
$topYear = 2005;

@weekdays = ("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday");

sub monthSelect {
	my ($curmonth) = @_;

	my ($st,$i);
	$curmonth =~ s/^0//gs;	

	foreach $i (0 .. $#months) {

                     $val = ($i + 1); 
		if ($i == $curmonth -1) {
			$st .= qq|<option value="$val" selected>$months[$i]</option>\n|;
		} else {
			$st .= qq|<option value="$val">$months[$i]</option>\n|;
		}


	}

	return $st;

}


sub daySelect {
        my ($curday) = @_;   
 

        my ($st,$i);
        $curmday =~ s/^0//gs;
        
        foreach $i (1 .. 31) {
        
                if ($i == $curday) {
                        $st .= qq|<option value="$i" selected>$i</option>\n|;
                } else {
                        $st .= qq|<option value="$i">$i</option>\n|;
                }
        
        
        }
        
        return $st;
 
}

sub yearSelect {
        my ($curyear,$startYear,$endYear) = @_;   

	if (!$startYear) {
		$startYear = $curYear;
	}
	if (!$endYear) {
		$endYear = $curYear;
	}

	foreach $y ($startYear .. $endYear) {

			push(@years,$y);
	}
 

        my ($st,$i);
        $curyear =~ s/^0//gs;
        
        foreach $i (0 .. $#years) {

                        $val = $years[$i];
        
                if ($years[$i] == $curyear) {
                
                        $st .= qq|<option value="$val" selected>$years[$i]</option>\n|;
                } else {
                        $st .= qq|<option value="$val">$years[$i]</option>\n|;
                }
        
        
        }
        
        return $st;
 
}
