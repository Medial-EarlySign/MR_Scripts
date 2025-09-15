#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my %stats ;

die "Usage : $0 ConfigurationFile outDir [-noMimic]" if (@ARGV !=2 and @ARGV != 3) ;
my ($confFile,$outDir,$noMimic) = @ARGV ;
die unless ($noMimic eq "" or $noMimic eq "-noMimic") ;

die "directory $outDir doesnot exist" unless (-e $outDir) ;
my $outFileHandle = FileHandle->new("$outDir/Summary","w") or die "Cannot open \'$outDir/Summary\' for writing" ;

my %inFiles ;
readConfFile($confFile,\%inFiles) ;

foreach my $inFile (@{$inFiles{SIGNAL}}) {
	my $inFileHandle = FileHandle->new($inFile,"r") or die "Cannot open $inFile for reading" ;
	print STDERR "Working on $inFile\n" ;

	my $prevId ;
	my @data ;
	my $header = 1;

	while (<$inFileHandle>) {
		if ($header) {
			$header = 0 ;
		} else {
			chomp ;
			my @line = split /\t/,$_ ;
			my $id = $line[0] ;
			if (defined $prevId and $id != $prevId) {
				collectData($prevId,\@data);
				@data = () ;
			} 
			
			$prevId = $id ;
			push @data,\@line ;
		}
	}

	collectData($prevId,\@data);
}

printStats($outFileHandle) ;

getAdmissionStats($inFiles{ADMISSION},$outFileHandle) if (exists $inFiles{ADMISSION});
getDemographicsStats($inFiles{DEMOGRAPHICS},$outFileHandle) if (exists $inFiles{DEMOGRAPHICS}) ;

printVecs($outDir) ;

#### Functions ####
sub getAdmissionStats {
	my ($files,$outFileHandle) = @_ ;

	my @admissionTimes ;
	my %admissionNums ;
	
	foreach my $inFile (@$files) {
		my $inFileHandle = FileHandle->new($inFile,"r") or die "Cannot open $inFile for reading" ;
		print STDERR "Working on $inFile\n" ;
		
		while (<$inFileHandle>) {
			chomp ;
			my ($id,$admissionId,$inTime,$lenDays,$lenHours,$outTime) = split /\t/,$_ ;
			
			$admissionNums{$id} ++ ;
			push @{$stats{admissionTimes}->{values}},$lenHours ;
		}
	}
	
	getStats($stats{admissionTimes}->{values},"AdmissionTimes","Values",$outFileHandle) ;
	
	push @{$stats{admissionNos}->{values}},values %admissionNums ;
	getStats($stats{admissionNos}->{values},"AdmissionNos","Values",$outFileHandle) ;
}
	
sub getDemographicsStats {
	my ($files,$outFileHandle) = @_ ;
	
	my @ages ;
	my %genders ;
	
	foreach my $inFile (@$files) {
		my $inFileHandle = FileHandle->new($inFile,"r") or die "Cannot open $inFile for reading" ;
		print STDERR "Working on $inFile\n" ;
		
		while (<$inFileHandle>) {
			chomp ;
			my ($id,$admissionId,$value,$units,$signal,$time) = split /\t/,$_ ;
			if ($signal eq "Age") {
				push @{$stats{Ages}->{values}},$value if ($value<120);
			} elsif ($signal eq "Gender") {
				$genders{$value} ++ ;
			}
		}
	}
	
	getStats($stats{Ages}->{values},"Ages","Values",$outFileHandle) ;
	
	map {$outFileHandle->print("Gender $_ n $genders{$_}\n")} keys %genders ;
}

sub readConfFile {
	my ($confFile,$inFiles) = @_ ;
	
	open (CNF,$confFile) or die "Cannot open $confFile for reading" ;
	while (<CNF>) {
		chomp ;
		my ($type,$name) = split ;
		push @{$inFiles{$type}},$name ;
	}
	close IN ;
}
	
sub printVecs {
	my ($outDir) = @_ ;
	
	foreach my $signal (keys %stats) {
		my $signalName = $signal ; 
		$signalName =~ s/\//_/g ;
		
		printVec($stats{$signal}->{values},"$outDir/Data.$signalName.Value") ;
		printVec($stats{$signal}->{deltas},"$outDir/Data.$signalName.time-gap") if (exists $stats{$signal}->{deltas}) ;
	}
}

sub printVec {
	my ($vec,$file) = @_ ;
	
	my $outFileHandle = FileHandle->new ($file,"w") or die "Cannot open \'$file\' for writing" ;
	map {$outFileHandle->print("$_\n")} @$vec ;
	$outFileHandle->close() ;
}
	
sub printStats {
	my ($outFileHandle) = @_ ;

	foreach my $signalName (keys %stats) {
		getStats($stats{$signalName}->{values},$signalName,"Values",$outFileHandle) ;
		getStats($stats{$signalName}->{deltas},$signalName,"time-gap",$outFileHandle) if (exists $stats{$signalName}->{deltas}) ;
	}
}

sub getStats {
	my ($vec,$name,$type,$outFileHandle) = @_ ;

	my %moments ;
	
	my @sorted = sort {$a<=>$b} @$vec ;	
	my $n = scalar @sorted ;
	
	$moments{n} = $n ;
	$moments{median} = $sorted[int(0.5*$n)] ;
	$moments{qunatile25} = $sorted[int(0.25*$n)] ;
	$moments{quantile75} = $sorted[int(0.75*$n)] ;
	$moments{quantile5}  = $sorted[int(0.05*$n)] ;
	$moments{quantile95} = $sorted[int(0.95*$n)] ;

	my ($s,$s2) ;
	foreach my $value (@sorted) {
		$s += $value ;
		$s2 += $value*$value ;
	}
		
	$moments{mean} = $s/$n ;
	$moments{sdv} = ($n<2) ? 0 : sqrt(($s2 - $s*$moments{mean})/($n-1)) ;

	map {$outFileHandle->print ("$name\t$type\t$_\t$moments{$_}\n")} qw/n mean sdv median quantile5 qunatile25 quantile75 quantile95/ ;
	$outFileHandle->print("\n") ;
}
	
sub getMinutes {
	my ($inTime) = @_ ;
	
	$inTime =~ /(\d\d)\/(\d\d)\/(\d\d\d\d) (\d\d):(\d\d):(\d\d)/ or die "Cannot parse time $inTime" ;
	my ($day,$month,$year,$hour,$minute,$second) ;
	my $days ;

	if ($noMimic eq "") {
		($day,$month,$year,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6) ;
		$days = 365 * ($year-2500) ;
	} else {
		($month,$day,$year,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6) ;
		$days = 365 * ($year-1900) ;
	}
	
	$days += int(($year-2497)/4) ;
	$days -= int(($year-2401)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	return ($days*24*60) + ($hour*60) + $minute + ($second/60) ;
}	
	
sub collectData {
	my ($id,$data) = @_ ;
	
	my %stays ;
	foreach my $rec (@$data) {
		my @line = @$rec ;
		$line[5] = getMinutes($line[5]) ;
		push @{$stays{$line[1]}},\@line ;
	}

	foreach my $stay (keys %stays) {
		my %prevMinutes  ;
		foreach my $rec (sort {$a->[5] <=> $b->[5]} @{$stays{$stay}}) {
			my ($id,$stayId,$signalName,$value,$unit,$minutes) = @$rec ;
			push @{$stats{$signalName}->{values}},$value ;
			push @{$stats{$signalName}->{deltas}},$minutes-$prevMinutes{$signalName} if (exists $prevMinutes{$signalName}) ;
			print "$signalName $id !\n" if (exists $prevMinutes{$signalName} and $minutes-$prevMinutes{$signalName}  > 60*24*30) ;
			$prevMinutes{$signalName} = $minutes ;
		}
	}
}