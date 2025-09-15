#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

use Scalar::Util qw(looks_like_number) ;

die "Usage : $0 ConfigFile [oldInfraMedVersion]" if (@ARGV != 1 and @ARGV != 2) ;
my ($configFile) = @ARGV ;
my $useOldInfraMed = (@ARGV==2) ;

# Global Parameters
my @dataSFiles = qw/Demographics ICU_Stays_S LabEvents_S ChartEvents_S IOEvents_S ICD9 PROCEDURES/ ;
my @dataNFiles = qw/ICU_Stays_N  LabEvents_N  ChartEvents_N IOEvents_N CoMorbidities MicroBiologyEvents_N ExtraEvents PoeOrder_N/ ;
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
my (%origUnits,%units,%extraUnitConversion) ;
my %reader ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my $maxTime = transformTime("9999-12-31 23:59:00 EST") ;

my $logFH ;
my $maxId = 100000 ;

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

@reqKeys = qw/LabEventsInstructions LabEventsTextValues/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

my (%labInstructions,%labNonNumericValues) ;
readInstructions($config{LabEventsInstructions},\%labInstructions) ;
readNonNumericValues($config{LabEventsTextValues},\%labInstructions,\%labNonNumericValues) ;

@reqKeys = qw/ChartEventsInstructions ChartEventsTextValues/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

my (%chartInstructions,%chartNonNumericValues) ;
readInstructions($config{ChartEventsInstructions},\%chartInstructions) ;
readNonNumericValues($config{ChartEventsTextValues},\%chartInstructions,\%chartNonNumericValues) ;

@reqKeys = qw/OutputEventsInstructions/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

my %outputInstructions ;
readInstructions($config{OutputEventsInstructions},\%outputInstructions) ;

@reqKeys = qw/InputEventsMVInstructions/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

my %inputMVInstructions ;
readInstructions($config{InputEventsMVInstructions},\%inputMVInstructions) ;

@reqKeys = qw/InputEventsCVInstructions/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

my %inputCVInstructions ;
readInstructions($config{InputEventsCVInstructions},\%inputCVInstructions) ;

@reqKeys = qw/PoeOrderInstructions/ ;
map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;

my %poeInstructions ;
readPoeInstructions($config{PoeOrderInstructions},\%poeInstructions) ;
	
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

	# ICU Stays
	doStays($dir,$id,\%idData,\%allData)  ;

	# Demographics
	doDemographics($dir,$id,\%idData,\%allData) ;

	# ICD-9
	doICD9($dir,$id,\%idData,\%allData) ;

	# Microbiology events
	doMicroBiologyEvents($dir,$id,\%idData,\%allData) ;	
	
	# Lab Events
	doLabEvents($dir,$id,\%idData,\%allData) ;	
	
	# Procedures
	doProcedures($dir,$id,\%idData,\%allData) ;

	# Chart Events
	doChartEvents($dir,$id,\%idData,\%allData) ;	

	# Prescriptions
	doPrescriptions($dir,$id,\%idData,\%allData) ;	
	
	# I/O Events
	doOutputEvents($dir,$id,\%idData,\%allData) ;	
	doInputEvents($dir,$id,\%idData,\%allData) ;	

	# Comorbidities
#	doComorbidities($dir,$id,\%idData,\%allData) ;
	
	# Post process stays
	postProcessStays(\%idData) ;

	# Update stays data
	updateData(\%idData,\%allData) ;
	
	# Transfers
	doTransfers($dir,$id,\%idData,\%allData) ;
	
	# Handle lab/chart signals
	handleLabChartSignals(\%idData) ;
	
	# Add data from past ICU (and possibly hospital) stays
	addPastData(\%idData) ;
	
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
	print STDERR "Read $nids IDs\n\n" ;
	
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
		
	my ($lines,$header) = readLines($dir,"ADMISSIONS",$inId) ;
	my %done ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;
			
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $hadmId = $rec[$header->{HADM_ID}] ;

		die "Multiple Demographics info for $id/$hadmId" if (exists $done{$id}->{$hadmId}) ;
		$done{$id}->{$hadmId} = 1 ;
		
		if (! exists $idData->{stays}->{$hadmId}) {
			$logFH->print("DEM: Cannot find ICU stay Ids for $id/$hadmId. Skipping\n")  ;
		} else {
			my $signal ;
			for my $colName (qw/MARITAL_STATUS ETHNICITY INSURANCE RELIGION ADMISSION_TYPE ADMISSION_LOCATION/) {
				
				if ($colName eq "INSURANCE") {
					$signal = "OVERALL_PAYOR_GROUP" ;
				} elsif ($colName eq "ADMISSION_LOCATION") {
					$signal = "ADMISSION_SOURCE" ;
				} else {
					$signal = $colName ;
				}
				
				my $desc = $rec[$header->{$colName}] ;

				if ($desc ne "") {
					$desc .= "_$signal" if ($desc eq "OTHER") ;
					addToDict($allData,$desc,"Demographics") if (! exists $allData->{dict}->{$desc})  ;
					addToSignalValues($allData,$signal,$desc) ;
					
					foreach my $stay (@{$idData->{stays}->{$hadmId}}) {
						my $stayInTime = $idData->{data}->{$stay}->{InTime} ;
						push @{$idData->{data}->{$stay}->{Demographics}},[$signal,$stayInTime,$desc]  ;
						$allData->{SignalValuesPerStay}->{$stay}->{$signal}->{$desc} = 1 ;
					}
				}
			}
			
			# Admission Time
			my $adminTime = transformTime($rec[$header->{ADMITTIME}]) ;
			my $signal = "HADMIN_TIME" ;
			foreach my $stay (@{$idData->{stays}->{$hadmId}}) {
				push @{$idData->{data}->{$stay}->{Demographics_N}},[$signal,$adminTime] ;
				$allData->{SignalValuesPerStay}->{$stay}->{$signal}->{$adminTime} = 1 ;
			}
			
			# Alive at discharge ? 
			my $dischTime = transformTime($rec[$header->{DISCHTIME}]) ;
			my $hospAlive = 1 - $rec[$header->{HOSPITAL_EXPIRE_FLAG}] ;
			$signal = "HOSPITAL_DISCHARGE_ALIVE" ;
			foreach my $stay (@{$idData->{stays}->{$hadmId}}) {
				push @{$idData->{data}->{$stay}->{Demographics}},[$signal,$dischTime,$hospAlive] ;
				$allData->{SignalValuesPerStay}->{$stay}->{$signal}->{$hospAlive} = 1 ;
			}	
		}	
	}
	
	close IN ;
}

# Handle ICU Stays
sub doStays {
	my ($dir,$inId,$idData,$allData) = @_ ;
		
	my ($lines,$header) = readLines($dir,"ICUSTAYS",$inId) ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;
  
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $stayID = $rec[$header->{ICUSTAY_ID}] ;
		next if ($stayID eq "") ;
		
		my $hadmID = $rec[$header->{HADM_ID}] ;
			
		push @{$idData->{stays}->{$hadmID}},$stayID ;
			
		die "Missing inTIme. Quitting" if ($rec[$header->{INTIME}] == "") ;
		my $inTime = $idData->{data}->{$stayID}->{InTime} = transformTime($rec[$header->{INTIME}]) ;
		
		if ($rec[$header->{OUTTIME}] == "") {
			$logFH->print("STAYS: Missing outTime for $stayID/$id. Setting to inTime\n") ;
			$rec[$header->{OUTTIME}] = $rec[$header->{INTIME}] ;
		}
		my $outTime = $idData->{data}->{$stayID}->{OutTime} = transformTime($rec[$header->{OUTTIME}]) ;
		
		$idData->{earliestTime} = $idData->{data}->{$stayID}->{InTime} if (! exists $idData->{earliestTime} or $idData->{data}->{$stayID}->{InTime} < $idData->{earliestTime}) ;
			
		push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["InTime",$inTime] ;
		$allData->{SignalValuesPerStay}->{$stayID}->{InTime}->{$inTime} = 1 ;
			
		push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["OutTime",$outTime] ;
		$allData->{SignalValuesPerStay}->{$stayID}->{OutTime}->{$outTime} = 1 ;
		
		push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["OrigStayID",$inTime,$stayID] ;
		$allData->{SignalValuesPerStay}->{$stayID}->{OrigStayID}->{$stayID} = 1 ;
		
		if ($hadmID ne "") {
			push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["HospitalAdmin",$inTime,$hadmID] ;
			$allData->{SignalValuesPerStay}->{$stayID}->{HospitalAdmin}->{$hadmID} = 1 ;
		}
		
		if ($id ne "") {
			push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["ID",$inTime,$id] ;
			$allData->{SignalValuesPerStay}->{$stayID}->{ID}->{$id} = 1 ;
		}	
		
		#dbSource
		$idData->{data}->{$stayID}->{dbSource} = $rec[$header->{DBSOURCE}]  ;
	}
	
	($lines,$header) = readLines($dir,"PATIENTS",$inId) ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;
		
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $gender = $rec[$header->{GENDER}] ;
		my $timeOb = ($rec[$header->{DOB}] eq "") ? -1 : transformTime($rec[$header->{DOB}]) ;

		if (exists $idData->{data}) {
			foreach my $stayID (keys %{$idData->{data}}) {		
				if ($gender eq "M") {
					push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["Gender",$idData->{data}->{$stayID}->{InTime},1] ;
					$allData->{SignalValuesPerStay}->{$stayID}->{Gender}->{1} = 1 ;
				} elsif ($gender eq "F") {
					push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["Gender",$idData->{data}->{$stayID}->{InTime},2] ;
					$allData->{SignalValuesPerStay}->{$stayID}->{Gender}->{2} = 1 ;
				} else {
					$logFH->print("STAYS: Unknown gender \'$gender\' for $stayID\n") ;
				}
				
				if ($timeOb != -1) {
					my $age = int(($idData->{data}->{$stayID}->{InTime} - $timeOb)/365/24/60) ;
					push @{$idData->{data}->{$stayID}->{ICU_Stays_N}},["Age",$idData->{data}->{$stayID}->{InTime},$age] ; 
					$allData->{SignalValuesPerStay}->{$stayID}->{Age}->{$age} = 1 ;
				}
			}
		}
	}
}

# Handle LAB Events
sub doLabEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;
			
	my ($lines,$header) = readLines($dir,"LABEVENTS",$inId) ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $hadmId = $rec[$header->{HADM_ID}] ;
		my $itemID = $rec[$header->{ITEMID}] ;
		
		if (exists $labInstructions{$itemID}) {
			my $time = transformTime($rec[$header->{CHARTTIME}]) ;
			
			my $signalName = $labInstructions{$itemID}->{name} ;
			if ($labInstructions{$itemID}->{type} eq "TEXT") {
				my $nonNumericValue = $rec[$header->{VALUE}] ;
				$nonNumericValue =~ s/\"//g; 
				if ($nonNumericValue !~ /\S/) {
					$logFH->print("LAB: Cannot find value for $signalName for $id at $time\n") ;
				} else {
					addToDict($allData,$nonNumericValue,"") if (! exists $allData->{dict}->{$nonNumericValue});
					addToSignalValues($allData,$signalName,$nonNumericValue) ;
					die "Cannot handle lab/chart signal" if (exists $chartLabSignals{$signalName}) ;
					map {push @{$idData->{data}->{$_}->{LabEvents_S}},[$signalName,$time,$nonNumericValue]} (@{$idData->{stays}->{$hadmId}}) ;
				}
			} else {
				my $value = $rec[$header->{VALUENUM}] ;
				if ($value eq "") {
					my $nonNumericValue = $rec[$header->{VALUE}] ;
					$nonNumericValue =~ s/\"//g;
					if ($nonNumericValue !~ /\S/) {
						$logFH->print("LAB: Cannot find value for $signalName for $id at $time\n") ;
					} elsif (!exists $labNonNumericValues{$signalName}->{lc($nonNumericValue)}) {
						$logFH->print("LAB: Ignoring non numeric values $nonNumericValue for $signalName for $id at $time\n") ;
					} else {
						$value = $labNonNumericValues{$signalName}->{lc($nonNumericValue)} ;
						my $unit = lc($rec[$header->{VALUEUOM}]) ;
						if (!exists $units{$signalName}->{$unit}) {
							$logFH->print("LAB: Cannot analyze unit \'$unit\' for $signalName\n") ;
						} else {
							$value *= $units{$signalName}->{$unit} ;
							my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "LabEvents_N" ;
							map {push @{$idData->{data}->{$_}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)]} (@{$idData->{stays}->{$hadmId}}) ;
						}						
					}
				} else {
					my $unit = lc($rec[$header->{VALUEUOM}]) ;
					if (!exists $units{$signalName}->{$unit}) {
						$logFH->print("LAB: Cannot analyze unit \'$unit\' for $signalName\n") ;
					} else {
						$value *= $units{$signalName}->{$unit} ;
						my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "LabEvents_N" ;
						map {push @{$idData->{data}->{$_}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)]} (@{$idData->{stays}->{$hadmId}}) ;
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
	
	my ($lines,$header) = readLines($dir,"CHARTEVENTS",$inId) ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;
		
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $stayID = $rec[$header->{ICUSTAY_ID}] ;
		$stayID = "MISSING" if ($stayID eq "") ;
		my $itemID = $rec[$header->{ITEMID}] ;

		if (exists $chartInstructions{$itemID}) {
			my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				
			my $signalName = $chartInstructions{$itemID}->{name} ;
			if ($chartInstructions{$itemID}->{type} eq "TEXT") {
				my $nonNumericValue = $rec[$header->{VALUE}] ;
				$nonNumericValue =~ s/\"//g; 
					
				if ($nonNumericValue eq "") {
					$logFH->print("CHART: Cannot find value for $signalName for $id at $time\n") ;
				} else {
					addToDict($allData,$nonNumericValue,"") if (! exists $allData->{dict}->{$nonNumericValue});
					addToSignalValues($allData,$signalName,$nonNumericValue) ;
					die "Cannot handle lab/chart signal" if (exists $chartLabSignals{$signalName}) ;
					push @{$idData->{data}->{$stayID}->{ChartEvents_S}},[$signalName,$time,$nonNumericValue] ;
					updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
				}
			} else {
				my $value = $rec[$header->{VALUENUM}] ; 
				if ($value eq "") {
					my $nonNumericValue = $rec[$header->{VALUE}] ;
					$nonNumericValue =~ s/\"//g; 
					if ($nonNumericValue eq "") {
						$logFH->print("CHART: Cannot find value for $signalName for $id at $time\n") ;
					} elsif ($signalName eq "CHART_I:E_Ratio") { #### SPECIAL CARE OF I:E Ratio Data
						if ($nonNumericValue =~ /^(\S+):(\S+)$/ and looks_like_number($1) and looks_like_number($2) and $2 != 0) {
							my $ratio = $1/$2 ;
							my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "ChartEvents_N" ;
							push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,$ratio] ;
							updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
						} else {
							$logFH->print("CHART: Ignoring non numeric values $nonNumericValue for $signalName for $id at $time\n") ;
						}
					} elsif (!exists $chartNonNumericValues{$signalName}->{lc($nonNumericValue)}) {
						$logFH->print("CHART: Ignoring non numeric values $nonNumericValue for $signalName for $id at $time\n") ;
					} else {
						$value = $chartNonNumericValues{$signalName}->{lc($nonNumericValue)} ;
						my $unit = lc($rec[$header->{VALUE1UOM}]) ;
						if (!exists $units{$signalName}->{$unit}) {
							$logFH->print("CHART: Cannot analyze unit \'$unit\' for $signalName\n") ;
						} else {
							$value *= $units{$signalName}->{$unit} ;
							my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "ChartEvents_N" ;
							push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)] ;
							updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
						}						
					}
				} else {
					my $unit = lc($rec[$header->{VALUEUOM}]) ;
					if (!exists $units{$signalName}->{$unit}) {
						$logFH->print("CHART: Cannot analyze unit \'$unit\' for $signalName\n") ;
					} elsif ($signalName eq "CHART_I:E_Ratio") { #### SPECIAL CARE OF I:E Ratio Data							
						$logFH->print("CHART: I:E Ratio has a single value $value for $id at $time\n") ;
					} else {
						$value *= $units{$signalName}->{$unit} ;
						# Extra Unit conversion: Fahrenheit2Celsius
						if (exists $extraUnitConversion{$signalName}->{$unit}) {
							if ($extraUnitConversion{$signalName}->{$unit} eq "Fahrenheit2Celsius") {
								$value = ($value - 32.0)*5.0/9.0 ;
							} else {
								die "Unknown extra unit conversion \'$extraUnitConversion{$signalName}->{$unit}\'\n" ;
							}
						}
						
						my $destFile = (exists $chartLabSignals{$signalName}) ? "ExtraEvents" : "ChartEvents_N" ;
						push @{$idData->{data}->{$stayID}->{$destFile}},[$signalName,$time,fixResolution($signalName,$value)] ;
						updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
					}
				}
			} 
		}
	}
	close IN ;
}

# Handle IO Events
sub doOutputEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;
	
	my ($lines,$header) = readLines($dir,"OUTPUTEVENTS",$inId) ;
	
	my %outputEvents ;	
	foreach my $line (@$lines) {
		my @rec = @$line ;

		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $stayID = $rec[$header->{ICUSTAY_ID}] ;
		$stayID = "MISSING" if ($stayID eq "") ;
		my $itemID = $rec[$header->{ITEMID}] ;
		
		if (exists $outputInstructions{$itemID}) {
			my $time = transformTime($rec[$header->{CHARTTIME}]) ;
			push @{$outputEvents{$itemID}->{$stayID}},[$time,$line] ;
#			updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
		}
	}
	
	foreach my $itemID (keys %outputEvents) {
		foreach my $stayID (keys %{$outputEvents{$itemID}}) {
		
			my $prevTime = -1 ;
			my @lines = map {$_->[1]} sort {$a->[0] <=> $b->[0]} @{$outputEvents{$itemID}->{$stayID}} ;
			
			foreach my $line (@lines) {
				my @rec = @$line ;
				my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				my $signalName = $outputInstructions{$itemID}->{name} ;
				
				if ($rec[$header->{STOPPED}] ne "") {
					my $stopped = lc($rec[$header->{STOPPED}]) ;
					$logFH->print("OUT: Signal $signalName [$itemID] at $stayID/$time : $stopped\n") ;
					if ($stopped eq "stopped" or $stopped eq "d/c'd") {
						$prevTime = -1 ;
						$prevTime = -1 ;
					} elsif ($stopped eq "restart" or $stopped eq "notstopd") {
						$prevTime = $time ;
					}
				} else {
					my $value = $rec[$header->{VALUE}] ;	
					if ($value eq "") {
						$logFH->print("OUT: Signal IO:$signalName [$itemID] at $stayID/$time : MISSING VALUE\n") ;
					} else {
						my $unit = lc($rec[$header->{VALUEUOM}]) ;
						if (!exists $units{$signalName}->{$unit}) {
							$logFH->print("OUT: Cannot analyze unit \'$unit\' for $signalName at $inId/$stayID/$time ($rec[$header->{CHARTTIME}])\n") ;
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

sub doInputEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;
	
	# CV/MV input
	my $cv = doInputCV($dir,$inId,$idData,$allData) ;
	my $mv = doInputMV($dir,$inId,$idData,$allData) ;
	
	# dbSource
	my $signalName = "InputSignalsSystem" ;
	foreach my $stay (keys %{$idData->{data}}) {
		next if ($stay eq "MISSING") ;
		
		my $dbSource ;
		if ($idData->{data}->{$stay}->{dbSource} eq "carevue") {
			if (exists $mv->{$stay}) {
				$logFH->print("IN: MV/CV inconsistency $inId/$stay\n") ;
				$dbSource = "Mixed" ;
			} elsif (exists $cv->{$stay}) {
				$dbSource = "CareVue" ;
			} else {
				$dbSource = "CareVueInduced" ;
			}
		} elsif ($idData->{data}->{$stay}->{dbSource} eq "metavision") {
			if (exists $cv->{$stay}) {
				$logFH->print("IN: MV/CV inconsistency $inId/$stay\n") ;
				$dbSource = "Mixed" ;
			} elsif (exists $mv->{$stay}) {
				$dbSource = "Metavision" ;
			} else {
				$dbSource = "MetavisionInduced" ;
			}
		} else {
			die "Missing dbSource for $inId/$stay\n" ;
		}

		addToDict($allData,$dbSource,"") if (! exists $allData->{dict}->{$dbSource}) ;	
		addToSignalValues($allData,$signalName,$dbSource) ;		
		my $stayInTime = $idData->{data}->{$stay}->{InTime} ;
		push @{$idData->{data}->{$stay}->{IOEvents_S}},[$signalName,$stayInTime,$dbSource]  ;	
	}
	
}

sub doInputMV {
	my ($dir,$inId,$idData,$allData) = @_ ;
	
	# CareView Input Events
	my ($lines,$header) = readLines($dir,"INPUTEVENTS_MV",$inId) ;
	
	my %stays ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;

		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $stayID = $rec[$header->{ICUSTAY_ID}] ;
		$stays{$stayID}=1 if ($stayID ne "") ;
		$stayID = "MISSING" if ($stayID eq "") ;
		my $itemID = $rec[$header->{ITEMID}] ;
		if (exists $inputMVInstructions{$itemID}) {
			my $signalName = $inputMVInstructions{$itemID}->{name} ;
			my $startTime = transformTime($rec[$header->{STARTTIME}]) ;
			my $endTime = transformTime($rec[$header->{ENDTIME}]) ;
			
			if ($startTime > $endTime) {
				$logFH->print("IN: Signal $signalName for $stayID StartTime ($startTime) after endTime ($endTime)\n") ;
				next ;
			}
			
			my $amount = $rec[$header->{AMOUNT}] ;	
			my $rate = $rec[$header->{RATE}] ;
			
			if ($amount eq "" and $rate eq "") {
				$logFH->print("IN: Signal INPUT:$signalName [$itemID] at $stayID/$startTime/$endTime : MISSING VALUE\n") ;
			} else {
				if ($amount ne "") {
					my $unit = lc($rec[$header->{AMOUNTUOM}]) ;
					if (!exists $units{$signalName}->{$unit}) {
						$logFH->print("IN: Cannot analyze unit \'$unit\' for $signalName\n") ;
					} else {
						$amount *= $units{$signalName}->{$unit} ;
						push @{$idData->{data}->{$stayID}->{IOEvents_N}},[$signalName,$startTime,$endTime,$amount] ;
					}
				}
				
				if ($rate ne "") {
					my $unit = lc($rec[$header->{RATEUOM}]) ;
					my $rateSignalName = ($unit =~ /.+kg.+/) ? ($signalName."-k_Rate") : ($signalName."_Rate")  ;
					
					if (!exists $units{$rateSignalName}->{$unit}) {
						$logFH->print("IN: Cannot analyze unit \'$unit\' for $rateSignalName\n") ;
					} else {
						$rate *= $units{$rateSignalName}->{$unit} ;
						# Extra Unit conversion: dividing by patient weight
						if (exists $extraUnitConversion{$rateSignalName}->{$unit}) {
							if ($extraUnitConversion{$rateSignalName}->{$unit} =~/:(\S+)/) {
								my $field = $1 ;
								if (exists $header->{$field}) {
									$rateSignalName = $signalName."-k_Rate" if ($field eq "PATIENTWEIGHT") ;
									if ($rec[$header->{$field}] + 0 == 0) {
										$logFH->print("IN: Cannot normalize $rateSignalName for $stayID/$startTime by $field:$rec[$header->{$field}]") ;
									} else {
										$rate /= $rec[$header->{$field}] ;
									}
								} else {
									$logFH->print("IN: Cannot normalize $rateSignalName for $stayID/$startTime by field $field") ;
								}
							} else {
								$logFH->print("IN: Cannot normalize $rateSignalName for $stayID/$startTime by $extraUnitConversion{$rateSignalName}->{$unit}") ;
							}
						}
						
						push @{$idData->{data}->{$stayID}->{IOEvents_N}},[$rateSignalName,$startTime,$rate] ;
					}							
				}
			}
		}
	}
	
	return \%stays ;
}

sub doInputCV {
	my ($dir,$inId,$idData,$allData) = @_ ;

	# CareView Input Events
	my ($lines,$header) = readLines($dir,"INPUTEVENTS_CV",$inId) ;
	
	my %inputEvents ;
	my %stays ;	
	foreach my $line (@$lines) {
		my @rec = @$line ;

		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $stayID = $rec[$header->{ICUSTAY_ID}] ;
		$stays{$stayID}=1 if ($stayID ne "") ;
		$stayID = "MISSING" if ($stayID eq "") ;
		my $itemID = $rec[$header->{ITEMID}] ;
		

		if (exists $inputCVInstructions{$itemID}) {
			my $time = transformTime($rec[$header->{CHARTTIME}]) ;
			push @{$inputEvents{$itemID}->{$stayID}},[$time,$line] ;
#			updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
		}
	}
	
	foreach my $itemID (keys %inputEvents) {
		foreach my $stayID (keys %{$inputEvents{$itemID}}) {
		
			my $prevTime = -1 ;
			my @lines = map {$_->[1]} sort {$a->[0] <=> $b->[0]} @{$inputEvents{$itemID}->{$stayID}} ;
			
			foreach my $line (@lines) {
				my @rec = @$line ;
				my $time = transformTime($rec[$header->{CHARTTIME}]) ;
				my $signalName = $inputCVInstructions{$itemID}->{name} ;
				
				if ($rec[$header->{STOPPED}] ne "") {
					my $stopped = lc($rec[$header->{STOPPED}]) ;
					$logFH->print("IN: Signal $signalName [$itemID] at $stayID/$time : $stopped\n") ;
					if ($stopped eq "stopped" or $stopped eq "d/c'd") {
						$prevTime = -1 ;
						$prevTime = -1 ;
					} elsif ($stopped eq "restart" or $stopped eq "notstopd") {
						$prevTime = $time ;
					}
				} else {
					my $value = $rec[$header->{AMOUNT}] ;	
					if ($value eq "") {
						my $rate = $rec[$header->{RATE}] ;
						if ($rate eq "") {
							$logFH->print("IN: Signal INPUT:$signalName [$itemID] at $stayID/$time : MISSING VALUE\n") ;
						} else {
							my $unit = lc($rec[$header->{RATEUOM}]) ;
							my $rateSignalName = ($unit =~ /.+kg.+/) ? ($signalName."-k_Rate") : ($signalName."_Rate")  ;
							if (!exists $units{$rateSignalName}->{$unit}) {
								$logFH->print("IN: Cannot analyze unit \'$unit\' for $rateSignalName\n") ;
							} else {
								$rate *= $units{$rateSignalName}->{$unit} ;
								push @{$idData->{data}->{$stayID}->{IOEvents_N}},[$rateSignalName,$time,$rate] ;
							}							
						}
					} else {
						my $unit = lc($rec[$header->{AMOUNTUOM}]) ;
						if (!exists $units{$signalName}->{$unit}) {
							$logFH->print("IN: Cannot analyze unit \'$unit\' for $signalName\n") ;
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
	
	return \%stays ;
}

# Handle Microbiology Event
sub doMicroBiologyEvents {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my ($specimen,$organism,$antibact,$interept) = ("","","","") ;
	my %interpatations = ("S" => 1, "P" => 0, "I" => 0, "R" => 2, "U" => 0) ;
	
	my ($lines,$header) = readLines($dir,"MICROBIOLOGYEVENTS",$inId) ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $hadmId = $rec[$header->{HADM_ID}] ;
			
		if (! exists $idData->{stays}->{$hadmId}) {
			$logFH->print("MicroB: Cannot find ICU stay Ids for $id/$hadmId. Skipping\n")  ;
		} else {
			my $time ;
			if ($rec[$header->{CHARTTIME}] ne "") {
				$time = transformTime($rec[$header->{CHARTTIME}]) ;
			} elsif ($rec[$header->{CHARTDATE}] ne "") {
				$time = transformTime($rec[$header->{CHARTDATE}]) + 24*60 - 1 ;
			} else {
				$time = $maxTime ;
			}
	
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
	close IN ;
}

# Handle Transfers
sub doTransfers {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my $maxStaysPerId = 5 ;
	
	my ($lines,$header) = readLines($dir,"TRANSFERS",$inId) ;
	
	my %careUnits ;
	
	my @stayIds = sort {$idData->{data}->{$a}->{InTime} <=> $idData->{data}->{$b}->{InTime}} keys %{$idData->{data}} ;
	for my $idx (0..$#stayIds-1) {
		die "Problem with transfers of $inId" if ($idData->{data}->{$stayIds[$idx]}->{OutTime} >= $idData->{data}->{$stayIds[$idx+1]}->{InTime}) ;
	}
	return if (@stayIds == 0) ;
	
	# Keep only first stays
	my %goodStays = map{($stayIds[$_] => 1)} (0..($maxStaysPerId-1)) ;
	foreach my $stayId (@stayIds) {
		if (! exists $goodStays{$stayId}) {
			$logFH->print("TRSF: Removing stay $stayId/$inId\n") ;
			delete $idData->{data}->{$stayId} ;
		}
	}
	
	my @recs ;
	foreach my $line (@$lines) {
		my @rec = @$line ;
		my $id = $rec[$header->{SUBJECT_ID}] ;
		die "Id Mismatch at transfers ($id vs $inId)" if ($id != $inId) ;	
		
		my %rec ;
		($rec{inTime},$rec{outTime}) = map {($rec[$header->{$_}]=="") ? -1 : transformTime($rec[$header->{$_}])} qw/INTIME OUTTIME/ ;
		($rec{adminID},$rec{stayID}) = map {$rec[$header->{$_}]} qw/HADM_ID ICUSTAY_ID/ ;
		($rec{prevCareUnit},$rec{currCareUnit},$rec{prevWardId},$rec{currWardId}) = map {$rec[$header->{$_}]} qw/PREV_CAREUNIT CURR_CAREUNIT PREV_WARDID CURR_WARDID/ ;
		$rec{event} = $rec[$header->{EVENTTYPE}] ;
		push @recs,\%rec ;
	}
	
	return if (@recs == 0) ;
	
	# first transfer = admit
	$logFH->print("TRSF: Problem at first trasnfer for $inId\n") if ($recs[0]->{event} ne "admit") ;
	
	# Last transfer = discharge
	$logFH->print("TRSF: Problem at last trasnfer for $inId\n") if ($recs[-1]->{event} ne "discharge") ;

	# Locate trasnfers corresponding to ICU stays
	my %stayRecs ;
	foreach my $index (0..$#recs) {
		if ($recs[$index]->{stayID} ne "") {
			my $stayID = $recs[$index]->{stayID} ;
			if (!exists $idData->{data}->{$stayID}) {
				$logFH->print("TRSF: UnKnown stayId $stayID for $inId\n") ;
			} else {
				push @{$stayRecs{$stayID}},$index ;
			}
		}
	}
	
	# Process stayids
	foreach my $stayID (keys %stayRecs) {
		my @inds = @{$stayRecs{$stayID}} ;
		
		# Sanity
		my $inTime = $recs[$inds[0]]->{inTime} ;
		my $outTime = $recs[$inds[-1]]->{outTime} ;
		$logFH->print("TRSF: Timing mismatch for inId/$stayID\n") if ($inTime != $idData->{data}->{$stayID}->{InTime} or $outTime != $idData->{data}->{$stayID}->{OutTime}) ;

		# Add Extra Signals
		# Source/Destination and Care_Units
		my ($source,$discharge) ;
			
		# Source
		if ($recs[$inds[0]]->{event} eq "admit") {
			$source = "hospitalAdmission" ;
		} else {
			$logFH->print("TRSF : ICU admission from ICU for $inId/$stayID\n") if ($recs[$inds[0]]->{prevCareUnit} ne "") ;
			$source = "ward" ;
		}
		addToDict($allData,$source,"") if (! exists $allData->{dict}->{$source})  ;
		addToSignalValues($allData,"source",$source) ;
		push @{$idData->{data}->{$stayID}->{ICU_Stays_S}},["source",$inTime,$source] ;
		$allData->{SignalValuesPerStay}->{$stayID}->{"source"}->{$source} = 1 ;
		
		# Destination
		if ($recs[$inds[-1]+1]->{event} eq "discharge") {
			$discharge = "hospitalDischarge" ;
		} else {
			$discharge = "ward" ;
		}
		addToDict($allData,$discharge,"") if (! exists $allData->{dict}->{$discharge})  ;
		addToSignalValues($allData,"dischargeDestination",$discharge) ;
		push @{$idData->{data}->{$stayID}->{ICU_Stays_S}},["dischargeDestination",$outTime,$discharge] ;
		$allData->{SignalValuesPerStay}->{$stayID}->{"dischargeDestination"}->{$discharge} = 1 ;

		# Care Units
		my @careUnits = map {[$recs[$_]->{currCareUnit},$recs[$_]->{inTime},$recs[$_]->{outTime}]} grep {$recs[$_]->{currCareUnit} ne ""} @inds ;
		if (@careUnits) {
			push @{$idData->{data}->{$stayID}->{ICU_Stays_S}},["First_Care_Unit",$careUnits[0]->[1],$careUnits[0]->[0]] ;
			addToDict($allData,$careUnits[0]->[0],"") if (! exists $allData->{dict}->{$careUnits[0]->[0]})  ;
			addToSignalValues($allData,"First_Care_Unit",$careUnits[0]->[0]) ;				
			$allData->{SignalValuesPerStay}->{$stayID}->{First_Care_Unit}->{$careUnits[0]->[0]} = 1 ;

			foreach my $unitRec (@careUnits) {
				push @{$idData->{data}->{$stayID}->{ICU_Stays_S}},["Care_Units",$unitRec->[1],$careUnits[0]->[2],$unitRec->[0]] ;
				addToDict($allData,$unitRec->[0],"") if (! exists $allData->{dict}->{$careUnits[0]->[0]})  ;
				addToSignalValues($allData,"Care_Units",$unitRec->[0]) ;							
				$allData->{SignalValuesPerStay}->{$stayID}->{Care_Units}->{$unitRec->[0]} = 1 ;
			}
		}		
	}
}

# Handle ICD-9 Data
sub getICD9Num {
	my ($code) = @_ ;

	return -1 if ($code eq "") ;
	
	my $num ;
	if ($code =~ /^(V|E)(\S+)/) {
		$num = $2 ; 
	} else {
		$num = $code ;
	}
	
	if ($num < 1000) {
		return $num ;
	} elsif ($num < 10000) {
		return $num/10 ;
	} else {
		return $num/100 ;
	}
}

sub getICD9Prefix {
	my ($code) = @_ ;
	
	if ($code =~ /^(V|E)[0-9]+$/) {
		return $1 ;
	} else {
		return "NULL" ;
	}
}

sub doICD9 {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my %icd9Codes ;
	for my $file (qw/DIAGNOSES_ICD PROCEDURES_ICD/) {
		my $dictFile = "D_".$file ;
		my $signal = $file."9" ;
		my ($lines,$header) = readLines($dir,$file,$inId) ;
		
		foreach my $line (@$lines) {
			my @rec = @$line ;
		
			my $id = $rec[$header->{SUBJECT_ID}] ;
			my $hadmId = $rec[$header->{HADM_ID}] ;
			
			if (! exists $idData->{stays}->{$hadmId}) {
				$logFH->print("ICD: Cannot find ICU stay Ids for $id/$hadmId. Skipping\n")  ;
			} else {
				my $code = $rec[$header->{ICD9_CODE}] ;
				$icd9Codes{$hadmId}->{$code} = {num => getICD9Num($code), alpha => getICD9Prefix($code)};
				
				my $desc = lookFor($code,$dictFile,1) ;
				if ($desc eq "") { 	
					$logFH->print("ICD9: Cannot find description for $code for $id/$hadmId\n") ;
				} else {
					$desc = "$code:$desc" ;
					addToDict($allData,$desc,"") if (! exists $allData->{dict}->{$desc})  ;
					addToSignalValues($allData,$signal,$desc) ;
				
					# out-time of last icu-stay
					my $lastOutTime = -1 ;
					map {$lastOutTime = $idData->{data}->{$_}->{OutTime} if ($idData->{data}->{$_}->{OutTime} > $lastOutTime)} (@{$idData->{stays}->{$hadmId}}) ;
						
					foreach my $stayId (@{$idData->{stays}->{$hadmId}}) {
						push @{$idData->{data}->{$stayId}->{ICD9}},[$signal,$lastOutTime,$desc] ;
						$allData->{SignalValuesPerStay}->{$stayId}->{$signal}->{$desc} = 1 ;
					}
				}
			}
		}
	}
	close IN ;
	
	# Read DRG-Codes and calculate Elixhauser comorbidities
	my %comorbidityValues ;
	foreach my $hadmId (keys %icd9Codes) {
		map {$comorbidityValues{$hadmId}->{$_} = 0} @allComorbiditySignals ;
	}
	
	my ($lines,$header) = readLines($dir,"DRGCODES",$inId) ;
	foreach my $line (@$lines) {
		my @rec = @$line ; 
		
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $hadmId = $rec[$header->{HADM_ID}] ;
		my $drgCode = $rec[$header->{DRG_CODE}] ;
		
		my $drgCardiac =  (($drgCode >= 103 and $drgCode <= 108) or ($drgCode >= 110 and $drgCode <= 112) or ($drgCode >= 115 and $drgCode <= 118) or ($drgCode >= 120 and $drgCode <= 127) or $drgCode == 129
			or ($drgCode >= 132 and $drgCode <= 133) or ($drgCode >= 135 and $drgCode <= 143)) ;
		my $drgRenal = (($drgCode >= 302 and $drgCode <= 305) or ($drgCode >= 315 and $drgCode <= 333)) ;
		my $drgLiver = (($drgCode >= 199 and $drgCode <= 202) or ($drgCode >= 205 and $drgCode <= 208)) ;
		my $drgLeukemiaLymphoma = (($drgCode >= 400 and $drgCode <= 414) or $drgCode == 473 or $drgCode == 492) ;
		my $drgCancer = ($drgCode == 10 or $drgCode == 11 or $drgCode == 64 or $drgCode == 82 or $drgCode == 172 or $drgCode == 173 or $drgCode == 199 or $drgCode == 203 or $drgCode == 239
						 or ($drgCode >= 257 and $drgCode <= 260) or $drgCode == 274 or $drgCode == 275 or $drgCode == 303 or $drgCode == 318 or $drgCode == 319 or $drgCode == 338 or $drgCode == 344 or $drgCode == 346
						 or $drgCode == 347 or $drgCode == 354 or $drgCode == 355 or $drgCode == 357 or $drgCode == 363 or $drgCode == 366 or $drgCode == 367 or ($drgCode >= 406 and $drgCode <= 414)) ;
		my $drgCopd = ($drgCode == 88) ;
		my $drgPeripherialVascular = ($drgCode >= 130 and $drgCode <= 131) ;
		my $drgHyperTension = ($drgCode == 134) ;
		my $drgCerebroVascular = ($drgCode >= 14 and $drgCode <= 17) ;
		my $drgNervousSystem = ($drgCode >= 1 and $drgCode <= 35) ;
		my $drgAsthma = ($drgCode >= 96 and $drgCode <= 98) ;
		my $drgDiabetes = ($drgCode >= 294 and $drgCode <= 295) ;
		my $drgThyroid = ($drgCode == 290) ;
		my $drgEndocrine = ($drgCode >= 300 and $drgCode <= 301) ;
		my $drgKidneyTransplant = ($drgCode == 302) ;
		my $drgRenalFailureDialysis = ($drgCode >= 316 and $drgCode <= 317) ;
		my $drgEndocrine = ($drgCode >= 300 and $drgCode <= 301) ;
		my $drgGiHemorrhageUlcer = ($drgCode >= 174 and $drgCode <= 178) ;
		my $drgHIV = ($drgCode >= 488 and $drgCode <= 490) ;
		my $drgConnectiveTissue = ($drgCode >= 240 and $drgCode <= 241) ;
		my $drgCoagulation = ($drgCode == 397) ;
		my $drgObesityProcedure = ($drgCode == 288) ;
		my $drgNutritionMetabolic = ($drgCode >= 396 and $drgCode <= 398) ;
		my $drgAnemia = ($drgCode >= 395 and $drgCode <= 396) ;
		my $drgAlcoholDrug = ($drgCode >= 433 and $drgCode <= 437) ;
		my $drgPsychoses = ($drgCode == 430) ;
		my $drgDepression = ($drgCode == 426) ;
	   
		foreach my $icd9Code (keys %{$icd9Codes{$hadmId}}) {

			my $num = $icd9Codes{$hadmId}->{$icd9Code}->{num} ;
			my $alpha = $icd9Codes{$hadmId}->{$icd9Code}->{alpha} ;
			my $alpha = $icd9Codes{$hadmId}->{$icd9Code}->{alpha} ;

			$comorbidityValues{$hadmId}->{ELIXHAUSER_CONGESTIVE_HEART_FAILURE} = 1 if (!$drgCardiac and (($alpha eq "NULL") and 
							  ($num == 398.91 or $num == 402.11 or $num == 402.91 or $num == 404.11 or $num == 404.13 or $num == 404.91 or $num == 404.93 or ($num >= 428 and $num <= 428.9)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_CARDIAC_ARRHYTHMIAS} = 1 if (!$drgCardiac and ((($alpha eq "NULL") and ($num == 426.1 or $num == 426.11 or $num == 426.13 or $num == 427 or $num == 427.2 or
								$num == 427.31 or $num == 427.6 or $num == 427.9 or $num == 785 or ($num >= 426.2 and $num <= 426.53) or ($num >= 426.6 and $num <= 426.89))) or (($alpha eq "V") and 
								($num == 45 or $num == 53.3)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_VALVULAR_DISEASE} = 1	if (!$drgCardiac and ((($alpha eq "NULL") and ($num >= 93.2 and $num <= 93.24) or ($num >= 394 and $num <= 397.1) or 
								($num >= 424 and $num <= 424.91) or ($num >= 746.3 and $num <= 746.6)) or (($alpha eq "V") and ($num == 42.2 or $num == 43.3)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_PULMONARY_CIRCULATION} = 1 if (!$drgCardiac and !$drgCopd and ((($alpha eq "NULL") and ($num >= 416 and $num <= 416.9) or $num == 417.9))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_PERIPHERAL_VASCULAR} = 1 if (!$drgPeripherialVascular and ((($alpha eq "NULL") and (($num >= 440 and $num <= 440.9) or $num == 441.2 or $num == 441.4 or $num == 441.7 or
							    $num == 441.9 or ($num >= 443.1 and $num <= 443.9) or $num == 447.1 or $num == 557.1 or $num == 557.9)) or (($alpha eq "V") and ($num == 43.4)))) ; 
			$comorbidityValues{$hadmId}->{ELIXHAUSER_HYPERTENSION} = 1 if (!$drgHyperTension and !$drgCardiac and !$drgRenal and (($alpha eq "NULL") and ($num == 401.1 or $num == 401.9 or $num == 402.1 or $num == 402.9 or
								$num == 404.1 or $num == 404.9 or $num = 405.11 or $num == 405.19 or $num == 405.91 or $num == 405.99))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_PARALYSIS} = 1 if (!$drgCerebroVascular and (($alpha eq "NULL") and (($num >= 342 and $num <= 342.12) or ($num >= 342.9 and $num <= 344.9)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_OTHER_NEUROLOGICAL} = 1 if (!$drgNervousSystem and (($alpha eq "NULL") and ($num == 331.9 or $num == 332 or $num == 333.4 or $num == 333.5 or 
								($num >= 334 and $num <= 335.9) or $num == 340 or ($num >= 341.1 and $num <= 341.9) or ($num >= 345 and $num <= 345.11) or ($num >= 345.5 and $num <= 345.51) or
								($num >= 345.8 and $num <= 345.91) or $num == 348.1 or $num == 348.3 or $num == 780.3 or $num == 784.3))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_CHRONIC_PULMONARY} = 1 if (!$drgCopd and !$drgAsthma and (($alpha eq "NULL") and (($num >= 490 and $num <= 492.8) or ($num >= 493 and $num <= 493.91) or $num == 494 or
								($num >= 495 and $num <= 505) or $num == 506.4))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_DIABETES_UNCOMPLICATED} = 1 if (!$drgDiabetes and (($alpha eq "NULL") and (($num >= 250 and $num <= 250.33)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_DIABETES_COMPLICATED} = 1 if (!$drgDiabetes and (($alpha eq "NULL") and (($num >= 250.4 and $num <= 250.73) or ($num >= 250.9 and $num <= 250.93))));
			$comorbidityValues{$hadmId}->{ELIXHAUSER_HYPOTHYROIDISM} = 1 if (!$drgThyroid and !$drgEndocrine and (($alpha eq "NULL") and (($num >= 243 and $num <= 244.2) or $num == 244.8 or $num == 244.9))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_RENAL_FAILURE} = 1 if (!$drgKidneyTransplant and !$drgRenalFailureDialysis and ((($alpha eq "NULL") and ($num == 403.11 or $num == 403.91 or $num == 404.12 or
							    $num == 404.92 or $num == 585 or $num == 586)) or (($alpha eq "V") and ($num == 42 or $num == 45.1 or $num == 56 or $num == 56.8)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_LIVER_DISEASE} = 1 if (!$drgLiver and ((($alpha eq "NULL") and ($num == 70.32 or $num == 70.33 or $num == 70.54 or $num == 456 or $num == 456.1 or $num == 456.2 or 
								$num == 456.21 or $num == 571 or $num == 571.2 or $num == 571.3 or ($num >= 571.4 and $num <= 571.49) or $num == 571.5 or $num == 571.6 or $num == 571.8 or $num == 571.9 or 
								$num == 572.3 or $num == 572.8)) or (($alpha eq "V") and ($num == 42.7)))) ;
  			$comorbidityValues{$hadmId}->{ELIXHAUSER_PEPTIC_ULCER} = 1 if (!$drgGiHemorrhageUlcer and ((($alpha eq "NULL") and ($num == 531.7 or $num == 531.9 or $num == 532.7 or $num == 532.9 or $num == 533.7 or 
							    $num == 533.9 or $num == 534.7 or $num == 534.9)) or (($alpha eq "V") and ($num == 12.71)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_AIDS} = 1 if (!$drgHIV and (($alpha eq "NULL") and (($num >= 42 and $num <= 44.9)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_LYMPHOMA} = 1 if (!$drgLeukemiaLymphoma and ((($alpha eq "NULL") and (($num >= 200 and $num <= 202.38) or ($num >= 202.5 and $num <= 203.01) or
								($num >= 203.8 and $num <= 203.81) or $num == 238.6 or $num == 273.3)) or (($alpha eq "V") and ($num == 10.71 or $num == 10.72 or $num == 10.79)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_METASTATIC_CANCER} = 1 if (!$drgCancer and (($alpha eq "NULL") and (($num >= 196 and $num <= 199.1)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_SOLID_TUMOR} = 1 if (!$drgCancer and ((($alpha eq "NULL") and (($num >= 140 and $num <= 172.9) or ($num >= 174 and $num <= 175.9) or ($num >= 179 and $num <= 195.8))) or 
								(($alpha eq "V") and ($num >= 10 and $num <= 10.9)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_RHEUMATOID_ARTHRITIS} = 1 if (!$drgConnectiveTissue and ((($alpha eq "NULL") and ($num == 701 or ($num >= 710 and $num <= 710.9) or ($num >= 714 and $num <= 714.9) or 
								($num >= 720 and $num <= 720.9) or $num == 725)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_COAGULOPATHY} = 1 if (!$drgCoagulation and (($alpha eq "NULL") and (($num >= 2860 and $num <= 2869) or $num == 287.1 or ($num >= 287.3 and $num <= 287.5)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_OBESITY} = 1 if (!$drgObesityProcedure and !$drgNutritionMetabolic and (($alpha eq "NULL") and ($num == 278))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_WEIGHT_LOSS} = 1 if (!$drgNutritionMetabolic and (($alpha eq "NULL") and (($num >= 260 and $num <= 263.9)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_FLUID_ELECTROLYTE} = 1 if (!$drgNutritionMetabolic and (($alpha eq "NULL") and (($num >= 276 and $num <= 276.9)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_BLOOD_LOSS_ANEMIA} = 1 if (!$drgAnemia and (($alpha eq "NULL") and ($num == 2800))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_DEFICIENCY_ANEMIAS} = 1 if (!$drgAnemia and (($alpha eq "NULL") and (($num >= 280.1 and $num <= 281.9) or $num == 285.9))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_ALCOHOL_ABUSE} = 1 if (!$drgAlcoholDrug and ((($alpha eq "NULL") and ($num == 291.1 or $num == 291.2 or $num == 291.5 or $num == 291.8 or $num == 291.9) or
								($num >= 303.9 and $num <= 303.93) or ($num >= 305 and $num <= 305.03)) or (($alpha eq "V") and ($num == 113)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_DRUG_ABUSE} = 1 if (!$drgAlcoholDrug and (($alpha eq "NULL") and ($num == 292 or ($num >= 292.82 and $num <= 292.89) or $num == 292.9 or ($num >= 304 and $num <= 304.93) or
								($num >= 305.2 or $num <= 305.93)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_PSYCHOSES} = 1 if (!$drgPsychoses and (($alpha eq "NULL") and (($num >= 295 and $num <= 298.9) or ($num >= 299.1 and $num <= 299.11)))) ;
			$comorbidityValues{$hadmId}->{ELIXHAUSER_DEPRESSION} = 1 if (!$drgDepression and (($alpha eq "NULL") and ($num == 300.4 or $num == 301.12 or $num == 309 or $num == 309.1 or $num == 311))) ;
		}
	}

	# set comorbidities indice at last ICU discharge times
	foreach my $hadmId (keys %comorbidityValues) {
		my $lastOutTime = -1 ;
		map {$lastOutTime = $idData->{data}->{$_}->{OutTime} if ($idData->{data}->{$_}->{OutTime} > $lastOutTime)} (@{$idData->{stays}->{$hadmId}}) ;

		foreach my $stayId (@{$idData->{stays}->{$hadmId}}) {
			foreach my $elixhausers (keys %{$comorbidityValues{$hadmId}}) {
				push @{$idData->{data}->{$stayId}->{CoMorbidities}},[$elixhausers,$lastOutTime,$comorbidityValues{$hadmId}->{$elixhausers}] ;
				$allData->{SignalValuesPerStay}->{$stayId}->{$elixhausers}->{$comorbidityValues{$hadmId}->{$elixhausers}} = 1 ;
			}
		}
	}
}

# Handle Perscription Events
sub doPrescriptions {
	my ($dir,$inId,$idData,$allData) = @_ ;
	
	my ($lines,$header) = readLines($dir,"PRESCRIPTIONS",$inId) ;
	
	foreach my $line (@$lines) {
		my @rec = @$line ;
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $stayID = $rec[$header->{ICUSTAY_ID}] ;
		$stayID = "MISSING" if ($stayID eq "") ;
		my $medication = $rec[$header->{DRUG}] ;
			
		if (exists $poeInstructions{$medication}) {
			my $signalName = "PRESCRIPTION_".($poeInstructions{$medication}->{name});
			addToDict($allData,$signalName,"PRESCRIPTION_Antibiotics") if (! exists $allData->{dict}->{$signalName}) ;
			
			my ($startTime,$endTime) ;
			if ($rec[$header->{STARTDATE}] eq "") {
				$logFH->print("POE: Cannot find time for $medication for $id\n") ;
				$startTime = -1 ;
			} else {
				$startTime = transformTime($rec[$header->{STARTDATE}]) + 24*60-1 ;
			}
			if ($rec[$header->{ENDDATE}] eq "") {
				$logFH->print("POE: Cannot find time for $medication for $id\n") ;
				$endTime = -1 ;
			} else {
				$endTime = transformTime($rec[$header->{ENDDATE}]) + 24*60-1 ;
			}
			
			if ($startTime > $endTime) {
				$logFH->print("POE: Signal $signalName for $stayID StartTime ($startTime) after endTime ($endTime)\n") ;
				next ;
			}			
			
			my $dose = ($rec[$header->{DOSE_VAL_RX}] eq "") ? 0 : $rec[$header->{DOSE_VAL_RX}] ;
			my 	$unit = $rec[$header->{DOSE_UNIT_RX}] ;
			if (!exists $units{$signalName}->{$unit}) {
				$logFH->print("POE: Cannot analyze unit \'$unit\' for $signalName\n") ;
				$dose = 0 ;
			} else {
				$dose *= $units{$signalName}->{$unit} ;
			}
			push @{$idData->{data}->{$stayID}->{PoeOrder_N}},[$signalName,$startTime,$endTime,$dose] ;
#			updateStayInfo($idData,$stayID,$time) if ($stayID ne "MISSING") ;
		}
	}
}

# Handle Procedures
sub doProcedures {
	my ($dir,$inId,$idData,$allData) = @_ ;

	my ($lines,$header) = readLines($dir,"PROCEDUREEVENTS_MV",$inId) ;
	
	my %careUnits ;
	foreach my $line (@$lines) {
		my @rec = @$line ;
		
		my @rec = @$line ;
		my $id = $rec[$header->{SUBJECT_ID}] ;
		my $stayID = $rec[$header->{ICUSTAY_ID}] ;
		$stayID = "MISSING" if ($stayID eq "") ;
		my $itemID = $rec[$header->{ITEMID}] ;
			
		my $code = $rec[$header->{ITEMID}] ;
		die "Unknown procedure code $code" if (! exists $procedures{codes}->{$code}) ;
		if ($procedures{codes}->{$code}->{count} < $procedures{minNum}) {
			$logFH->print("PRCD: Ignoring rare procedure $code [$procedures{codes}->{$code}->{count} < $procedures{minNum}] for $id/$stayID\n") ;
			next ;
		}
			
			
		my $startTime = transformTime($rec[$header->{STARTTIME}]) ;
		my $endTime = transformTime($rec[$header->{STARTTIME}]) ;
		
		if ($endTime < $startTime) {
			$logFH->print("PRCD: EndTime before StartTime for procedure $code at $id/$stayID\n") ;
		} else {
			my $desc = $procedures{codes}->{$code}->{desc} ;					
			addToDict($allData,$desc,"") if (! exists $allData->{dict}->{$desc})  ;
			addToSignalValues($allData,"Procedure",$desc) ;				
				
			push @{$idData->{data}->{$stayID}->{PROCEDURES}},["Procedure",$startTime,$endTime,$desc]  ;
			$allData->{SignalValuesPerStay}->{$stayID}->{PROCEDURES}->{$desc} = 1 ;
		}
	}
	close IN ;
}

# Add data from past ICU (and possibly hospital) stays
sub addPastData {
	my ($idData) = @_ ;
	
	my $gapToInTime = 72*60 ; # Add data from up to 72 hours before current ICU stay
	
	# Loop on stays
	my @stays = sort {$idData->{data}->{$a}->{InTime} <=> $idData->{data}->{$b}->{InTime}} keys %{$idData->{data}} ;
	
	for my $i (1..$#stays) {
		my $inTime = $idData->{data}->{$stays[$i]}->{InTime} ;
		
		for my $j (0..$i-1) {
			foreach my $type (@dataFiles) {				
				if ($type eq "LabEvents_N" or $type eq "IOEvents_N" or $type eq "MicroBiologyEvents_N" or $type eq "PoeOrder_N" or $type eq "LabEvents_S" or $type eq "IOEvents_S" or 
					$type eq "ICD9" or $type eq "PROCEDURES" or $type eq "ExtraEvents" or $type eq "CoMorbidities") {	
						push @{$idData->{data}->{$stays[$i]}->{$type}},@{$idData->{data}->{$stays[$j]}->{$type}};
				}
			}
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
		s/\r// ; 
		
		chomp ;
		my ($signal,$unit,$factor,$extra) = split /\t/,$_ ;
		$unit = lc($unit) ;
		
		# Handle input signals dosage per kg
		$signal = $1."-k_Rate" if ($unit =~ /.+kg.+/ and $signal =~ /(INPUT_\S+)_Rate/) ;
		
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
			if ($quotesSeparated[$i] ne $separator and $quotesSeparated[$i] ne "") {
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
	my ($key,$table,$allow_missing) = @_ ;
	
	readLookupTable($table) if (! exists $lookups{$table}) ;	
	if (! exists $lookups{$table}->{forward}->{$key}) {
		die "Cannot find $key in Lookup table $table" if (! $allow_missing) ;
		return "" ;
	} else {
		return $lookups{$table}->{forward}->{$key} ;
	}
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
	print OUT "FNAMES\t$prefix.fnames_prefix\n" if ($useOldInfraMed);	
	print OUT "SIGNAL\t$prefix.signals\n" ;
	print OUT "SFILES\t$prefix.signals_to_files\n" if ($useOldInfraMed);	
	print OUT "MODE\t3\n" if (! $useOldInfraMed);	
	print OUT "PREFIX\tMedICU\n" if (! $useOldInfraMed);	
	
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
	
	if ($useOldInfraMed) {
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
}

# Get Minutes
sub getMinutes {
	my ($InTime) = @_ ;
	
	$InTime =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/ or die "Cannot parse time $InTime" ;
	my ($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6) ;
	
	my $days = 365 * ($year-1700) ;
	$days += int(($year-1697)/4) ;
	$days -= int(($year-1601)/100);

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
		$logFH->print("PRCSS: Updating start time of $stayID from $idData->{data}->{$stayID}->{InTime} to $time\n") ;
		$idData->{data}->{$stayID}->{InTime} = $time ;
	}
	
	if (! exists $idData->{data}->{$stayID}->{OutTime} or $time > $idData->{data}->{$stayID}->{OutTime}) {
		$logFH->print("PRCSS: Updating end time of $stayID from $idData->{data}->{$stayID}->{OutTime} to $time\n") ;
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
			$logFH->print("PRCSS: Overlapping icu stays: $stays[$i] and $stays[$i-1]\n") ;
			my $temp = $idData->{data}->{$stays[$i-1]}->{OutTime} ; 
			$idData->{data}->{$stays[$i-1]}->{OutTime} = $idData->{data}->{$stays[$i]}->{InTime} ;
			$idData->{data}->{$stays[$i]}->{InTime} = $temp ;
			die "Problem with stay $stays[$i-1]" if ($idData->{data}->{$stays[$i-1]}->{OutTime} <= $idData->{data}->{$stays[$i-1]}->{InTime});
			die "Problem with stay $stays[$i] [$idData->{data}->{$stays[$i]}->{InTime},$idData->{data}->{$stays[$i]}->{OutTime}]" 
												if ($idData->{data}->{$stays[$i]}->{OutTime} <= $idData->{data}->{$stays[$i]}->{InTime});
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
	
	my @reqKeys = qw/OutputEventsInstructions LabEventsInstructions ChartEventsInstructions InputEventsCVInstructions InputEventsMVInstructions/ ;
	map {die "Required key \'$_\' missing." if (! exists $config{$_})} @reqKeys ;
		
	my %instructions ;
	
	# Perscription
	readPoeInstructions($config{PoeOrderInstructions},\%instructions) ;	
	for my $signalID (keys %instructions) {
		my $signalName = "PRESCRIPTION_".($instructions{$signalID}->{name});
		addToDict($allData,$signalName,"Prescription_".($instructions{$signalID}->{group})) if (! exists $allData{dict}->{$signalName}) ;;
	
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal", file => "PERSCRITIONS", origType => "T_TimeRangeVal"} ;
		$allData->{signals}->{$signalName}->{sfiles} = $fileIds{PoeOrder_N} ;
		$allData->{signalInfo}->{$signalName}->{value} = "Numeric" ;
	}
		
	# Lab Signals
	readInstructions($config{LabEventsInstructions},\%instructions) ;
	
	for my $signalID (keys %instructions) {
		my $signalName = $instructions{$signalID}->{name} ;

		addToDict($allData,$signalName,"LabSignals")  if (! exists $allData{dict}->{$signalName}) ;
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
	
	# Chart Signals
	%instructions = () ;
	readInstructions($config{ChartEventsInstructions},\%instructions) ;	

	for my $signalID (keys %instructions) {
		my @signalNames = (exists $instructions{$signalID}->{name}) ? ($instructions{$signalID}->{name}) : (@{$instructions{$signalID}->{names}}) ;

		foreach my $signalName (@signalNames) {

			addToDict($allData,$signalName,"ChartSignals")if (! exists $allData{dict}->{$signalName}) ;
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
	
	# IO Signals
	%instructions = () ;
	my %estimates ;
	readInstructions($config{OutputEventsInstructions},\%instructions) ;

	for my $signalID (keys %instructions) {
		my $signalName = $instructions{$signalID}->{name} ;
		
		addToDict($allData,$signalName,"OutputSignals") if (! exists $allData{dict}->{$signalName}) ;

		if ($instructions{$signalID}->{type} eq "TEXT") {
			$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{IOEvents_S}} ;
			$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "OUTPUTEVENTS", origType => "T_TimeVal"} ;
		} else {
			$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{IOEvents_N}} ;
			$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Numeric", file => "OUTPUTEVENTS", origType => "T_TimeRangeVal"} ;

			if (exists $estimates{$signalID}) {
				$signalName .= "_Estimate" ;
				addToDict($allData,$signalName,"OutputSignals") ;
				
				$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{IOEvents_S}} ;
				$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Categorial", file => "OUTPUTEVENTS", origType => "T_TimeRangeVal"} ;
			}
		}
	}
	
	for my $inputInstructionsFile (qw/InputEventsCVInstructions InputEventsMVInstructions/) {
		%instructions = () ;
		readInstructions($config{$inputInstructionsFile},\%instructions) ;		
	
		for my $signalID (keys %instructions) {
			my $signalName = $instructions{$signalID}->{name} ;
			my $rateSignalName = $signalName."_Rate" ;
			my $kRateSignalName = $signalName."-k_Rate" ;
		
			addToDict($allData,$signalName,"InputSignals") if (! exists $allData{dict}->{$signalName}) ;
			addToDict($allData,$rateSignalName,"InputSignals") if (! exists $allData{dict}->{$rateSignalName});
			addToDict($allData,$kRateSignalName,"InputSignals") if (! exists $allData{dict}->{$kRateSignalName});
			
			if ($instructions{$signalID}->{type} eq "VALUE") {
				$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{IOEvents_N}} ;
				$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Numeric", file => "INPUTEVENTS", origType => "T_TimeRangeVal"} ;
				
				$allData->{signals}->{$rateSignalName} = {code => $rateSignalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{IOEvents_N}} ;
				$allData->{signalInfo}->{$rateSignalName} = {type => "T_TimeVal" , value => "Numeric", file => "INPUTEVENTS", origType => "T_TimeVal"} ;
				
				$allData->{signals}->{$kRateSignalName} = {code => $kRateSignalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{IOEvents_N}} ;
				$allData->{signalInfo}->{$kRateSignalName} = {type => "T_TimeVal" , value => "Numeric", file => "INPUTEVENTS", origType => "T_TimeVal"} ;				

			} else {
				die "Cannot handle non-value input signal $signalName" ;
			}
		}
	}

	my $signalName = "InputSignalsSystem" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ if (! exists $allData{dict}->{$signalName});
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{IOEvents_S}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "INPUTEVENTS", origType => "T_Value"} ;		
	
	# Microbiology
	my $signalName = "MicroBiology" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ if (! exists $allData{dict}->{$signalName});
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeLongVal}, sfiles => $fileIds{MicroBiologyEvents_N}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeLongVal" , value => "MicrobiologyCoding", file => "MICROBIOLOGYEVENTS", origType => "T_TimeLongVal"} ;								

	# ICD9
	foreach my $signalName (qw/DIAGNOSES_ICD9 PROCEDURES_ICD9/) {
		$allData{dict}->{$signalName} = $allData{dictIndex} ++ if (! exists $allData{dict}->{$signalName});
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ICD9}} ;	
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "ICD9", origType => "T_Value"} ;		
	}

	# Procedures
	my $signalName = "Procedure" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ if (! exists $allData{dict}->{$signalName});
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{PROCEDURES}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Categorial", file => "Procedure", origType => "T_TimeRangeVal"} ;			
	
	# Census Events
	my $signalName = "Census" ;
	$allData{dict}->{$signalName} = $allData{dictIndex} ++ if (! exists $allData{dict}->{$signalName});
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{CensusEvents}} ;	
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Numeric", file => "CENSUSEVENTS", origType => "T_TimeRangeVal"} ;		
	
	# ICU Stay Signals
	for my $signalName (qw/Gender Age HospitalAdmin ID OrigStayID/) {
		$allData{dict}->{$signalName} = $allData{dictIndex}++ if (! exists $allData{dict}->{$signalName});	
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ICU_Stays_N}} ;
		$allData->{signalInfo}->{$signalName} = {type =>  "T_TimeVal" , value => "Numeric", file => "ICUSTAY_DETAILS", origType => "T_Value"} ;									
	}
	
	for my $signalName (qw/InTime OutTime/) {
		$allData{dict}->{$signalName} = $allData{dictIndex}++ if (! exists $allData{dict}->{$signalName});	
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeStamp}, sfiles => $fileIds{ICU_Stays_N}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeStamp" , value => "Numeric", file => "ICUSTAY_DETAILS", origType => "T_TimeStamp"} ;								
	}
	
	for my $signalName (qw/dischargeDestination source First_Care_Unit/) {
		$allData{dict}->{$signalName} = $allData{dictIndex}++ if (! exists $allData{dict}->{$signalName});	
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ICU_Stays_S}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "ICUSTAY_DETAILS", origType => "T_Value"} ;											
	}
	
	my $signalName = "Care_Units" ;
	$allData{dict}->{$signalName} = $allData{dictIndex}++ if (! exists $allData{dict}->{$signalName});	
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeRangeVal}, sfiles => $fileIds{ICU_Stays_S}} ;
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeRangeVal" , value => "Categorial", file => "ICUSTAY_DETAILS", origType => "T_TimeRangeVal"} ;	

	map {push @{$allData{dictSets}->{Demographics}},$_} qw/Age Gender/ ;
	map {push @{$allData{dictSets}->{ICU_Stays_Info}},$_} qw/InTime OutTime dischargeDestination source Care_Units First_Care_Unit/ ;
 
	# Demographics Signals
	for my $signalName (qw/MARITAL_STATUS ETHNICITY OVERALL_PAYOR_GROUP RELIGION ADMISSION_TYPE ADMISSION_SOURCE/) {
		addToDict($allData,$signalName,"Demographics")if (! exists $allData{dict}->{$signalName}) ;
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{Demographics_S}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Categorial", file => "DEMOGRAPHICEVENTS", origType => "T_Value"} ;									
	}
	
	my $signalName = "HADMIN_TIME" ;
	addToDict($allData,$signalName,"Demographics") if (! exists $allData{dict}->{$signalName}) ;	
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeStamp}, sfiles => $fileIds{Demographics_N}} ;
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeStamp" , value => "Numeric", file => "DEMOGRAPHICEVENTS", origType => "T_TimeStamp"} ;	
	
	my $signalName = "HOSPITAL_DISCHARGE_ALIVE" ;
	addToDict($allData,$signalName,"Demographics") if (! exists $allData{dict}->{$signalName}) ;	
	$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{Demographics_N}} ;
	$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Numeric", file => "DEMOGRAPHICEVENTS", origType => "T_TimeVal"} ;	
	
	# Comorbidities Signals
	for my $signalName (@allComorbiditySignals) {
		addToDict($allData,$signalName,"Comorbidities") if (! exists $allData{dict}->{$signalName});
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{CoMorbidities}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Numeric", file => "CoMorbidities", origType => "T_Value"} ;									
	}	
	
	# Chart/Lab Signals
	my %signals = map {($chartLabSignals{$_} => 1)} keys %chartLabSignals ;
	foreach my $signalName (values %chartLabSignals) {
		addToDict($allData,$signalName,"ChartLabSignals")if (! exists $allData->{dict}->{$signalName});
			 ;
		$allData->{signals}->{$signalName} = {code => $signalName, signalType => $signalTypes{T_TimeVal}, sfiles => $fileIds{ExtraEvents}} ;
		$allData->{signalInfo}->{$signalName} = {type => "T_TimeVal" , value => "Numeric", file => "CHARTEVENTS/LABEVENTS", origType => "T_TimeVal"} ;									
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
		$reader{$name}->{data_fh} = FileHandle->new("$dir/$name.csv","r") or die "Cannot open \'$dir/$name.csv\' for reading" ;
        my $headerLine = $reader{$name}->{data_fh}->getline() ;
		chomp $headerLine ; $headerLine =~ s/s\r// ;
		my @fields = mySplit($headerLine,",") ;
		my %header= map {($fields[$_] => $_)} (0..$#fields) ; 
		die "File $name has no SUBJECT_ID column !" if (! exists $header{SUBJECT_ID}) ;
		
		$reader{$name}->{header} = \%header ;
        $reader{$name}->{index} = read_index("$dir/$name.idx") ;
		
	}
	
	die "Cannot get id $id (Max = $maxId)\n" if ($id > $maxId) ;
	
	my $from = $reader{$name}->{index}->[$id] ;
	if ($from != -1) {
		$reader{$name}->{data_fh}->seek($from,0) ;
		
		while (my $line = $reader{$name}->{data_fh}->getline()) {
			chomp $line ; $line =~ s/\r// ; 
			my @fields = mySplit($line,",") ;
			last if ($fields[$reader{$name}->{header}->{SUBJECT_ID}] != $id) ;
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

	
	
	
	