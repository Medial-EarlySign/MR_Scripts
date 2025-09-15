package MedialUtils ;
use Exporter qw(import) ;

our @EXPORT_OK = qw(nim max hash_to_str open_file correct_path_for_condor get_days) ;

# min
sub min {
	my ($a, $b) = @_;
	
	return (($a < $b) ? $a : $b);
}

# max
sub max {
	my ($a, $b) = @_;
	
	return (($a > $b) ? $a : $b);
}

# format a simple hash as a string
sub hash_to_str {
    my ($h) = @_;

    my $res = "";
    map {$res .= $_ . " => " . $h->{$_} . "; ";} sort keys %$h;

    return $res;
}

# get a hash value for a key if exists and return a default value otherwise
sub safe_get_hash_val {
	my ($h, $key, $na_val) = @_;
	
	return ((exists $h->{$key}) ? $h->{$key} : $na_val);
}

# open file in requested mode and report in case of failure
sub open_file {
    my ($fn, $mode) = @_;
    my $fh;
    
#   print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode";

    return $fh;
}

# convert network path name formats in a Condor submission line, from Unix-like format(W:/path/to/file) 
# to Windows awkward style (\\\\server\\work\\path\\to\\file)
sub correct_path_for_condor {
	my $ltr2folder = {W => "Work", T => "Data", X => "Temp", 
					U => "UsersData", P => "Products",
					};
	my ($in_line) = @_ ;
	
	my $idx = 0 ;
	my $out_line ;
	my $inside = 0 ;
	
	while ($idx < length($in_line)) {
		if (not $inside) {
			for my $drive (qw(W T X U P)) {
				if (substr($in_line,$idx,3) eq  $drive . ":/") {
					die "Cannot parse $in_line" if ($inside) ;
					$out_line .= "\\\\server\\" . $ltr2folder->{$drive} . "\\" ;
					$inside = 1 ;
					$idx += 3 ;
					last;
				}
			}
			next if ($inside);
		}
		if (not $inside and substr($in_line,$idx,3) eq "H:/") {
			die "Cannot parse $in_line" if ($inside) ;
			my $user = `whoami` ;
			$user =~ s/\n$//; $user =~ s/\r$//;
			$out_line .= "\\\\server\\UsersData\\$user\\" ;
			$inside = 1 ;
			$idx += 3 ;	
			next;
		}
		if ($inside and substr($in_line,$idx,1) eq "/") {
			$out_line .= "\\" ;
			$idx ++ ;
		} else {
			$inside = 0 if (substr($in_line,$idx,1) =~ /\s|,/) ;
			$out_line .= substr($in_line,$idx,1) ;
			$idx ++ ;
		}
	}
	
	return $out_line ;
}

# days from January 1, 1900
my @days2month = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334) ;
sub get_days {
	my ($date) = @_;
		
	my $year = int($date / 100 / 100) ;
	my $month = ($date / 100) % 100 ;
	my $day = $date % 100 ;

	# full years
	my $days = 365 * ($year - 1900) ;
	$days += int(($year - 1897) / 4) ;
	$days -= int(($year - 1801) / 100) ;
	$days += int(($year - 1601) / 400) ;

	# full months
	$days += $days2month[$month - 1] ;
	$days += 1 if ($month > 2 && ($year % 4) == 0 and (($year % 100) != 0 or ($year % 400) == 0)) ;
	$days += ($day - 1) ;

	return $days;
}

# convert date format M/D/Y to YYYYMMDD
sub fmt_date {
	my ($str) = @_;
	
	my @D = split(/\//, $str);
	die "MedialUtils::fmt_date: Date string $str is not in M/D/Y format" unless (@D == 3);
	
	return sprintf("%04d%02d%02d", @D[2, 0, 1]);
}