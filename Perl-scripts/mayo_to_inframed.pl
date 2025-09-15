#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

use Scalar::Util qw(looks_like_number) ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

die "Usage : $0 ConfigFile" if (@ARGV != 1) ;
my ($configFile) = @ARGV ;

# Global Parameters
my @dataSFiles ;
my @dataNFiles = qw/Fluids_N/ ;
my @dataFiles = (@dataNFiles,@dataSFiles) ;
my @signalTypes = qw/T_Value T_DateVal T_TimeVal T_DateRangeVal T_TimeStamp T_TimeRangeVal T_DateVal2 T_TimeLongVal/ ;

my %config ;
my %allData = (dictIndex => 0) ;
my %resolutions ;
my (%origUnits,%units,%extraUnitConversion) ;
my %reader ;


my $maxTime = transformTime("12/31/9999 23:59:00 PM") ;

my $logFH ;
my $maxId = 20000 ;

# Read Config File
readConfig($configFile) ;

# Required keys
my @reqKeys = qw/OutDir OutPrefix IdsFile LogFile UnitsFile/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

# Open Log File
$logFH = FileHandle->new($config{LogFile},"w") or die "Cannot open log file $config{LogFile} for writing" ;

# Init
my %fileIds = map {($dataFiles[$_] => $_)} (0..$#dataFiles) ;
my %signalTypes = map {$signalTypes[$_] => $_} (0..$#signalTypes) ;

openOutFiles(\%allData) ;
prepareSignalInfo(\%allData) ;
readResolutions() ;
readUnits() ;

@reqKeys = qw/FluidInstructions/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

my %fluidInstructions ;
readInstructions($config{FluidInstructions},\%fluidInstructions) ;

# Read Ids To handle
my @ids ;

readIdsList($config{IdsFile},\@ids) ;

$allData{SignalValuesPerStay} = {} ;

# LOOP ON IDS
my $idx = 0 ;
foreach my $id (@ids) {
	
	$idx++ ;
	print STDERR "$idx : $id" ;
	
	my %idData ;
	my $dir = $config{DataDir} ;
	
	# Fluids
	doFluids($dir,$id,\%idData,\%allData) ;

	# Print Data
	printData(\%idData,\%allData) ;
		
	print STDERR "\r" ;
}

# Values Counter
handleValuesCounter(\%allData) ;

# Create configuration file for conversion
createConvertConfig(\%allData) ;

# Create general output file
printCollectiveData(\%allData) ;

# Final sorting of files
closeOutFiles(\%allData) ;
sortOutFiles() ;


print STDERR "\nDone\n" ;

######################################
## Function							##
######################################

# Read Configuration file
sub readConfig {
	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open \'$file\' for reading" ;
	
	while (my $line = <IN>) {
		chomp $line ;
		
		next if ($line eq "" or $line =~ /^#/) ;
		
		$line =~ s/^\s+// ;
		$line =~ s/\s+$// ;
		
		my @line = split /\s*:=\s*/,$line ;
		die "Cannot parse \'$line\'" if (@line != 2) ;
		
		my $key = shift @line ;
		die "Illegal variable \'$key\' in \'$line\'" if ($key =~ /\$/) ;
		die "Redifinition of variable \'$key\' in \'$line\'" if (exists $config{$key}) ;

		my $value = shift @line ;
		while ($value =~ /\$\{(\S+?)\}/) {
			die "Unknown Reference to key \$\{$1\}" if (! exists $config{$1}) ;
			$value =~ s/\$\{(\S+?)\}/$config{$1}/ ;
		}

		$config{$key} = $value ;
	}

	return;
}
	
# Read resolutions
sub readResolutions {

	my $file = $config{Resolution} ;
	open (IN,$file) or die "Cannot open $file for reading" ;
	
	while (<IN>) {
		chomp ;
		my ($signal,$resolution) = split ;
		$resolutions{$signal} = $resolution ;
	}
	close IN;
}

# Read Ids
sub readIdsList {
	my ($file,$ids) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id) = split ;
		push @$ids,$id ;
	}
	
	my $nids = scalar @$ids ;
	print STDERR "Read $nids IDs\n\n" ;
	
	return ;
}
	
# Utility: is a flag on ?
sub flagOn {
	my ($value) = @_ ;
	
	return (uc($value) eq "Y" or uc($value) eq "YES") ;
}


# Handle IO Events
sub doFluids {
	my ($dir,$inId,$idData,$allData) = @_ ;
	
	my ($lines,$header) = readLines($dir,"FluidsData",$inId) ;
	
	my %events ;	
	foreach my $line (@$lines) {
		my @rec = @$line ;

		my $id = $rec[$header->{"Case N"}] ;
		my $family = $rec[$header->{familydescription}] ;
		my $name = $rec[$header->{genericname}] ;
		my $item = "$family.$name" ;
		
		if (exists $fluidInstructions{$family}->{$name}) {
			my $time = transformTime($rec[$header->{donedate_DI}]) ;
			push @{$events{$item}},[$time,$line] ;
		}
	}

	foreach my $item (keys %events) {
		
		my $prevTime = -1 ;
		my @lines = map {$_->[1]} sort {$a->[0] <=> $b->[0]} @{$events{$item}} ;
		
		foreach my $line (@lines) {
			my @rec = @$line ;
			my $time = transformTime($rec[$header->{donedate_DI}]) ;
			my $family = $rec[$header->{familydescription}] ;
			my $name = $rec[$header->{genericname}] ;				
			
			my $signalName = $fluidInstructions{$family}->{$name}->{name} ;
			my $unit = lc($rec[$header->{unitsymbol}]) ;
			if ($unit =~ /\/(min|day|h)/) {
				$signalName .= "-k" if ($unit =~ /\/kg\//) ;
				$signalName .= "_Rate" ;
			}
			
#			print "\n@rec !!\n"  if ($signalName eq "INPUT-k_Rate") ;
			
			my $stat = $rec[$header->{taskstatusdescription}] ;
			my $val1 = $rec[$header->{dosen}] ;
			my $val2 = $rec[$header->{dosec}] ;
				
			if ($stat eq "Done" or $stat eq "Modified" or ($signalName =~/_Rate/ and ($stat eq "Connect" or $stat eq "New bag"))) {

				if (abs($val1 - $val2) > 0.001) {
					$logFH->print("Fluids: Signal $signalName has values mismatch at $inId/$time : $val1/$val2\n") ;
				} elsif ($val1 eq "") {
					$logFH->print("Fluids: Signal $signalName has no value at $inId/$time\n") ;
				} else {
					if (!exists $units{$signalName}->{$unit}) {
						my @units = keys %{$units{$signalName}} ;
						$logFH->print("Fluids: Cannot analyze unit \'$unit\' for $signalName at $inId/$time ($rec[$header->{donedate_DI}]) (@units)\n") ;
					} else {
						my $value = $val2*$units{$signalName}->{$unit} ;
						# Rate ?
						if ($signalName =~ /_Rate/) {
							push @{$idData->{data}->{$inId}->{Fluids_N}},[$signalName,$time,$value] ;
						} else {
							push @{$idData->{data}->{$inId}->{Fluids_N}},[$signalName,$prevTime,$time,$value] ;
						}
					}
				}
			} else {
				$logFH->print("Fluids: Signal $signalName has status $stat at $inId/$time [$val1/$val2]\n") ;
			}
			$prevTime = $time ;
		}
	}
}

# Handle resolutions issues
sub fixResolution {
	my ($signal,$value) = @_ ;
	
	die "Cannot find Resolutsion for $signal" if (! exists $resolutions{$signal}) ;
	my $bin = int ($value/$resolutions{$signal} + 0.5) ;
	$value = sprintf("%.3f",$bin * $resolutions{$signal}) ;
	
	return $value ;
}

# Read Instructions
sub readInstructions {
	my ($file,$instructions) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($family,$generic,$type,$name) = split /\t/,$_ ;
		$instructions->{$family}->{$generic} = {type => $type, name => $name} ;
		die "Unknown signal type \'$type\' at \'$_\'" if ($type ne "VALUE" and $type ne "TEXT") ;
	}
	
	close IN ;
}

# Read Signals units and conversions
sub readUnits {

	my $file = $config{UnitsFile} ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		next if (/^#/) ;
		s/\r// ; 
		
		chomp ;
		my ($signal,$unit,$factor,$extra) = split /\t/,$_ ;
		$signal = $1."-k_Rate" if ($unit =~ /\/kg\// and $signal =~ /(\S+)_Rate/) ;
		
		$unit = lc($unit) ;
		$units{$signal}->{$unit} = $factor ;

		if (defined $extra and $extra ne "" and $extra !~ /^#/) {
			if ($extra =~ /^:\S+/ or $extra eq "Fahrenheit2Celsius") {
				$extraUnitConversion{$signal}->{$unit} = $extra ;
			} else {
				die "Unknown extra conversion $extra for $signal/$unit" ;
			}
		}
		$origUnits{$signal} = $unit if ($factor == 1 and ! exists $origUnits{$signal}) ;
	}
	
	close IN ;
}

# Read values dictionary
sub readNonNumericValues {
	my ($file,$instructions,$dict) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($signal,$desc,$value) = split /\t/,$_ ;
		$dict->{$signal}->{lc($desc)} = $value ;
	}
	
	foreach my $code (keys %$instructions) {
		if ($instructions->{$code}->{type} eq "VALUE") {
			$dict->{$instructions->{$code}->{name}}->{none} = 0 ;
			$dict->{$instructions->{$code}->{name}}->{neg} = 0 ;
		}
	}
	
	close IN ;
}

sub transformTime{
	my ($time) = @_ ;

	$time =~ /(\d\d)\/(\d\d)\/(\d\d\d\d) (\d+):(\d\d):(\d\d) (AM|PM)/ or die "Illegal time format for $time" ;
	my ($mo,$dy,$yr,$hr,$min,$sec,$ampm)=($1,$2,$3,$4,$5,$6,$7);
	$hr += 12 if ($ampm eq "PM") ;
	
	my $newTime = sprintf("%4d%02d%02d%02d%02d%02d",$yr,$mo,$dy,$hr,$min,$sec) ;
	
	return getMinutes($newTime) ;
	
}

sub transformDate {
	my ($date) = @_ ;
	
	$date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ or die "Illegal date format for $date" ;
	my $time = sprintf("%4d%02d%02d%02d%02d%02d",$1,$2,$3,23,59,59) ;
	
	return getMinutes($time) ;
	
}

# Create files for conversion
sub createConvertConfig() {
	my ($allData) = @_  ;
	
	my @reqKeys = qw/OutDir OutPrefix/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
	
	my $dir = $config{OutDir} ;
	my $prefix = $config{OutPrefix} ;
	
	# Config File
	my $outConfigFile = "$dir/$prefix.convert_config" ;
	open (OUT,">$outConfigFile") or die "Cannot open $outConfigFile for writing";
	
	print OUT "DESCRIPTION\t$config{Description}\n" if (exists $config{Description}) ;
	print OUT "DIR\t$dir\n" ;
	print OUT "OUTDIR\t$dir\n" ;
	print OUT "CONFIG\t$prefix.repository\n" ;
	print OUT "DICTIONARY\t$prefix.dictionary\n" ;
	print OUT "DICTIONARY\t$prefix.microbiology_dictionary\n" ;
	print OUT "DICTIONARY\t$prefix.sets_dictionary\n" ;
	print OUT "CODES\t$prefix.codes_to_signal_names\n" ;
	print OUT "FNAMES\t$prefix.fnames_prefix\n" ;
	print OUT "SIGNAL\t$prefix.signals\n" ;
	print OUT "SFILES\t$prefix.signals_to_files\n" ;

	map {print OUT "DATA\t$prefix.$_\n"} @dataNFiles;
	map {print OUT "DATA_S\t$prefix.$_\n"} @dataSFiles ;
	
	close OUT ;
	
	# Find valid signals
	my %validSignals = map {$_ => 1} grep {exists $allData->{signalFlags}->{$_}} keys %{$allData->{signals}} ;
	
	# Dictionary	
	my $outSetFile = "$dir/$prefix.microbiology_dictionary" ;
	open (OUT,">$outSetFile") or die "Cannot open $outSetFile for writing";	
	foreach my $entry (keys %{$allData->{mbDict}}) {
		my $id = $allData->{mbDict}->{$entry} ;
		print OUT "DEF\t$id\t$entry\n" ;
	}
	close OUT ;	
	
	my $outDictFile = "$dir/$prefix.dictionary" ;
	open (OUT,">$outDictFile") or die "Cannot open $outDictFile for writing";	
	foreach my $entry (keys %{$allData->{dict}}) {
		my $id = $allData->{dict}->{$entry} ;
		next if (exists $allData->{signals}->{$entry} and not exists  $validSignals{$entry}) ; # Remove missing signals from dictionary
		print OUT "DEF\t$id\t$entry\n" ;
	}
	close OUT ;
		
	my $outSetFile = "$dir/$prefix.sets_dictionary" ;
	open (OUT,">$outSetFile") or die "Cannot open $outSetFile for writing";	
	foreach my $set (keys %{$allData->{dictSets}}) {
		print OUT "DEF\t".($allData->{dictIndex}++)."\t$set\n" ;
		foreach my $value (@{$allData->{dictSets}->{$set}}) {
			next if (exists $allData->{signals}->{$value} and not exists  $validSignals{$value}) ; # Remove missing signals from dictionary
			print OUT "SET\t$set\t$value\n" ;
		}
	}

	
	foreach my $signal (keys %{$allData->{SignalValues}}) {
		my $set = "$signal\_Values" ;
		print OUT "DEF\t".($allData->{dictIndex}++)."\t$set\n" ;
		map {print OUT "SET\t$set\t$_\n"} keys %{$allData->{SignalValues}->{$signal}} ;
	}

	close OUT ;

	# Filter signals
	map {delete $allData->{signals}->{$_} if (! exists $validSignals{$_})} keys %{$allData->{signals}} ;	
	
	# Signals
	my $outSignalsFile = "$dir/$prefix.signals" ;
	open (OUT,">$outSignalsFile") or die "Cannot open $outSignalsFile for writing";
		
	foreach my $signal (keys %{$allData->{signals}}) {
		die "Signal $signal not in dictionary" if (! exists $allData->{dict}->{$signal}) ;
		my $line = join "\t",("SIGNAL",$signal,$allData->{dict}->{$signal},$allData->{signals}->{$signal}->{signalType}) ;
		print OUT "$line\n" ;
	}
	close OUT ;
	
	# Codes File
	my $outCodesFile = "$dir/$prefix.codes_to_signal_names" ;
	open (OUT,">$outCodesFile") or die "Cannot open $outCodesFile for writing";
	
	map {print OUT $allData->{signals}->{$_}->{code}."\t$_\n"} (keys %{$allData->{signals}}) ;
	close OUT ;
	
	# Files File
	my $outFileNamesFile = "$dir/$prefix.fnames_prefix" ;
	open (OUT,">$outFileNamesFile") or die "Cannot open $outFileNamesFile for writing";
	
	map {print OUT "$fileIds{$_}\t$_\n"} sort {$fileIds{$a} <=> $fileIds{$b}} keys %fileIds ;
	close OUT ;
	
	# Signals to files
	my $outSignalToFilesFile = "$dir/$prefix.signals_to_files" ;
	open (OUT,">$outSignalToFilesFile") or die "Cannot open $outSignalToFilesFile for writing";
	
	map {print OUT $allData->{signals}->{$_}->{sfiles}."\t$_\n"} sort {$allData->{signals}->{$a}->{sfiles} <=> $allData->{signals}->{$b}->{sfiles}}
																	keys %{$allData->{signals}} ;
	close OUT ;
}

# Get Minutes
sub getMinutes {
	my ($InTime) = @_ ;
	
	$InTime =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/ or die "Cannot parse time $InTime" ;
	my ($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6) ;
	
	my $baseYear = 2000 ;
	
	my $days = 365 * ($year-$baseYear) ;
	$days += int(($year-($baseYear-3))/4) ;
	$days -= int(($year-($baseYear-99))/100); 
	$days += int(($year-($baseYear-399))/400); 
	
	$days += $days2month[$month-1.0] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	
	$minute ++ if ($second > 30) ;

	return ($days*24*60) + ($hour*60) + $minute ;
}	

# Update data files
sub updateData {
	my ($idData,$allData) = @_ ;

	if (exists $idData->{data}->{MISSING}) {
		for my $type (/LabEvents_N LabEvents_S ChartEvents_N ChartEvents_S IOEvents_N IOEvents_S MedEvents_N PoeOrder_N/) {
			if (exists $idData->{data}->{MISSING}->{$type}) {
			
				foreach my $rec (@{$idData->{data}->{MISSING}->{$type}}) {
					my $signalName = $rec->[0] ;
					my $signalType = $allData->{signals}->{$signalName}->{signalType} ;
				
					my $stayID ;
					if ($signalType == $signalTypes{"T_TimeVal"}) {
						my ($from,$to) = ($rec->[1],$rec->[1]) ;
						$stayID = getStay($idData,$from,$to,) ;
					} elsif ($signalType == $signalTypes{"T_TimeRangeVal"}) {
						my ($from,$to) = ($rec->[1],$rec->[2]) ;
						$stayID = getStay($idData,$from,$to) ;
					} elsif ($signalType == $signalTypes{"T_TimeStamp"}) {
						my ($from,$to) = ($rec->[1],$rec->[1]) ;
						$stayID = getStay($idData,$from,$to) ;
					} else {
						die "Cannot handle signal type $signalType in post-processing" ;
					}
				}
			}
		}
		delete $idData->{data}->{MISSING} ;
	}
}
	
# Add to dictionary
sub addToDict {
	my ($allData,$entry,$type) = @_ ;

	$allData->{dict}->{$entry} = $allData->{dictIndex}++ ;
	push @{$allData->{dictSets}->{$type}},$entry if ($type ne "");
}

# Add to list of values per signal
sub addToSignalValues{
	my ($allData,$signal,$value) = @_ ;
	$allData->{SignalValues}->{$signal}->{$value} = 1 ;
}

# Open/Close Output Files
sub openOutFiles {
	my ($allData) = @_ ;
	
	foreach my $file (@dataFiles) {
		$allData->{files}->{$file} = FileHandle->new($config{OutDir}."/".$config{OutPrefix}.".".$file,"w") or die "Cannot open output $file" ;
	}
	
	$allData{signalInfoFile} = FileHandle->new($config{OutDir}."/SignalInfoFile","w") or die "Cannot open output file SignalInfoFile" ;
}

sub closeOutFiles {
	my ($allData) = @_ ;

	map {$allData->{files}->{$_}->close()} keys %{$allData->{files}} ;
	$allData{signalInfoFile}->close() ;
}

# Sort Output Files
sub sortOutFiles {
	foreach my $file (@dataFiles) {
		my $fileName = $config{OutDir}."/".$config{OutPrefix}.".".$file ;
		my $tempFileName = $config{OutDir}."/TemporaryFileForSorting" ;
		
		my $command = "sort -nk1 -S50% $fileName -o $tempFileName" ;
		(system($command) == 0 or die "\'$command\' Failed" ) ;
		
		$command = "mv $tempFileName $fileName" ;
		(system($command) == 0 or die "\'$command\' Failed" ) ;
	}
}
	
# Prepare signals info
sub prepareSignalInfo {
	my ($allData) = @_ ;
	
	my @reqKeys = qw/FluidInstructions/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my %instructions ;
	
	# Fluids Signals
	%instructions = () ;
	my %estimates ;
	readInstructions($config{FluidInstructions},\%instructions) ;

	foreach my $family (keys %instructions) {
		foreach my $name (keys %{$instructions{$family}}) {
			my $signalName = $instructions{$family}->{$name}->{name} ;
			my $rateSignalName = $signalName."_Rate" ;
			my $kRateSignalName = $signalName."-k_Rate" ;
			
			addToDict($allData,$signalName,"FluidsSignals") if (! exists $allData{dict}->{$signalName}) ;
			addToDict($allData,$rateSignalName,"FluidsSignals") if (! exists $allData{dict}->{$rateSignalName});
			addToDict($allData,$kRateSignalName,"FluidsSignals") if (! exists $allData{dict}->{$kRateSignalName});
			
			$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{Fluids_N}} ;
			$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Numeric", file => "Fluids_N", origType => "T_TimeRangeVal"} ;
			
			$allData->{signals}->{$rateSignalName} = {code => $rateSignalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{Fluids_N}} ;
			$allData->{signalInfo}->{$rateSignalName} = {type => "T_TimeVal" , value => "Numeric", file => "Fluids_N", origType => "T_TimeVal"} ;
			
			$allData->{signals}->{$kRateSignalName} = {code => $kRateSignalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{Fluids_N}} ;
			$allData->{signalInfo}->{$kRateSignalName} = {type => "T_TimeVal" , value => "Numeric", file => "Fluids_N", origType => "T_TimeVal"} ;
		}
	}	
}

# Print data to files
sub printData {
	my ($idData,$allData) = @_ ;
	
	foreach my $stayId (sort {$a<=>$b} keys %{$idData->{data}}) {
		foreach my $type (@dataFiles) {
			foreach my $rec (@{$idData->{data}->{$stayId}->{$type}}) {
				my $out = join "\t",($stayId,@$rec) ;
				$allData->{files}->{$type}->print ("$out\n") ;
				$allData->{signalFlags}->{$rec->[0]} = 1 ;
			}
		}
	}
}
	
sub printCollectiveData {
	my ($allData) = @_ ;

	# Print Signal Info File
	foreach my $signalName (keys %{$allData->{signalInfo}}) {
		if (exists $allData->{signalFlags}->{$signalName}) {
			my $sigType = $allData->{signalInfo}->{$signalName}->{type} ;
			my $valType = $allData->{signalInfo}->{$signalName}->{value} ;
			my $valCount = (exists $allData->{MultValuesSignals}->{$signalName} and $allData->{MultValuesSignals}->{$signalName}==0) ? "SingleValue" : "MultipleValue" ;
			my $unit = $origUnits{$signalName} ;
			my $file = $allData->{signalInfo}->{$signalName}->{file} ;
			my $origSigType = $allData->{signalInfo}->{$signalName}->{origType} ;
			
			$allData->{signalInfoFile}->print("$signalName\t$sigType\t$valType\t$valCount\t$unit\t$file\t$origSigType\n") ;
		}
	}	
}

# Check number of allowed value per stay.
sub handleValuesCounter {
	my ($allData) = @_ ;
	
	foreach my $stay (keys %{$allData->{SignalValuesPerStay}}) {
		foreach my $signal (keys %{$allData->{SignalValuesPerStay}->{$stay}}) {
			my $num = scalar (keys %{$allData->{SignalValuesPerStay}->{$stay}->{$signal}}) ;
			$allData->{MultValuesSignals}->{$signal} += ($num > 1) ? 1:0 ;
		}
	}
}
	
# Reading indexed files	

sub readLines {
	
	my ($dir,$name,$id,$header) = @_ ;
	my @outLines = () ;
	
	if (!exists ($reader{$name}->{data_fh})) {
		$reader{$name}->{data_fh} = FileHandle->new("$dir/$name","r") or die "Cannot open \'$dir/$name\' for reading" ;
        my $headerLine = $reader{$name}->{data_fh}->getline() ;
		chomp $headerLine ; $headerLine =~ s/\r// ;
		my @fields = split /\t/,$headerLine ;
		my %header= map {($fields[$_] => $_)} (0..$#fields) ; 
		die "File $name has no Case-N column !" if (! exists $header{"Case N"}) ;
		
		$reader{$name}->{header} = \%header ;
        $reader{$name}->{index} = read_index("$dir/$name.idx") ;		
	}
	
	die "Cannot get id $id (Max = $maxId)\n" if ($id > $maxId) ;
	
	my $from = $reader{$name}->{index}->[$id] ;
	if ($from != -1) {
		$reader{$name}->{data_fh}->seek($from,0) ;
		
		while (my $line = $reader{$name}->{data_fh}->getline()) {
			chomp $line ; $line =~ s/\r// ; 
			my @fields = split /\t/,$line ;
			last if ($fields[$reader{$name}->{header}->{"Case N"}] != $id) ;
			push @outLines,\@fields ;
		}
	}
	
	return (\@outLines,$reader{$name}->{header});
}

sub read_index {
	my $name = shift @_ ;
	
	my $buffer ;
	open (IN,"<:raw",$name) or die "Cannot open \'$name\' for reading in binary mode" ;
	read (IN,$buffer,($maxId+1)*8) == ($maxId+1)*8 or die "Cannot read from \'$name\'" ;
	my $format = sprintf("q%d",$maxId+1) ;
	my @pos = unpack($format,$buffer) ;
	return \@pos ;
}

	
	
	
	