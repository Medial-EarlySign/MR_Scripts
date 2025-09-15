#!/usr/bin/env perl 

# A script for finding enriched entries in THIN

use strict(vars);
use Getopt::Long;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my %stages = (parse_files => 1, score => 2, parse_results => 3) ;
my $p = {
		ID2NR => "ID2NR",
		dir => "W:/CRC/THIN/IndividualData",
		years => "Years",
		gap => 30,
		period => 999*365,
		start => "parse_files",
		counts_file => "W:/Users/Yaron/LUCA/Restart/Fisher/Counts",
		fdr_file => "W:/Users/Yaron/LUCA/Restart/Fisher/FDRs",
		final_file => "W:/Users/Yaron/LUCA/Restart/Fisher/FinalOut",
		in_r_script => "W:/Users/Yaron/LUCA/Restart/Fisher/fisher_test.r",
		out_r_script => "W:/Users/Yaron/LUCA/Restart/Fisher/temp_fisher_test.r",
        };

GetOptions($p,
        "cases=s",         # List of Cases (with Dates)
		"controls=s",	   # List of Controls
		"ID2NR=s",		   # ID2NR File
		"dir=s",		   # THIN Files Directory
		"gap=i",		   # Safety period prior to registry
		"period=i",		   # Past Period to consider
		"years=i",		   # File with birth and last years
		"start=s",		   # Start stage (parse_files/score/parse_results)
		"counts_file=s",   # Intermediate file of counts
		"fdr_file=s",	   # Intermediate file of fdrs
		"final_file=s",	   # Final output file
		"in_r_script=s",   # Template for R script
		"out_r_script=s",  # R script
        );
		
map {die "Missing param $_" if (! exists $p->{$_})} qw/cases controls/ ;		
map {print STDERR "Running param $_ : $p->{$_}\n"} keys %$p ;	
die "Unkonwn start-stage $p->{start}" if (! exists $stages{$p->{start}}) ;	
my $start = $stages{$p->{start}};

# Collect all THIN counts
if ($start <= 1) {
	# Output File
	open (OUT,">".$p->{counts_file}) or die "Cannot open ".($p->{counts_file})." for writing" ;
	
	# Read ID2NR
	open (ID,$p->{ID2NR}) or die "Cannot open $p->{ID2NR} for reading" ;

	my %nr2id ;
	while (<ID>) {
		chomp ;
		my ($id,$nr) = split ;
		$nr2id{$nr} = $id ;
	}
	close ID ;

	# Read MaxAge
	open (MA,$p->{years}) or die "Cannot open $p->{years} for reading" ;

	my %years ;
	while (<MA>) {
		chomp ;
		my ($id,$first_year,$last_year) = split ;
		$years{$id} = [$first_year,$last_year] ;
	}
	close MA ;

	# Read Cases
	open (CS,$p->{cases}) or die "Cannot open $p->{cases} for reading" ;

	my %cases ;
	while (<CS>) {
		chomp ;
		my ($id,$date) = split ;
		$cases{$id} = $date if (!exists $cases{$id} or $date < $cases{$id}) ;
	}
	close CS ;
	my $ncases = scalar keys %cases ;
	print STDERR "Read $ncases cases\n" ;

	# Loop on Files
	my %data ;
	my %fields ;
	my %case_ages ;

	my $idx = 1 ;
	foreach my $nr (keys %cases) {
		die "Cannot find id for $nr" unless (exists $nr2id{$nr}) ;
		my $id = $nr2id{$nr} ;
		my $dir = substr($id,0,5) ;
		my $file = "$p->{dir}/$dir/$nr" ;
		
		print STDERR "Reading $idx/$ncases : $file" ;
		
		my $target_day = get_days($cases{$nr}) ;
		my $target_year = int($cases{$nr}/10000) ;
		my $age = $target_year - $years{$nr}->[0] ;

		if ($age <= 80) {
			$case_ages{$age} ++ ;
			read_file(\%data,$nr,$file,$target_day,$p->{gap},$p->{period}) ;
			map {$fields{$_} = 1} keys %{$data{$nr}->{entries}} ;
		}
		
		print STDERR "\r" ;
		$idx ++ ;
	}
	print STDERR "\nDone loading data for cases\n" ;

	# Read Controls
	open (CT,$p->{controls}) or die "Cannot open $p->{controls} for reading" ;

	my @controls ;
	while (<CT>) {
		chomp ;
		push @controls,$_ ;
	}
	close CT ;
	my $nctrls = scalar @controls ;
	print STDERR "Read $nctrls controls\n" ;

	# Match
	my $target_ratio = $nctrls/$ncases ;
	print STDERR "Target Ratio = $target_ratio\n" ;

	my @case_ages = sort {$b<=>$a} keys %case_ages ;
	my %selected ;

	my $done = 0 ;
	while (! $done) {
		%selected = () ;
		$done = 1 ;
		
		for my $age (@case_ages) {
			my $ntarget = int($target_ratio * $case_ages{$age}) ;
			my @candidates = grep {(! exists $selected{$_}) and ($years{$_}->[1] - $years{$_}->[0] >= $age)} @controls ;
			my $ncandidates = scalar @candidates ;
			
			if ($ncandidates < $ntarget) {
				$target_ratio = $ncandidates/$case_ages{$age} ;
				print STDERR "Not enough candidates at age $age : Required $ntarget. Found $ncandidates. Changing target-ratio to $target_ratio\n" ;
				$done = 0 ;
				last ;
			}
			
			for my $i (1..$ntarget) {
				my $idx = int(rand($ncandidates+1-$i)) ;
				$selected{$candidates[$idx]} = $age ;
				$candidates[$idx] = $candidates[-1] ;
				pop @candidates ;
			}
			
			print STDERR "Selected $ntarget out of $ncandidates for age $age\n" ;
		}
	}

	# Loop on Control Files
	my %control_data ;
	$nctrls = scalar keys %selected ;

	$idx = 1 ;
	foreach my $nr (keys %selected) {
		die "Cannot find id for $nr" unless (exists $nr2id{$nr}) ;
		my $id = $nr2id{$nr} ;
		my $dir = substr($id,0,5) ;
		my $file = "$p->{dir}/$dir/$nr" ;
		
		print STDERR "Reading $idx/$nctrls : $file" ;
		
		my $target_year = $years{$nr}->[0] + $selected{$nr} ;
		my $target_day = get_days($target_year."0101") ;

		read_file(\%control_data,$nr,$file,$target_day,$p->{gap},$p->{period}) ;
		
		print STDERR "\r" ;
		$idx ++ ;
	}
	print STDERR "\nDone loading data for controls\n" ;

	# Print
	my @case_nrs = keys %data ;
	my $tot_case_count = scalar @case_nrs ;
	my @ctrl_nrs = keys %control_data ;
	my $tot_ctrl_count = scalar @ctrl_nrs ;

	foreach my $field (keys %fields) {
		my $case_count = scalar (grep {exists $data{$_}->{entries}->{$field}} @case_nrs) ;
		my $ctrl_count = scalar (grep {exists $control_data{$_}->{entries}->{$field}} @ctrl_nrs) ;
		
		print OUT "$field\t$tot_case_count\t$case_count\t$tot_ctrl_count\t$ctrl_count\n" ;
	}	
	close OUT ;
}

# Fisher Exact Test + False Discovery rate
if ($start <= 2) {
	# Create the script
	my $in = $p->{in_r_script} ;
	my $out = $p->{out_r_script} ;
	
	open (IN,$in) or die "Cannot open $in for reading"  ;
	open (OUT,">$out") or die "Cannot open $out for writing" ;
	
	while (<IN>) {
		s/COUNTS_FILE_NAME/$p->{counts_file}/ ;
		s/FDR_FILE_NAME/$p->{fdr_file}/ ;
		print OUT $_ ;
	}
	close IN ;
	close OUT ;
	
	# Run the script
	system("R CMD BATCH --silent --no_timing $p->{out_r_script}") == 0 or die "R script failed\n" ;
}

# Parse
if ($start <= 3) {
	open (OUT,">$p->{final_file}") or die "Cannot open $p->{file_file} for writing" ;
	
	# Read Scores
	open (IN,$p->{fdr_file}) or die "Cannot open $p->{fdr_file} for reading" ;
	
	my $nlines = 0 ;
	my (@names,@p_values) ;
	while (<IN>) {
		chomp ;
		if ($nlines%2 == 0) {
			push @names,split ;
		} else {
			push @p_values,split ;
		}
		$nlines ++ ;
	}
	my $n1 = scalar @names ;
	my $n2 = scalar @p_values ;
	die "Mismatch at fdr file ($n1 != $n2)" if ($n1 != $n2) ;
		
	print STDERR "Read $n1 significant codes\n" ;	
	close IN ;
	
	# Read Counts
	open (CNT,$p->{counts_file}) or die "Cannot open $p->{counts_file} for reading" ;
	my %counts ;
	while (<CNT>) {
		chomp ;
		my ($code,@counts) = split ;
		$counts{$code} = join "\t",@counts ;
	}
	close CNT ;
	
	# Read read-codes
	my $readcodes = "T:\\THIN\\EPIC 65\\Ancil 1205\\Readcodes1205.txt";
	open (RC,$readcodes) or die "Cannot open $readcodes for reading" ;

	my %readcodes ;
	while (<RC>) {
		chomp ;
		my $code = substr($_,0,7) ; $code =~ s/^s\s+//g ; $code =~ s/\s+$//g ;
		my $desc = substr($_,7,60) ; $desc =~ s/^s\s+//g ; $desc =~ s/\s+$//g ;
		$readcodes{$code} = $desc ;
	}
	close RC ;

	# Read drug-codes
	my $readcodes = "T:\\THIN\\EPIC 65\\Ancil 1205\\Drugcodes1205.txt";
	open (RC,$readcodes) or die "Cannot open $readcodes for reading" ;

	my %drugcodes ;
	while (<RC>) {
		chomp ;
		my $code = substr($_,0,8) ; $code =~ s/^s\s+//g ; $code =~ s/\s+$//g ;
		my $desc = substr($_,41,120) ; $desc =~ s/^s\s+//g ; $desc =~ s/\s+$//g ;
		$drugcodes{$code} = $desc ;
	}
	close RC ;

	# Read AHD-codes
	my $ahdcodes = "W:\\CRC\\THIN\\IndividualData\\AHDCodes.txt" ;
	open (AC,$ahdcodes) or die "Cannot open $ahdcodes for reading" ;

	my %ahdcodes ;
	while (<AC>) {
		chomp ;
		my ($file,$code,$desc,@fields) = split /\t/,$_ ;
		$ahdcodes{$code} = {desc => $desc, fields => \@fields} ;
	}
	close AC ;

	# Read AHD-lookups
	my $ahdlookup = "W:\\CRC\\THIN\\IndividualData\\AHDlookups.txt" ;
	open (AL,$ahdlookup) or die "Cannot open $ahdlookup for reading" ;

	my %ahdlookup ;
	while (<AL>) {
		chomp ;
		my ($name,$desc,$key,$val) = split /\t/,$_ ;
		$ahdlookup{$desc}->{$key} = $val ;
	}
	close AL;

	# Read Lookups
	my $lookup = "T:\\THIN\\EPIC 65\\Ancil 1205\\THINLookups.txt" ;
	open (LP,$lookup) or die "Cannot open $lookup for reading" ;

	my %lookup ;
	while (<LP>) {
		chomp ;
		my $table = substr($_,0,10) ; $table =~ s/^\s+//g ; $table =~ s/\s+$//g ;
		my $key = substr($_,10,3) ; $key =~ s/^\s+//g ; $key =~ s/\s+$//g ;
		my $val = substr($_,13,256) ; $val =~ s/^\s+//g ; $val =~ s/\s+$//g ;

		$lookup{$table}->{$key} = $val ;
	}
	close LP ;
	
	# Parse
	for my $i (0..($n1-1)) {
		my $name = $names[$i] ;
		die "Cannot find counts for $name" if (!exists $counts{$name}) ;
		
		my $desc = "UnKnown" ;
		if ($name =~ /MED.(\S+)/) {
			if (! exists $readcodes{$1}) {
				print STDERR "Unknown MedCode $1" ;
			} else {
				$desc = $readcodes{$1};
			}
		} elsif ($name =~ /THE.(\S+)/) {
			if (! exists $drugcodes{$1}) {
				print STDERR "Unknown DrugCode $1" ;
			} else {
				$desc = $drugcodes{$1} ;	
			}
		} elsif ($name =~ /AHD.(\S+)/) {
			if (! exists $ahdcodes{$1}) {
				print STDERR "Unknown AhdCode $1" ;
			} else {
				$desc = $ahdcodes{$1}->{desc} ;	
			}
		} else {
			die "Cannot parse $name" ;
		}
		print OUT "$p_values[$i]\t$counts{$name}\t$desc\n" ;
	}
		
}

# FUNCTIONS

sub read_file {
	my ($data,$nr,$file,$target_day,$gap,$period) = @_ ;
	
	open (EMR,$file) or die "Cannot open $file for reading" ;
	while (<EMR>) {
		if (/^NR/) {
			/NR (\d+)\s+ID (\S+)\s+(\S+)/ or die "\nCannot parse $_" ;
			my ($inr,$iid,$info) = ($1,$2,$3) ;
	
			my @info = split ",",$info ;
			$data->{$nr}->{yob} = $info[1] ;
			$data->{$nr}->{sex} = $info[3] ;
		} else {
			my ($date,$type,$info) = split /\t/,$_ ;
			my $days = get_days($date) ;
			next if ($days > $target_day - $gap) ;
			
			if ($days > $target_day - $period) {
				my @info = split ",",$info ;
				my $entry ;
				if ($type eq "MED") {	
					$entry = "MED.$info[2]" ;
				} elsif ($type eq "THE" or $type eq "AHD") {
					$entry = "$type.$info[0]" ;
				}
				
				$data->{$nr}->{entries}->{$entry}++ ;
			}
		}
	}
	close EMR ;
}

sub get_days {
	my $date = shift @_ ;

	my $year = int ($date/100/100) ;
	my $month = int (($date % (100*100))/100) ;
	my $day = ($date % 100) ;
	
	my $days = 365 * ($year-1900) ;
	$days += int(($year-1897)/4) ;
	$days -= int(($year-1801)/100);
	$days += int(($year-1601)/400) ;

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	return $days ;
}	