#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

use Scalar::Util qw(looks_like_number) ;

die "Usage : $0 ConfigFile" if (@ARGV != 1) ;
my ($configFile) = @ARGV ;

# Global Parameters
my @dataSFiles = qw/Demographics ICU_Stays_S LabEvents_S ChartEvents_S IOEvents_S ICD9 PROCEDURES/ ;
my @dataNFiles = qw/ICU_Stays_N  LabEvents_N  ChartEvents_N IOEvents_N MicroBiologyEvents_N MedEvents_N PoeOrder_N ExtraEvents Comorbidities/ ;
my @dataFiles = (@dataNFiles,@dataSFiles) ;
my @signalTypes = qw/T_Value T_DateVal T_TimeVal T_DateRangeVal T_TimeStamp T_TimeRangeVal T_DateVal2 T_TimeLongVal/ ;

my @allComorbiditySignals = qw/ELIXHAUSER_AIDS ELIXHAUSER_ALCOHOL_ABUSE ELIXHAUSER_BLOOD_LOSS_ANEMIA ELIXHAUSER_CARDIAC_ARRHYTHMIAS ELIXHAUSER_CHRONIC_PULMONARY ELIXHAUSER_COAGULOPATHY ELIXHAUSER_CONGESTIVE_HEART_FAILURE
							   ELIXHAUSER_DEFICIENCY_ANEMIAS ELIXHAUSER_DEPRESSION ELIXHAUSER_DIABETES_COMPLICATED ELIXHAUSER_DIABETES_UNCOMPLICATED ELIXHAUSER_DRUG_ABUSE ELIXHAUSER_FLUID_ELECTROLYTE ELIXHAUSER_HYPERTENSION
							   ELIXHAUSER_HYPOTHYROIDISM ELIXHAUSER_LIVER_DISEASE ELIXHAUSER_LYMPHOMA ELIXHAUSER_METASTATIC_CANCER ELIXHAUSER_OBESITY ELIXHAUSER_OTHER_NEUROLOGICAL ELIXHAUSER_PARALYSIS ELIXHAUSER_PEPTIC_ULCER
							   ELIXHAUSER_PERIPHERAL_VASCULAR ELIXHAUSER_PSYCHOSES ELIXHAUSER_PULMONARY_CIRCULATION ELIXHAUSER_RENAL_FAILURE ELIXHAUSER_RHEUMATOID_ARTHRITIS ELIXHAUSER_SOLID_TUMOR ELIXHAUSER_VALVULAR_DISEASE ELIXHAUSER_WEIGHT_LOSS/ ;
							   
my %allComorbiditySignals = map {($_ => 1)} @allComorbiditySignals ;


my %config ;
my %lookups ;
my %counts = (good => 0, bad => 0, changed => 0) ;
my %allData = (dictIndex => 0) ;
my %chartLabSignals ;
my %resolutions ;
my %procedures ;
my (%origUnits,%units) ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my $maxTime = transformTime("9999-12-31 23:59:00 EST") ;

my $logFH ;

# Read Config File
readConfig($configFile) ;

# Required keys
my @reqKeys = qw/OutDir OutPrefix IdsFile LogFile UnitsFile LookUpDir ChartLabSignals/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

# Open Log File
$logFH = FileHandle->new($config{LogFile},"w") or die "Cannot open log file $config{LogFile} for writing" ;

# Init
my $bitsPerSpecimen = 7 ;
my $bitsPerOrganism = 9 ;
my $bitsPerAntibacterium = 9 ;
initDictionary(\%allData) ;

my %fileIds = map {($dataFiles[$_] => $_)} (0..$#dataFiles) ;
my %signalTypes = map {$signalTypes[$_] => $_} (0..$#signalTypes) ;

openOutFiles(\%allData) ;
readChartLabSignals() ;
prepareSignalInfo(\%allData) ;
readResolutions() ;
readProcedures() ;
readUnits() ;

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
	my $dir = sprintf("%s/%02d/%05d",$config{DataDir},int($id/1000),$id) ;

	# ICU Stays
	doStays($dir,$id,\%idData,\%allData)  ;

	# Demographics
	doDemographics($dir,$id,\%idData,\%allData) ;
	
	# Comorbidities
	doComorbidities($dir,$id,\%idData,\%allData) ;

	# Census Events
	doCensus($dir,$id,\%idData,\%allData) ;
	
	# Lab Events
	doLabEvents($dir,$id,\%idData,\%allData) ;

	# Chart Events
	doChartEvents($dir,$id,\%idData,\%allData) ;

	# IO Events
	doIOEvents($dir,$id,\%idData,\%allData) ;
	
	# Microbiology events
	doMicroBiologyEvents($dir,$id,\%idData,\%allData) ;
	
	# ICD-9
	doICD9($dir,$id,\%idData,\%allData) ;
	
	# Med Events
	doMedEvents($dir,$id,\%idData,\%allData) ;
	
	# POE-Order
	doPoeOrder($dir,$id,\%idData,\%allData) ;
	
	# Procedures
	doProcedures($dir,$id,\%idData,\%allData) ;

	# Additives
#	doAdditives($dir,$id,\%idData,\%allData) ;

	# Post process stays
	postProcessStays(\%idData,) ;

	# Update stays data
	updateData(\%idData,\%allData) ;
	
	# Handle lab/chart signals
	handleLabChartSignals(\%idData) ;
	
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


print STDERR "\n\n" ;

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

# Read Procedures
sub readProcedures {

	my $file = $config{ProceduresFile} ;
	$procedures{minNum} = (exists $config{MinProceduresCount}) ? $config{MinProceduresCount} : 1 ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp; 
		my ($code,$count,$desc) = split /\t/,$_ ;
		$procedures{codes}->{$code} = {desc => $desc, count => $count}  ; 
	}
	close IN ;
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
	print STDERR "Read $nids IDs\n" ;
	
	return ;
}
	
# Utility: is a flag on ?
sub flagOn {
	my ($value) = @_ ;
	
	return (uc($value) eq "Y" or uc($value) eq "YES") ;
}

# Handle Demographics
sub doDemographics {
	my ($dir,$inId,$idData,$allData) = @_ ;
		
	my $inFile = sprintf("$dir/DEMOGRAPHIC_DETAIL-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open $inFile for reading" ;

	my %done ;
	my $header ;
	my ($desc,$itemId) ;
	
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $hadmId = $rec[$header->{HADM_ID}] ;

			die "Multiple Demographics info for $id/$hadmId" if (exists $done{$id}->{$hadmId}) ;
			$done{$id}->{$hadmId} = 1 ;
			
			if (! exists $idData->{stays}->{$hadmId}) {
				$logFH->print("Cannot find ICU stay Ids for $id/$hadmId. Skipping\n")  ;
			} else {
				for my $signal (qw/MARITAL_STATUS ETHNICITY OVERALL_PAYOR_GROUP RELIGION ADMISSION_TYPE ADMISSION_SOURCE/) {
					my $desc = $rec[$header->{$signal."_DESCR"}] ;

					if ($desc ne "") {
						$desc .= "_$signal" if ($desc eq "OTHER") ;
						addToDict($allData,$desc,"Demographics") if (! exists $allData->{dict}->{$desc})  ;
						addToSignalValues($allData,$signal,$desc) ;
						
						# Get in-time of first stay
						my $firstInTime = -1 ;
#						map {$firstInTime = $idData->{data}->{$_}->{InTime} if ($firstInTime==-1 or $idData->{data}->{$_}->{InTime} < $firstInTime)} (@{$idData->{stays}->{$hadmId}}) ;
						
						foreach my $stay (@{$idData->{stays}->{$hadmId}}) {
							my $stayInTime = $idData->{data}->{$stay}->{InTime} ;
							push @{$idData->{data}->{$stay}->{Demographics}},[$signal,$stayInTime,$desc]  ;
							$allData->{SignalValuesPerStay}->{$stay}->{$signal}->{$desc} = 1 ;
						}
					}
				}
			}
		}	
	}
	
	close IN ;
}

# Handle Comorbidities
sub doComorbidities {
	my ($dir,$inId,$idData,$allData) = @_ ;
		
	my $inFile = sprintf("$dir/COMORBIDITY_SCORES-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open $inFile for reading" ;

	my %done ;
	my %comorbiditySignals ;
	
	my $header ;
	my ($desc,$itemId) ;
	
	while (my $line = <IN>) {
		chomp $line; 
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $hadmId = $rec[$header->{HADM_ID}] ;
			my $category = $rec[$header->{CATEGORY}] ;
	
			die "Multiple Comorbidities info for $id/$hadmId" if (exists $done{$id}->{$hadmId}) ;
			die "Unknown Comorbidity category $category" if ($category ne "ELIXHAUSER") ;
			$done{$id}->{$hadmId} = 1 ;
			
			if (! exists $idData->{stays}->{$hadmId}) {
				$logFH->print("Cannot find ICU stay Ids for $id/$hadmId. Skipping\n")  ;
			} else {
				# out-time of last icu-stay
				my $lastOutTime = -1 ;
				map {$lastOutTime = $idData->{data}->{$_}->{OutTime} if ($idData->{data}->{$_}->{OutTime} > $lastOutTime)} (@{$idData->{stays}->{$hadmId}}) ;
			
				foreach my $comorbidity (keys %$header) {
					next if ($comorbidity eq "SUBJECT_ID" or $comorbidity eq "HADM_ID" or  $comorbidity eq "CATEGORY") ;
					my $index = $rec[$header->{$comorbidity}] ;

					my $signalName = $category."_".$comorbidity ;
					$comorbiditySignals{$signalName} = 1 ;
					
					foreach my $stay (@{$idData->{stays}->{$hadmId}}) {
						push @{$idData->{data}->{$stay}->{Comorbidities}},[$signalName,$lastOutTime,$index]  ;
						$allData->{SignalValuesPerStay}->{$stay}->{$signalName}->{$index} = 1 ;	
					}
				}
			}
		}	
	}

	if (%comorbiditySignals) {
		map {die "Missing Comorbidity signal $_ in ".(keys %comorbiditySignals)  if (! exists $comorbiditySignals{$_})} @allComorbiditySignals ;
		map {die "Unknown Comorbidity signal $_" if (! exists $allComorbiditySignals{$_})} keys %comorbiditySignals ;
	}
	close IN ;
}

# Handle ICU Stays
sub doStays {
	my ($dir,$inId,$idData,$allData) = @_ ;
		
	my $inFile = sprintf("$dir/ICUSTAY_DETAIL-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open $inFile for reading" ;

	my $header ;
	
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;

			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $stayID = $rec[$header->{ICUSTAY_ID}] ;
			my $hadmID = $rec[$header->{HADM_ID}] ;
			
			push @{$idData->{stays}->{$hadmID}},$stayID ;
			
			my $inTime = $idData->{data}->{$stayID}->{InTime} = transformTime($rec[$header->{ICUSTAY_INTIME}]) ;
			my $outTime = $idData->{data}->{$stayID}->{OutTime} = transformTime($rec[$header->{ICUSTAY_OUTTIME}]) ;
			
			$idData->{earliestTime} = $idData->{data}->{$stayID}->{InTime} if (! exists $idData->{earliestTime} or $idData->{data}->{$stayID}->{InTime} < $idData->{earliestTime}) ;
			
			push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["InTime",$inTime] ;
			$allData->{SignalValuesPerStay}->{$stayID}->{InTime}->{$inTime} = 1 ;
			
			push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["OutTime",$outTime] ;
			$allData->{SignalValuesPerStay}->{$stayID}->{OutTime}->{$outTime} = 1 ;
			
			my $gender = $rec[$header->{GENDER}] ;
			my $age = int($rec[$header->{ICUSTAY_ADMIT_AGE}]) ;
			
			if ($gender eq "M") {
				push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["Gender",$inTime,1] ;
				$allData->{SignalValuesPerStay}->{$stayID}->{Gender}->{1} = 1 ;
			} elsif ($gender eq "F") {
				push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["Gender",$inTime,2] ;
				$allData->{SignalValuesPerStay}->{$stayID}->{Gender}->{2} = 1 ;
			} else {
				$logFH->print("Unknown gender \'$gender\' for $stayID\n") ;
			}
			
			if ($age ne "") {
				push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["Age",$inTime,$age] ; 
				$allData->{SignalValuesPerStay}->{$stayID}->{Age}->{$age} = 1 ;
			}
			
			if ($hadmID ne "") {
				push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["HospitalAdmin",$inTime,$hadmID] ;
				$allData->{SignalValuesPerStay}->{$stayID}->{HospitalAdmin}->{$hadmID} = 1 ;
			}
			
			if ($id ne "") {
				push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["ID",$inTime,$id] ;
				$allData->{SignalValuesPerStay}->{$stayID}->{ID}->{$id} = 1 ;
			}
		}
	}
	close IN ;
}

# Handle LAB Events
sub doLabEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;
			
	my @reqKeys = qw/LabEventsInstructions LabEventsTextValues/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my (%instructions,%nonNumericValues) ;
	readInstructions($config{LabEventsInstructions},\%instructions) ;
	readNonNumericValues($config{LabEventsTextValues},\%instructions,\%nonNumericValues) ;
	
	my $inFile = sprintf("$dir/LABEVENTS-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;

	my $header ;
	
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $stayID = $rec[$header->{ICUSTAY_ID}] ;
			$stayID = "MISSING" if ($stayID eq "") ;
			my $itemID = $rec[$header->{ITEMID}] ;
				
			if (exists $instructions{$itemID}) {
				my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				
				my $signalName = $instructions{$itemID}->{name} ;
				if ($instructions{$itemID}->{type} eq "TEXT") {
					my $nonNumericValue = $rec[$header->{VALUE}] ;
					$nonNumericValue =~ s/\"//g; 
					if ($nonNumericValue eq "") {
						$logFH->print("Cannot find value for $signalName for $id at $time\n") ;
					} else {
						addToDict($allData,$nonNumericValue,"") if (! exists $allData->{dict}->{$nonNumericValue});
						addToSignalValues($allData,$signalName,$nonNumericValue) ;
						die "Cannot handle lab/chart signal" if (exists $chartLabSignals{$signalName}) ;
						push @{$idData->{data}->{$stayID}->{LabEvents_S}},[$signalName,$time,$nonNumericValue] ;
# 						LabEvents can be outside ICU stay
#						updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
					}
				} else {
					my $value = $rec[$header->{VALUENUM}] ;
					if ($value eq "") {
						my $nonNumericValue = $rec[$header->{VALUE}] ;
						$nonNumericValue =~ s/\"//g; 
						if ($nonNumericValue eq "") {
							$logFH->print("Cannot find value for $signalName for $id at $time\n") ;
						} elsif (!exists $nonNumericValues{$signalName}->{lc($nonNumericValue)}) {
							$logFH->print("Ignoring non numeric values $nonNumericValue for $signalName for $id at $time\n") ;
						} else {
							$value = $nonNumericValues{$signalName}->{lc($nonNumericValue)} ;
							my $unit = lc($rec[$header->{VALUEUOM}]) ;
							if (!exists $units{$signalName}->{$unit}) {
								$logFH->print("Cannot analyze unit \'$unit\' for $signalName\n") ;
							} else {
								$value *= $units{$signalName}->{$unit} ;
								my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "LabEvents_N" ;
								push @{$idData->{data}->{$stayID}->{destFile}},[$signalName,$time,fixResolution($signalName,$value)] ;
#		 						LabEvents can be outside ICU stay								
#								updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
							}						
						}
					} else {
						my $unit = lc($rec[$header->{VALUEUOM}]) ;
						if (!exists $units{$signalName}->{$unit}) {
							$logFH->print("Cannot analyze unit \'$unit\' for $signalName\n") ;
						} else {
							$value *= $units{$signalName}->{$unit} ;
							my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "LabEvents_N" ;
							push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)] ;
#	 						LabEvents can be outside ICU stay							
#							updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
						}
					}
				}
			} 
		}
	}
	close IN ;
}

# Handle Chart Events
sub doChartEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;
	
	my @reqKeys = qw/ChartEventsInstructions ChartEventsTextValues/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my (%instructions,%nonNumericValues) ;
	readInstructions($config{ChartEventsInstructions},\%instructions) ;
	readNonNumericValues($config{ChartEventsTextValues},\%instructions,\%nonNumericValues) ;
	
	my $inFile = sprintf("$dir/CHARTEVENTS-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;

	my $header ;
	
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $stayID = $rec[$header->{ICUSTAY_ID}] ;
			$stayID = "MISSING" if ($stayID eq "") ;
			my $itemID = $rec[$header->{ITEMID}] ;

			if (exists $instructions{$itemID}) {
				my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				
				my $signalName = $instructions{$itemID}->{name} ;
				if ($instructions{$itemID}->{type} eq "TEXT") {
					my $nonNumericValue = $rec[$header->{VALUE1}] ;
					$nonNumericValue =~ s/\"//g; 
					
					if ($rec[$header->{VALUE2}] ne "" or $rec[$header->{VALUE2NUM}] ne "") {
						$logFH->print("Two values given for $signalName for $id at $time\n") ;
					} elsif ($nonNumericValue eq "") {
						$logFH->print("Cannot find value for $signalName for $id at $time\n") ;
					} else {
						addToDict($allData,$nonNumericValue,"") if (! exists $allData->{dict}->{$nonNumericValue});
						addToSignalValues($allData,$signalName,$nonNumericValue) ;
						die "Cannot handle lab/chart signal" if (exists $chartLabSignals{$signalName}) ;
						push @{$idData->{data}->{$stayID}->{ChartEvents_S}},[$signalName,$time,$nonNumericValue] ;
						updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
					}
				} elsif ($instructions{$itemID}->{type} eq "VALUE") {;
					my $value = $rec[$header->{VALUE1NUM}] ; 
					if ($value eq "") {
						my $nonNumericValue = $rec[$header->{VALUE1}] ;
						$nonNumericValue =~ s/\"//g; 
						if ($nonNumericValue eq "") {
							$logFH->print("Cannot find value for $signalName for $id at $time\n") ;
						} elsif ($rec[$header->{VALUE2}] ne "" or $rec[$header->{VALUE2NUM}] ne "") {
							$logFH->print("Two values given for $signalName for $id at $time\n") ;
						} elsif ($signalName eq "CHART_I:E_Ratio") { #### SPECIAL CARE OF I:E Ratio Data
							if ($nonNumericValue =~ /^(\S+):(\S+)$/ and looks_like_number($1) and looks_like_number($2) and $2 != 0) {
								my $ratio = $1/$2 ;
								my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "ChartEvents_N" ;
								push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,$ratio] ;
								updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
							} else {
								$logFH->print("Ignoring non numeric values $nonNumericValue for $signalName for $id at $time\n") ;
							}
						} elsif (!exists $nonNumericValues{$signalName}->{lc($nonNumericValue)}) {
							$logFH->print("Ignoring non numeric values $nonNumericValue for $signalName for $id at $time\n") ;
						} else {
							$value = $nonNumericValues{$signalName}->{lc($nonNumericValue)} ;
							my $unit = lc($rec[$header->{VALUE1UOM}]) ;
							if (!exists $units{$signalName}->{$unit}) {
								$logFH->print("Cannot analyze unit \'$unit\' for $signalName\n") ;
							} else {
								$value *= $units{$signalName}->{$unit} ;
								my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "ChartEvents_N" ;
								push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)] ;
								updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
							}						
						}
					} else {
						my $unit = lc($rec[$header->{VALUE1UOM}]) ;
						if (!exists $units{$signalName}->{$unit}) {
							$logFH->print("Cannot analyze unit \'$unit\' for $signalName\n") ;
						} elsif ($rec[$header->{VALUE2}] ne "" or $rec[$header->{VALUE2NUM}] ne "") {
							$logFH->print("Two values given for $signalName for $id at $time\n") ;
						} elsif ($signalName eq "CHART_I:E_Ratio") { #### SPECIAL CARE OF I:E Ratio Data							
							$logFH->print("I:E Ration has a single value $value for $id at $time\n") ;
						} else {
							$value *= $units{$signalName}->{$unit} ;
							my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "ChartEvents_N" ;
							push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)] ;
							updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
						}
					}
				} elsif ($instructions{$itemID}->{type} eq "2VALUES") {
					my ($valField,$numFiled,$unitField) ;

					for my $valNum (0,1) {
						if ($valNum == 0) {
							($valField,$numFiled,$unitField) = qw/VALUE1 VALUE1NUM VALUE1UOM/ ;
						} else {
							($valField,$numFiled,$unitField) = qw/VALUE2 VALUE2NUM VALUE2UOM/ ;
						}
					
						my $signalName = $instructions{$itemID}->{names}->[$valNum] ;
						my $value = $rec[$header->{$numFiled}] ;
						if ($value eq "") {
							my $nonNumericValue = $rec[$header->{$valField}] ;
							$nonNumericValue =~ s/\"//g; 
							if ($nonNumericValue eq "") {
								$logFH->print("Cannot find value for $signalName for $id at $time\n") ;
							} elsif (!exists $nonNumericValues{$signalName}->{lc($nonNumericValue)}) {
								$logFH->print("Ignoring non numeric values $nonNumericValue for $signalName for $id at $time\n") ;
							} else {
								$value = $nonNumericValues{$signalName}->{lc($nonNumericValue)} ;
								my $unit = lc($rec[$header->{$unitField}]) ;
								if (!exists $units{$signalName}->{$unit}) {
									$logFH->print("Cannot analyze unit \'$unit\' for $signalName\n") ;
								} else {
									$value *= $units{$signalName}->{$unit} ;
									my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "ChartEvents_N" ;
									push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)] ;
									updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
								}						
							}
						} else {
							my $unit = lc($rec[$header->{$unitField}]) ;
							if (!exists $units{$signalName}->{$unit}) {
								$logFH->print("Cannot analyze unit \'$unit\' for $signalName\n") ;
							} else {
								$value *= $units{$signalName}->{$unit} ;
								push @{$idData->{data}->{$stayID}->{ChartEvents_N}},[$signalName,$time,fixResolution($signalName,$value)] ;
								updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
							}
						}
					}
				}
			} 
		}
	}
	close IN ;
}

# Handle IO Events
sub doIOEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;
	
	my @reqKeys = qw/IOEventsInstructions IOEventsEstimatedSignals/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my (%instructions,%estimates,%directions) ;
	readInstructions($config{IOEventsInstructions},\%instructions) ;
	readEstimated($config{IOEventsEstimatedSignals},\%estimates) ;
	
	my $inFile = sprintf("$dir/IOEVENTS-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;

	my $header ;
	my %ioEvents ;
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $stayID = $rec[$header->{ICUSTAY_ID}] ;
			$stayID = "MISSING" if ($stayID eq "") ;
			my $itemID = $rec[$header->{ITEMID}] ;

			if (exists $instructions{$itemID}) {
				my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				my $signalName = $instructions{$itemID}->{name} ;
				if ($instructions{$itemID}->{type} eq "TEXT") {
					my $nonNumericValue = $rec[$header->{ESTIMATE}] ;
					$nonNumericValue =~ s/\"//g; 
					if ($nonNumericValue eq "") {
						$logFH->print("Cannot find value for IO:$signalName for $id at $time\n") ;
					} else {
						addToDict($allData,$nonNumericValue,"") if (! exists $allData->{dict}->{$nonNumericValue});
						addToSignalValues($allData,$signalName,$nonNumericValue) ;
						push @{$idData->{data}->{$stayID}->{IOEvents_S}},[$signalName,$time,$nonNumericValue] ;
						updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
					}
				} else {
					push @{$ioEvents{$itemID}->{$stayID}},$line ;
					updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
				}
			}
		}
	}
	
	foreach my $itemID (keys %ioEvents) {
		foreach my $stayID (keys %{$ioEvents{$itemID}}) {
		
			my $prevTime = -1 ;
			foreach my $line (@{$ioEvents{$itemID}->{$stayID}}) {
			
				my @rec = mySplit($line,",") ;
				my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				my $signalName = $instructions{$itemID}->{name} ;
				
				if ($rec[$header->{STOPPED}] ne "") {
					my $stopped = lc($rec[$header->{STOPPED}]) ;
					$logFH->print("Signal IO:$signalName [$itemID] at $stayID/$time : $stopped\n") ;
					if ($stopped eq "stopped" or $stopped eq "d/c'd") {
						$prevTime = -1 ;
					} elsif ($stopped eq "restart" or $stopped eq "notstopd") {
						$prevTime = $time ;
					}
				} else {
					my $value = $rec[$header->{VOLUME}] ;	
					if ($value eq "") {
						my $estimate = $rec[$header->{ESTIMATE}] ;
						if ($estimate eq "") {
							my $desc = ($rec[$header->{NEWBOTTLE}] eq "") ? "Missing" : "NewBottle" ;
							$logFH->print("Signal IO:$signalName [$itemID] at $stayID/$time : $desc\n") ;
						} elsif (exists $estimates{$itemID}) {
							$signalName .= "_Estimate" ;
							addToDict($allData,$estimate,"") if (! exists $allData->{dict}->{$estimate});
							addToSignalValues($allData,$signalName,$estimate) ;
							push @{$idData->{data}->{$stayID}->{IOEvents_S}},[$signalName,$prevTime,$time,$estimate] ;
							updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
						}
						
					} else {
						my $unit = lc($rec[$header->{VOLUMEUOM}]) ;
						if (!exists $units{$signalName}->{$unit}) {
							$logFH->print("Cannot analyze unit \'$unit\' for $signalName\n") ;
						} else {
							$value *= $units{$signalName}->{$unit} ;
							push @{$idData->{data}->{$stayID}->{IOEvents_N}},[$signalName,$prevTime,$time,$value] ;
						}
					}
					$prevTime = $time ;
				}
			} 
		}
	}
}

# Handle Microbiology Event
sub doMicroBiologyEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my $inFile = sprintf("$dir/MICROBIOLOGYEVENTS-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;

	my $header ;
	my ($specimen,$organism,$antibact,$interept) = ("","","","") ;
	my %interpatations = ("S" => 1, "P" => 0, "I" => 0, "R" => 2, "U" => 0) ;
	
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $hadmId = $rec[$header->{HADM_ID}] ;
			
			if (! exists $idData->{stays}->{$hadmId}) {
				$logFH->print("Cannot find ICU stay Ids for $id/$hadmId. Skipping\n")  ;
			} else {
				my $origTime = $rec[$header->{CHARTTIME}] ;
				my $time = $origTime eq "" ? $maxTime : transformTime($origTime) ;
				
			# Specimen
			my $specimen = ($rec[$header->{SPEC_ITEMID}] eq "") ? "" : lookFor($rec[$header->{SPEC_ITEMID}],"D_MICROBIOLOGY") ;
			$specimen = "NoSpecimen" if ($specimen eq "") ;
			die "Cannot find $specimen in dictionary" if (not exists $allData->{mbDict}->{$specimen});
			my $longValue = $allData->{mbDict}->{$specimen} ;
				
			# Organism
			my $organism = ($rec[$header->{ORG_ITEMID}] eq "") ? "" :lookFor($rec[$header->{ORG_ITEMID}],"D_MICROBIOLOGY") ;
			$organism = "NoOrganism" if ($organism eq "") ;
			die "Cannot find $organism in dictionary" if (not exists $allData->{mbDict}->{$organism});
			$longValue += $allData->{mbDict}->{$organism} << $bitsPerSpecimen ;
					
			# AntiBacterium	
			my $antibact = ($organism ne "NoOrganism" and $rec[$header->{AB_ITEMID}] ne "") ? lookFor($rec[$header->{AB_ITEMID}],"D_MICROBIOLOGY") : "" ;
			$antibact = "NoAntiBacterium" if ($antibact eq "") ;
			die "Cannot find $antibact in dictionary" if (not exists $allData->{mbDict}->{$antibact});
			$longValue += $allData->{mbDict}->{$antibact} << ($bitsPerSpecimen + $bitsPerOrganism) ;
				
			# Susceptability	
			my $interpet = ($antibact ne "NoAntiBacterium") ? $rec[$header->{INTERPRETATION}] : "U" ;
			die "Unknown interpretation $interpet" if (! exists $interpatations{$interpet}) ;
			$longValue += $interpatations{$interpet} << ($bitsPerSpecimen + $bitsPerOrganism + $bitsPerAntibacterium) ;
			
				map {push @{$idData->{data}->{$_}->{MicroBiologyEvents_N}},["MicroBiology",$time,$longValue]} (@{$idData->{stays}->{$hadmId}})
			}
		}
	}
	close IN ;
}

# Handle Census Events
sub doCensus {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my $inFile = sprintf("$dir/CENSUSEVENTS-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;
	
	my $header ; 
	my %careUnits ;
	my $id ;
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			$id = $rec[$header->{SUBJECT_ID}] ;
			
			my $inTime = transformTime($rec[$header->{INTIME}]) ;
			my $outTime = transformTime($rec[$header->{OUTTIME}]) ;
			my $stayID = $rec[$header->{ICUSTAY_ID}] ;
			
			if ($stayID eq "") {
				foreach my $testStayID (keys %{$idData->{data}}) {
					if ($outTime eq $idData->{data}->{$testStayID}->{OutTime}) {
						$stayID = $testStayID ;
						last ;
					}
				}
			}
			
			$stayID = "MISSING" if ($stayID eq "") ;
						
			# Care Units and Destinations
			push @{$careUnits{$stayID}},[$inTime,$outTime,$rec[$header->{CAREUNIT}],$rec[$header->{DESTCAREUNIT}]] ;
		}
	}
	
	foreach my $stayID (keys %careUnits) {	
		my @careUnits = sort {$a->[0] <=> $b->[0]} @{$careUnits{$stayID}} ;
		
		my (%allUnits,%allDest,%destChain) ;
		for my $rec (@careUnits) {
			my ($inTime,$outTime,$unit) = @$rec ;
			if ($unit ne "" and $inTime != $outTime) {
				if (exists $allUnits{$inTime} and $unit ne $allUnits{$inTime}) {
					$logFH->print("Multiple care-units for $id/$stayID at $inTime\n") ;
				} else {
					$allUnits{$inTime} = {outTime => $outTime, unit => $unit} ;
				}
			}
		}
			
		for my $rec (@careUnits) {
			my ($inTime,$outTime,$unit,$destination) = @$rec ;			
			
			if ($inTime == $outTime) {
				if ($destination ne "") {	
					if (exists $destChain{$outTime}->{$unit} and $destChain{$outTime}->{$unit} ne $destination) {
						$logFH->print("Multiple destinations for $id/$stayID at $outTime\n") ;
					} elsif ($destination == $unit) {
						$logFH->print("destination loop for $id/$stayID at $outTime\n") ;
					} else {
						$destChain{$outTime}->{$unit} = $destination ;
					}
				}
			} else {
				$destination = -1 if ($destination eq "") ;
				if (exists $allDest{$outTime} and $destination ne $allDest{$outTime}) {
					$logFH->print("Multiple destinations for $id/$stayID at $outTime\n") ;
				} else {
					$allDest{$outTime} = $destination ;
				}
			}			
		}
		
		# Care Units
		if (! %allUnits) {
			$logFH->print("No Units found for $id/$stayID\n") ;
		} else {
			my @inTimes = sort {$a<=>$b} keys %allUnits ; 
			for my $i (0..$#inTimes) {
				my $inTime = $inTimes[$i] ;
				if ($i>0 and $allUnits{$inTimes[$i-1]}->{outTime} > $allUnits{$inTime}->{inTime}) {
					$logFH->print("Census events intersection for $id/$stayID at $inTime\n") ;
				}
				
				my $outTime = $allUnits{$inTime}->{outTime} ;
				my $unit = $allUnits{$inTime}->{unit} ;
				my $careUnit = lookFor($unit,"D_CAREUNITS") ;
				addToDict($allData,$careUnit,"CareUnits") if (! exists $allData->{dict}->{$careUnit}) ;
				addToSignalValues($allData,"Care_Units",$careUnit) ;	
				push @{$idData->{data}->{$stayID}->{ICU_Stays_S}},["Care_Units",$inTime,$outTime,$careUnit] ;
				$allData->{SignalValuesPerStay}->{$stayID}->{Care_Units}->{$careUnit} = 1 ;
			}
			
			my $inTime = $inTimes[0] ;
			my $unit = $allUnits{$inTime}->{unit} ;
			my $careUnit = lookFor($unit,"D_CAREUNITS") ;
			push @{$idData->{data}->{$stayID}->{ICU_Stays_S}},["First_Care_Unit",$inTime,$careUnit] ;
			$allData->{SignalValuesPerStay}->{$stayID}->{First_Care_Unit}->{$careUnit} = 1 ;
			addToSignalValues($allData,"First_Care_Unit",$careUnit) ;
		}
		
		# Destinations
		if (! %allDest) {
			$logFH->print("No Destinations for $id/$stayID\n") ;
		} else {
			my @outTimes = sort {$a<=>$b} keys %allDest ; 

			foreach my $outTime (@outTimes) {
				my $destination = $allDest{$outTime} ;
				while (exists $destChain{$outTime}->{$destination}) {
					my $newDestination = $destChain{$outTime}->{$destination}; 
					$logFH->print("destination chain for $id/$stayID at $outTime : $destination -> $newDestination\n") ;
					delete $destChain{$outTime}->{$destination}; 
					$destination = $newDestination ;
				}
				my @chain = keys %{$destChain{$outTime}} ;
				$logFH->print("destination chain not fully exhausted for $id/$stayID at $outTime [@chain]\n") if (@chain) ;
			}
			
			my $outTime = $outTimes[-1] ;
			my $unit = $allDest{$outTime} ; 
			my $careUnit = lookFor($unit,"D_CAREUNITS") ;
			addToDict($allData,$careUnit,"CareUnits") if (! exists $allData->{dict}->{$careUnit}) ;
			addToSignalValues($allData,"Care_Units",$careUnit) ;			
			push @{$idData->{data}->{$stayID}->{ICU_Stays_S}},["Destination",$outTime,$careUnit] ;
			$allData->{SignalValuesPerStay}->{$stayID}->{Destination}->{$careUnit} = 1 ;
			addToSignalValues($allData,"Destination",$careUnit) ;
		}
	}
}

# Handle ICD-9 Data
sub doICD9 {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my $inFile = sprintf("$dir/ICD9-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;
	
	my $header ;
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $hadmId = $rec[$header->{HADM_ID}] ;
			
			if (! exists $idData->{stays}->{$hadmId}) {
				$logFH->print("Cannot find ICU stay Ids for $id/$hadmId. Skipping\n")  ;
			} else {
				my $code = $rec[$header->{CODE}] ;
				addToDict($allData,$code,"") if (! exists $allData->{dict}->{$code})  ;
				addToSignalValues($allData,"ICD9",$code) ;
				
				# out-time of last icu-stay
				my $lastOutTime = -1 ;
				map {$lastOutTime = $idData->{data}->{$_}->{OutTime} if ($idData->{data}->{$_}->{OutTime} > $lastOutTime)} (@{$idData->{stays}->{$hadmId}}) ;
					
				foreach my $stayId (@{$idData->{stays}->{$hadmId}}) {
					push @{$idData->{data}->{$stayId}->{ICD9}},["ICD9",$lastOutTime,$code] ;
					$allData->{SignalValuesPerStay}->{$stayId}->{ICD9}->{$code} = 1 ;
				}
			}
		}
	}
	close IN ;
}

# Handle Med Events
sub doMedEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;
			
	my @reqKeys = qw/MedEventsInstructions/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my %instructions ;
	readInstructions($config{MedEventsInstructions},\%instructions) ;
	
	my $inFile = sprintf("$dir/MEDEVENTS-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;

	my $header ;
	
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $stayID = $rec[$header->{ICUSTAY_ID}] ;
			$stayID = "MISSING" if ($stayID eq "") ;
			my $itemID = $rec[$header->{ITEMID}] ;
				
			if (exists $instructions{$itemID}) {
				my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				
				my $medName = $instructions{$itemID}->{name}  ;
				my $dose = $rec[$header->{DOSE}] ;
				if ($dose eq "") {
					$logFH->print("Missing dose for $medName for $id at $time\n") ;
				} else {
					my $unit = lc($rec[$header->{DOSEUOM}]) ;
					if (!exists $units{$medName}->{$unit}) {
						$logFH->print("Cannot analyze unit \'$unit\' for $medName for $id\n") ;
					} else {
						$dose *= $units{$medName}->{$unit} ;
						push @{$idData->{data}->{$stayID}->{MedEvents_N}},[$medName,$time,$dose] ;						
						updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
					}
				}
			} 
		}
	}
	close IN ;
}


# Handle POE-Order Events
sub doPoeOrder {
	my ($dir,$inId,$idData,$allData) = @_ ;
			
	my @reqKeys = qw/PoeOrderInstructions/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my %instructions ;
	readPoeInstructions($config{PoeOrderInstructions},\%instructions) ;
	
	my $inFile = sprintf("$dir/POE_ORDER-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open $inFile for reading" ;

	my $header ;
	
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $stayID = $rec[$header->{ICUSTAY_ID}] ;
			$stayID = "MISSING" if ($stayID eq "") ;
			my $medication = $rec[$header->{MEDICATION}] ;
				
			if (exists $instructions{$medication}) {
				my $signalName = "POE_".($instructions{$medication}->{name});
				my ($startTime,$endTime) ;
				if ($rec[$header->{START_DT}] eq "") {
					$logFH->print("Cannot find time for $medication for $id\n") ;
					$startTime = -1 ;
				} else {
					$startTime = transformTime($rec[$header->{START_DT}]) ;
				}
				if ($rec[$header->{STOP_DT}] eq "") {
					$logFH->print("Cannot find time for $medication for $id\n") ;
					$endTime = -1 ;
				} else {
					$endTime = transformTime($rec[$header->{STOP_DT}]) ;
				}

				push @{$idData->{data}->{$stayID}->{PoeOrder_N}},[$signalName,$startTime,$endTime,0.0] ;					
#				updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
			} 
		}
	}
	close IN ;
}

# Handle Procedures
sub doProcedures {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my $inFile = sprintf("$dir/PROCEDUREEVENTS-%05d.txt",$inId) ;
	open (IN,$inFile) or die "Cannot open inFile for reading" ;
	
	my $header ;
	while (my $line = <IN>) {
		chomp $line;
		if (! defined $header) {
			$header = getHeader($line) ;
		} else {
			my @rec = mySplit($line,",") ;
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $hadmId = $rec[$header->{HADM_ID}] ;
			
			if (! exists $idData->{stays}->{$hadmId}) {
				$logFH->print("Cannot find ICU stay Ids for procedure at $id/$hadmId. Skipping\n")  ;
			} else {
				my $code = $rec[$header->{ITEMID}] ;
				die "Unknown procedure code $code" if (! exists $procedures{codes}->{$code}) ;
				next if ($procedures{codes}->{$code}->{count} < $procedures{minNum}) ;

				my $desc = $procedures{codes}->{$code}->{desc} ;					
				my $date = $rec[$header->{PROC_DT}] ;
				my $time = transformDate($date) ;
				my @stays = grep {$time <= $idData->{data}->{$_}->{OutTime} + 24*60} @{$idData->{stays}->{$hadmId}} ;

				if (! @stays) {
					$logFH->print("Cannot find ICU stay for procedure at $id/$hadmId/$date\n") ;
				} else {
					addToDict($allData,$desc,"") if (! exists $allData->{dict}->{$desc})  ;
					addToSignalValues($allData,"Procedure",$desc) ;				
				
					my $stayId = $stays[0] ;
					push @{$idData->{data}->{$stayId}->{PROCEDURES}},["Procedure",$time,$desc]  ;
					$allData->{SignalValuesPerStay}->{$stayId}->{PROCEDURES}->{$desc} = 1 ;
				}
			}
		}
	}
	close IN ;
}

# Handle resolutions issues
sub fixResolution {
	my ($signal,$value) = @_ ;
	
	die "Cannot find Resolutsion for $signal" if (! exists $resolutions{$signal}) ;
	my $bin = int ($value/$resolutions{$signal} + 0.5) ;
	$value = sprintf("%.3f",$bin * $resolutions{$signal}) ;
	
	return $value ;
}

# Read Signals that are both chart and lab
sub readChartLabSignals {
	
	my $file = $config{ChartLabSignals} ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($signal) = split ;
		map {$chartLabSignals{$_."_$signal"} = "CHARTLAB_".$signal} qw/LAB CHART BG/ ;
	}
	close IN ;
}

# Read Instructions
sub readInstructions {
	my ($file,$instructions) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($code,$desc,$type,@names) = split /\t/,$_ ;
		$instructions->{$code}->{type} = $type ;
		if ($type eq "2VALUES" or $type eq "2TEXTS") {
			$instructions->{$code}->{names} = \@names ;
		} elsif ($type eq "VALUE" or $type eq "TEXT") {
			$instructions->{$code}->{name} = $names[0] ;
		} else {
			die "Unknown signal type \'$type\' at \'$_\'" ;
		}
	}
	
	close IN ;
}

sub readPoeInstructions {
	my ($file,$instructions) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my($desc,$name,$group) = split /\t/,$_ ;
		$instructions->{$desc} = {name => $name, group => $group} ;
	}
	
	close IN ;
}

# Read Signals units and conversions
sub readUnits {

	my $file = $config{UnitsFile} ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		next if (/^#/) ;
		
		chomp ;
		my ($signal,$unit,$factor) = split /\t/,$_ ;
		$unit = lc($unit) ;
		$units{$signal}->{$unit} = $factor ;
		$origUnits{$signal} = $unit if ($factor == 1 and ! exists $origUnits{$signal}) ;
	}
	
	close IN ;
}

sub readEstimated {
	my ($file,$estimates) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($signalID) = split /\t/,$_ ;
		$estimates->{$signalID}  = 1 ;
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

# Utility functions for reading
sub getHeader {
	my ($header) = @_ ;
	my @fields = mySplit($header,",") ;
	my %cols = map {($fields[$_] => $_)} (0..$#fields) ;
	return \%cols ;
}

sub transformTime{
	my ($time) = @_ ;
	
	$time =~ /(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)/ or die "Illegal time format for $time" ;
	my $newTime = sprintf("%4d%02d%02d%02d%02d%02d",$1,$2,$3,$4,$5,$6) ;
	
	return getMinutes($newTime) ;
	
}

sub transformDate {
	my ($date) = @_ ;
	
	$date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ or die "Illegal date format for $date" ;
	my $time = sprintf("%4d%02d%02d%02d%02d%02d",$1,$2,$3,23,59,59) ;
	
	return getMinutes($time) ;
	
}

# Utility : Splitting by separator
sub mySplit {
	my ($string,$separator) = @_ ;

	my @quotesSeparated = split /\"/,$string ;

	my @out ;
	for my $i (0..$#quotesSeparated) {
		if ($i%2==0) {
			if ($quotesSeparated[$i] ne $separator) {
				$quotesSeparated[$i] =~ s/^$separator// ;
				$quotesSeparated[$i] =~ s/$separator$// ;
				$quotesSeparated[$i] .= ($separator."Dummy") ;
				push @out,(split $separator,$quotesSeparated[$i]) ;
				pop @out ; 
			}
		} else {
			push @out,$quotesSeparated[$i] ;
		}
	}
	
	return @out; 
}

# Initialize dictionary with Microbiology data (to take care of number of bits in values)
sub initDictionary {
	my ($allData) = @_ ;
	
	# Read Microbiology information
	my $tableName = "D_MICROBIOLOGY" ;
	readLookupTable($tableName) ;
	my $table = $lookups{$tableName} ;
	
	# 7K - Specimen . Allow 7 bits
	addToMBDict($allData,"NoSpecimen","MicroBiologySpecimenValues") ;
	map {addToMBDict($allData,$table->{forward}->{$_},"MicroBiologySpecimenValues")} grep {($_ > 70001 and $_ < 80000)} keys %{$table->{forward}} ;
	die "Too many specimen ids ($allData->{dictIndex})" if ($allData->{dictIndex} > (1<<$bitsPerSpecimen)) ;

	# 8K - Organism. Allow 9 bits
	addToMBDict($allData,"NoOrganism","MicroBiologyOrganismValues") ;
	map {addToMBDict($allData,$table->{forward}->{$_},"MicroBiologyOrganismValues")} grep {($_ > 80001 and $_ < 90000)} keys %{$table->{forward}};
	die "Too many organism ids ($allData->{dictIndex})" if ($allData->{dictIndex} > (1<<$bitsPerOrganism)) ;
	
	# 9K - Antibacterium. Allow 9 bits
	addToMBDict($allData,"NoAntiBacterium","MicroBiologyAntiBacteriumValues") ;
	map {addToMBDict($allData,$table->{forward}->{$_},"MicroBiologyAntiBacteriumValues")} grep {($_ > 90001 and $_ < 100000)} keys %{$table->{forward}} ;
	die "Too many antibacterium ids ($allData->{dictIndex})" if ($allData->{dictIndex} > (1<<$bitsPerAntibacterium)) ;
}


sub readLookupTable {
	my ($table) = @_ ;
	
	my $file = "$config{LookUpDir}/$table.txt" ;
	open (TBL,$file) or die "Cannot open \'$file\' for reading" ;
	
	while (<TBL>) {
		chomp ;
		my ($tempKey,@values) = mySplit ($_,",") ;
		my $value = join " ",@values ;
		$value =~ s/\s+$// ;
		$lookups{$table}->{forward}->{$tempKey} = $value ;
	}
	close TBL ;
}
		
sub lookFor {
	my ($key,$table) = @_ ;
	
	readLookupTable($table) if (! exists $lookups{$table}) ;	
	die "Cannot find $key in Lookup table $table" if (! exists $lookups{$table}->{forward}->{$key}) ;
	return $lookups{$table}->{forward}->{$key} ;
}

sub reverseLookupTable {
	my ($table) = @_ ;
	
	foreach my $key (keys %{$lookups{$table}->{forward}}) {
		my $value = $lookups{$table}->{forward}->{$key} ;
		die "Cannot reverse lookup table $table; $value has more than one key" if (exists $lookups{$table}->{reverse}->{$value}) ;
		
		$lookups{$table}->{reverse}->{$value} = $key ;
	}
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
	
	my $days = 365 * ($year-2500) ;
	$days += int(($year-2497)/4) ;
	$days -= int(($year-2401)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	
	$minute ++ if ($second > 30) ;
	
	return ($days*24*60) + ($hour*60) + $minute ;
}	

# Update stays information
sub updateStayInfo {
	my ($idData,$stayID,$time) = @_ ;
	
	if (! exists $idData->{data}->{$stayID}->{InTime} or $time < $idData->{data}->{$stayID}->{InTime}) {
		$logFH->print("Updating start time of $stayID from $idData->{data}->{$stayID}->{InTime} to $time\n") ;
		$idData->{data}->{$stayID}->{InTime} = $time ;
	}
	
	if (! exists $idData->{data}->{$stayID}->{OutTime} or $time > $idData->{data}->{$stayID}->{OutTime}) {
		$logFH->print("Updating end time of $stayID from $idData->{data}->{$stayID}->{OutTime} to $time\n") ;
		$idData->{data}->{$stayID}->{OutTime} = $time ;
	}
}

# Post process stays
sub postProcessStays {
	my ($idData) = @_ ;

	my @stays = sort {$idData->{data}->{$a}->{InTime} <=> $idData->{data}->{$b}->{InTime}} grep {$_ ne "MISSING"} keys %{$idData->{data}} ;
		
	# Look for overlaps
	for my $i (1..$#stays) {
		if ($idData->{data}->{$stays[$i-1]}->{OutTime} > $idData->{data}->{$stays[$i]}->{InTime}) {
			$logFH->print("Overlapping icu stays: $stays[$i] and $stays[$i-1]\n") ;
			my $temp = $idData->{data}->{$stays[$i-1]}->{OutTime} ; 
			$idData->{data}->{$stays[$i-1]}->{OutTime} = $idData->{data}->{$stays[$i]}->{InTime} ;
			$idData->{data}->{$stays[$i]}->{InTime} = $temp ;
			die "Problem with stay $stays[$i-1]" if ($idData->{data}->{$stays[$i-1]}->{OutTime} <= $idData->{data}->{$stays[$i-1]}->{InTime});
			die "Problem with stay $stays[$i]" if ($idData->{data}->{$stays[$i]}->{OutTime} <= $idData->{data}->{$stays[$i]}->{InTime});
			$counts{changed} ++ ;
		}
	}
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

					if (! defined $stayID) {
						$counts{bad} ++ ;
					} else {
						push @{$idData->{data}->{$stayID}},$rec ;
						$counts{good}++ ;
					}
				}
			}
		}
		delete $idData->{data}->{MISSING} ;
	}
}

# Identify ICU stay
sub getStay {
	my ($idData,$from,$to) = @_ ;
	
	# Inside ?
	foreach my $stay (keys %{$idData->{data}}) {
		return $stay if ($stay ne "MISSING" and $idData->{data}->{$stay}->{InTime} <= $from and $idData->{data}->{$stay}->{OutTime} >= $to) ;
	}
	
	# Around
	my $goodStay = "MISSING" ;
	($from,$to) = (getMinutes($from),getMinutes($to)) ;
	foreach my $stay (keys %{$idData->{data}}) {
		if ($stay ne "MISSING" and getMinutes($idData->{data}->{$stay}->{InTime})-24*60 <= $from and getMinutes($idData->{data}->{$stay}->{OutTime})+24*60 >= $to) {
			if ($goodStay ne "MISSING") {
				return "MISSING" ;
			} else {
				$goodStay = $stay ;
			}
		}
	}
	
	return $goodStay ;
}
	
# Add to dictionary
sub addToDict {
	my ($allData,$entry,$type) = @_ ;

	$allData->{dict}->{$entry} = $allData->{dictIndex}++ ;
	push @{$allData->{dictSets}->{$type}},$entry if ($type ne "");
}

sub addToMBDict {
	my ($allData,$entry,$type) = @_ ;

	$allData->{mbDict}->{$entry} = $allData->{dictIndex}++ ;
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
	
	my @reqKeys = qw/IOEventsInstructions LabEventsInstructions ChartEventsInstructions MedEventsInstructions PoeOrderInstructions/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my %instructions ;
	
	
	# Lab Signals
	readInstructions($config{LabEventsInstructions},\%instructions) ;
	
	for my $signalID (keys %instructions) {
		my $signalName = $instructions{$signalID}->{name} ;

		if (! exists $allData{dict}->{$signalName}) {
			addToDict($allData,$signalName,"LabSignals") ;
			$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}} ;
			$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal", file => "LABEVENTS", origType => "T_TimeVal"} ;

			if ($instructions{$signalID}->{type} eq "TEXT") {
				$allData->{signals}->{$signalName}->{sfiles} = $fileIds{LabEvents_S} ;
				$allData->{signalInfo}->{$signalName}->{value} = "Categorial" ;
			} else {
				$allData->{signals}->{$signalName}->{sfiles} = $fileIds{LabEvents_N} ;
				$allData->{signalInfo}->{$signalName}->{value} = "Numeric" ;
			}
		}
	
	}
	
	# Chart Signals
	%instructions = () ;
	readInstructions($config{ChartEventsInstructions},\%instructions) ;	

	for my $signalID (keys %instructions) {
		my @signalNames = (exists $instructions{$signalID}->{name}) ? ($instructions{$signalID}->{name}) : (@{$instructions{$signalID}->{names}}) ;

		foreach my $signalName (@signalNames) {

			if (! exists $allData{dict}->{$signalName}) {
				addToDict($allData,$signalName,"ChartSignals") ;
				$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}} ;
				$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal", file => "CHARTEVENTS", origType => "T_TimeVal"} ;
				
				if ($instructions{$signalID}->{type} eq "TEXT") {
					$allData->{signals}->{$signalName}->{sfiles} = $fileIds{ChartEvents_S} ;
					$allData->{signalInfo}->{$signalName}->{value} = "Categorial" ;
				} else {
					$allData->{signals}->{$signalName}->{sfiles} = $fileIds{ChartEvents_N} ;
					$allData->{signalInfo}->{$signalName}->{value} = "Numeric" ;
				}	
			}
		}
	}
	
	# IO Signals
	%instructions = () ;
	my %estimates ;
	readInstructions($config{IOEventsInstructions},\%instructions) ;
	readEstimated($config{IOEventsEstimatedSignals},\%estimates) ;

	for my $signalID (keys %instructions) {
		my $signalName = $instructions{$signalID}->{name} ;
		
		if (! exists $allData{dict}->{$signalName}) {
			addToDict($allData,$signalName,"IOSignals") ;

			if ($instructions{$signalID}->{type} eq "TEXT") {
				$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{IOEvents_S}} ;
				$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "IOEVENTS", origType => "T_TimeVal"} ;
			} else {
				$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{IOEvents_N}} ;
				$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Numeric", file => "IOEVENTS", origType => "T_TimeRangeVal"} ;

				if (exists $estimates{$signalID}) {
					$signalName .= "_Estimate" ;
					addToDict($allData,$signalName,"IOSignals") ;
					
					$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{IOEvents_S}} ;
					$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Categorial", file => "IOEVENTS", origType => "T_TimeRangeVal"} ;
				}
			}
		}
	}
	
	# Microbiology
	my $signalName = "MicroBiology" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ ;
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeLongVal}, sfiles => $fileIds{MicroBiologyEvents_N}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeLongVal" , value => "MicrobiologyCoding", file => "MICROBIOLOGYEVENTS", origType => "T_TimeLongVal"} ;								

	# ICD9
	my $signalName = "ICD9" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ ;
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ICD9}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "ICD9", origType => "T_Value"} ;		

	# Procedures
	my $signalName = "Procedure" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ ;
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{PROCEDURES}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "Procedure", origType => "T_DateVal"} ;			
		
	# Med Signals
	%instructions = () ;
	readInstructions($config{MedEventsInstructions},\%instructions) ;
	
	for my $medID (keys %instructions) {
		my $medName = $instructions{$medID}->{name} ;

		if (! exists $allData{dict}->{$medName}) {
			addToDict($allData,$medName,"MedSignals") ;
			$allData->{signals}->{$medName} = {code => $medName, signalType => $signalTypes{T_TimeVal}} ;
			$allData->{signals}->{$medName}->{sfiles} = $fileIds{MedEvents_N} ;			

			$allData->{signalInfo}->{$medName} = {type => "T_TimeVal", file => "MEDEVENTS", value => "Numeric", origType => "T_TimeVal"} ;
		}
	}

	# PoeOrder Signals
	%instructions=() ;
	readPoeInstructions($config{PoeOrderInstructions},\%instructions) ;
	
	for my $medication (keys %instructions) {
		my $medName = "POE_".($instructions{$medication}->{name});

		if (! exists $allData{dict}->{$medName}) {
			addToDict($allData,$medName,"PoeOrder_".($instructions{$medication}->{group})) ;
			$allData->{signals}->{$medName} = {code => $medName, signalType => $signalTypes{T_TimeRangeVal}} ;
			$allData->{signals}->{$medName}->{sfiles} = $fileIds{PoeOrder_N} ;			

			$allData->{signalInfo}->{$medName} = {type => "T_TimeRangeVal", file => "POE_ORDER", value => "Numeric", origType => "T_TimeRangeVal"} ;
		}

	}	
	
	# ICU Stay Signals
	for my $signalName (qw/Gender Age HospitalAdmin ID/) {
		$allData{dict}->{$signalName} = $allData{dictIndex}++ ;	
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ICU_Stays_N}} ;
		$allData->{signalInfo}->{$signalName} = {type =>  "T_TimeVal" , value => "Numeric", file => "ICUSTAY_DETAILS", origType => "T_Value"} ;									
	}
	
	for my $signalName (qw/InTime OutTime/) {
		$allData{dict}->{$signalName} = $allData{dictIndex}++ ;	
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeStamp}, sfiles => $fileIds{ICU_Stays_N}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeStamp" , value => "Numeric", file => "ICUSTAY_DETAILS", origType => "T_TimeStamp"} ;								
	}
	
	for my $signalName (qw/Destination First_Care_Unit/) {
		$allData{dict}->{$signalName} = $allData{dictIndex}++ ;	
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ICU_Stays_S}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "CENSUSEVENTS", origType => "T_Value"} ;											
	}
	
	my $signalName = "Care_Units" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ ;
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{ICU_Stays_S}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Categorial", file => "CENSUSEVENTS", origType => "T_TimeRangeVal"} ;			

	map {push @{$allData{dictSets}->{Demographics}},$_} qw/Age Gender/ ;
	map {push @{$allData{dictSets}->{ICU_Stays_Info}},$_} qw/InTime OutTime Destination First_Care_Unit Care_Units/ ;
 
	# Demographics Signals
	for my $signalName (qw/MARITAL_STATUS ETHNICITY OVERALL_PAYOR_GROUP RELIGION ADMISSION_TYPE ADMISSION_SOURCE/) {
		addToDict($allData,$signalName,"Demographics") ;
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{Demographics}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "DEMOGRAPHICEVENTS", origType => "T_Value"} ;									
	}
	
	# Comorbidities Signals
	for my $signalName (@allComorbiditySignals) {
		addToDict($allData,$signalName,"Comorbidities") ;
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{Comorbidities}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Numeric", file => "COMORBIDITY_SCORES", origType => "T_Value"} ;									
	}	
	
	# Chart/Lab Signals
	my %signals = map {($chartLabSignals{$_} => 1)} keys %chartLabSignals ;
	foreach my $signalName (values %chartLabSignals) {
		if (! exists $allData->{dict}->{$signalName}) {
			addToDict($allData,$signalName,"ChartLabSignals") ;
			$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ExtraEvents}} ;
			$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Numeric", file => "CHARTEVENTS/LABEVENTS", origType => "T_TimeVal"} ;									
		}
	}
}

# Handle Lab and Chart Signal
sub handleLabChartSignals {
	my ($idData) = @_ ;
	
	foreach my $stayID (keys %{$idData->{data}}) {
		next if (! exists $idData->{data}->{$stayID}->{ExtraEvents}) ;
		
		my @signals = sort {$a->[1] <=> $b->[1] or ($a->[1] == $b->[1] and $a->[0] =~ /CHART_/) } @{$idData->{data}->{$stayID}->{ExtraEvents}} ;
		
		my %newData ;
		foreach my $rec (@signals) {
			if ($rec->[0] =~ /^CHART_/) {
				$newData{$chartLabSignals{$rec->[0]}}->{$rec->[1]} = {value => $rec->[2], type => $chartLabSignals{$rec->[0]}} ;
			} else {
				my $signalName = $chartLabSignals{$rec->[0]};
				my $time = $rec->[1] ;
				my $prevTime = $time - 60 ; 
				my $value = $rec->[2] ;

				if (exists $newData{$signalName}->{$prevTime} and $newData{$signalName}->{$prevTime}->{value} == $value) {
					$newData{$signalName}->{$prevTime}->{type} = $rec->[0] if ($rec->[0] =~ /^BG_/) ;
				} else {
					$newData{$signalName}->{$time}->{value} = $value ;
					$newData{$signalName}->{$time}->{type} = ($rec->[0] =~ /^BG_/) ? $rec->[0] : $signalName ;
				}
			}
		}
		
		my @newData ;
		foreach my $signalName (keys %newData) {
			foreach my $time (sort {$a<=>$b} keys %{$newData{$signalName}}) {
				push @newData,[$newData{$signalName}->{$time}->{type},$time,$newData{$signalName}->{$time}->{value}] ;
			}
		}
		$idData->{data}->{$stayID}->{ExtraEvents} = \@newData ;
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
	
	# Complete units info
	foreach my $signalName (keys %chartLabSignals) {
		my $chartLabSignalName = $chartLabSignals{$signalName} ;
		next if (! exists $origUnits{$signalName}) ;
		die "Inconsistent units for $signalName" if (exists $origUnits{$chartLabSignalName} and $origUnits{$chartLabSignalName} ne $origUnits{$signalName}) ;
		$origUnits{$chartLabSignalName} = $origUnits{$signalName}
	}
		
	
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
		if ($stay ne "MISSING") {
			foreach my $signal (keys %{$allData->{SignalValuesPerStay}->{$stay}}) {
				my $num = scalar (keys %{$allData->{SignalValuesPerStay}->{$stay}->{$signal}}) ;
				$allData->{MultValuesSignals}->{$signal} += ($num > 1) ? 1:0 ;
			}
		}
	}
}
	