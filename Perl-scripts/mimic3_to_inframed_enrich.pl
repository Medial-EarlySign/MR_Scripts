#!/usr/bin/env perl 

use strict ;
use Getopt::Long;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

# Read Parameters
my $p  = {config_file => "ICU.convert_config",
#		  text_signals_file => "AdditionalSignals_S",
#		  extra_dict_file => "ICU.additional_dict",
		  signal_info_file => "SignalInfoFile",
#		  numeric_signals_file => "AdditionalSignals_N",
#		  notes_file => "//server/Work/ICU/AncillaryFiles/Sepsis.Notes",
#		  microbiology_file => "ICU.MicroBiologyEvents_N",
#		  sepsis_file => "//server/Work/Users/yaron/ICU/Mimic/Sepsis/GetSepsisInfo/GenerationOutput",
#		  diagnosis_file  => "ICU.ChartEvents_S",
#		  ie_file => "ICU.ChartEvents_S",
		  } ;
my ($help) = (0) ;
GetOptions($p,
		  "config_file=s",				# Repository File
		  "text_signals_file=s",		# Additional File For Text Signals
		  "extra_dict_file=s",			# Additional Dictionary File
		  "numeric_signals_file=s",		# Additional File For Numeric Signals  
		  "notes_file=s",				# Optional Notes File
		  "microbiology_file=s",		# Microbiology Signals File
		  "signal_info_file=s",			# SignalInfo File
		  "sepsis_file=s",				# Sepsis Info File
		  "diagnosis_file=s",			# Diagnosis Signals File
		  "antibiotics_file=s",			# First Antibiotics input File
		  "readmission_file=s",			# Readmission signals input File
		  "ie_file=s",					# I:E Ratio File
		  "useOldInfraMed",				# Use old version of inframed		  
		  ) ;
		  
die "text_signals_file required for notes" if (exists $p->{notes_file} and not exists $p->{text_signals_file}) ;
die "numeric_signals_file required for microbiologySignals and sepsisSignals" if ((exists $p->{microbiology_file} or exists $p->{sepsis_file}) and not exists $p->{numeric_signals_file}) ;

map {die "Cannot find $p->{$_}" if (exists $p->{$_} and not -e $p->{$_})} qw/notes_file microbiology_file sepsis_file/ ;

my $useOldInframed = $p->{useOldInfraMed} ;

# Read
my $config = readConfigFile($p->{config_file}) ;
my ($dir) = keys %{$config->{DIR}} ;
my $dict = readDictionary($dir,$config->{DICTIONARY}) ;

my %newDict ;
my %data ;

# Add Notes
addNotes($config,$dict,$p->{notes_file},$p->{text_signals_file},$p->{signal_info_file},\%newDict,\%data) if (exists $p->{notes_file}) ;

# Add Microbiology
addMB($config,$dict,$p->{microbiology_file},$p->{numeric_signals_file},$p->{signal_info_file},\%newDict,\%data) if (exists $p->{microbiology_file}) ;

# Add Sepsis
addSepsis($config,$dict,$p->{sepsis_file},$p->{numeric_signals_file},$p->{signal_info_file},\%newDict,\%data) if (exists $p->{sepsis_file}) ;

# Add tokenized Diagnosis
addDiagnosis($config,$dict,$p->{diagnosis_file},$p->{text_signals_file},$p->{signal_info_file},\%newDict,\%data) if ($p->{diagnosis_file}) ;

# Add I:E Ratio
addIERatio($p->{ie_file},$p->{numeric_signals_file},\%data) if (exists $p->{ie_file}) ;

# Add First Antibiotics File
addAntibiotics($config,$dict,$p->{antibiotics_file},$p->{numeric_signals_file},$p->{signal_info_file},\%newDict,\%data) if ($p->{antibiotics_file}) ;

# Add Readmission info File
addReadmision($config,$dict,$p->{readmission_file},$p->{numeric_signals_file},$p->{signal_info_file},\%newDict,\%data) if ($p->{readmission_file}) ;


# Write
delete $p->{extra_dict_file} if (! %newDict) ;

if (exists $p->{extra_dict_file}) {
	my $extraDictFile = "$dir/".$p->{extra_dict_file} ;
	writeDictionary(\%newDict,$extraDictFile) ;
}

writeConfigFile($p->{config_file},$config,$p->{extra_dict_file}) ;
writeSignals($dir,\%data) ;

print STDERR "Done\n" ;

###########################
# Functions
###########################

## Add notes
sub addNotes {
	my ($config,$dict,$notesFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e $dataFile) ;
	
	# Read
	my $notes = readNotesFile($notesFile) ;
	
	# Update
	notesUpdateDictionary($notes,$dict,$newDict) ;
	$config->{DATA_S}->{$dataFile} = -1 ;
	
	my $infoLine = join "\t",("Sepsis_Notes","T_TimeVal","Categorial","MultipleValue","","NOTESEVENTS","T_DateVal") ;
	addSignal("Sepsis_Notes",$config,$dataFile,$newDict->{def}->{Sepsis_Notes},2,$signalInfoFile,$infoLine) ;

	# Write
	addNotesSignal($notes,$dataFile,$data) ;
}

# Inspiratory + Expiratory Ratio -> I:E_Ratio
sub addIERatio {
	my ($inFile,$dataFile,$data) = @_ ;
	
	# Update Data
	$config->{DATA}->{$dataFile} = -1 ;	
	open (IN,$inFile) or die "Cannot open $inFile for reading " ;
	
	my (%inData) ;
	while (<IN>) {
		chomp ;
		my ($id,$signal,$time,$entry) = split /\t/,$_ ;
		$inData{$id}->{$time}->{$signal} = $entry if ($signal eq "CHART_ExpRatio" or $signal eq "CHART_InspRatio") ;
	}
	close IN ;	
	
	foreach my $id (keys %inData) {
		foreach my $time (keys %{$inData{$id}}) {
			
			if ((!exists $inData{$id}->{$time}->{CHART_InspRatio}) or (!exists $inData{$id}->{$time}->{CHART_ExpRatio}) or ($inData{$id}->{$time}->{CHART_ExpRatio} == 0)) {
				print STDERR "Warning: I:E cannot be calculated for $id/$time\n"  ;
			} else {
				my $ratio = $inData{$id}->{$time}->{CHART_InspRatio}/$inData{$id}->{$time}->{CHART_ExpRatio} ;
				my $line =  "$id\tCHART_I:E_Ratio\t$time\t$ratio\n" ;
				push @{$data->{$dataFile}->{$id}},$line ;
			}
		}
	}		
}	

# Tokenize diagnosis
sub addDiagnosis {
	my ($config,$dict,$diagnosisFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;
	
	die "Cannot use existing dataFile \'$dataFile\'" if (-e dataFile) ;
	
	die "Cannot find CHART_Diagnosis_OP_Values in dictionary" if (!exists $dict->{set}->{CHART_Diagnosis_OP_Values}) ;
	
	# Get All Tokens
	my %tokens ;
	foreach my $entry (@{$dict->{set}->{CHART_Diagnosis_OP_Values}}) {
		my $newEntry = uc(" $entry ") ;

		$tokens{$entry}->{"S/P"} = 1 if ($newEntry =~ s/S\/P//g) ;
		$tokens{$entry}->{"R/O"} = 1 if ($newEntry =~ s/R\/O//g) ;
		$tokens{$entry}->{"U/A"} = 1 if ($newEntry =~ s/U\/A//g) ;
		$tokens{$entry}->{"N/V"} = 1 if ($newEntry =~ s/N\/V//g) ;
		$tokens{$entry}->{$1} = 1 while ($newEntry =~ s/\s(\S\.\S\.\S)\s//) ;
		$tokens{$entry}->{$1} = 1 while ($newEntry =~ s/\s(\S\.\S)\s//) ;
		$tokens{$entry}->{$1} = 1 while ($newEntry =~ s/\s(\S\.\S)\.//) ;
		
		$newEntry =~ s/[\.\,\;\:\-\/\&\']/ /g ;
		$newEntry =~ s/\?\s+/\?/g ; 
		
		map {$tokens{$entry}->{$_} = 1} grep {length($_) > 1} split /\s+/,$newEntry ;
		
#		my $o = join " XX ", keys %{$tokens{$entry}} ; print STDERR "$entry :: $o\n" ;
	}
		
	# Update dictionary
	tokenedDiagnosisUpdateDictionary(\%tokens,$dict,$newDict) ;
	
	my $infoLine = join "\t",("CHART_Tokened_Diagnosis_OP","T_TimeVal","Categorial","MultipleValue","","CHARTEVENTS","T_TimeVal") ;
	addSignal("CHART_Tokened_Diagnosis_OP",$config,$dataFile,$newDict->{def}->{CHART_Tokened_Diagnosis_OP},2,$signalInfoFile,$infoLine) ;
	
	# Update Data
	$config->{DATA_S}->{$dataFile} = -1 ;	
	open (IN,$diagnosisFile) or die "Cannot open $diagnosisFile for reading " ;
	
	while (<IN>) {
		chomp ;
		my ($id,$signal,$time,$entry) = split /\t/,$_ ;
		if ($signal eq "CHART_Diagnosis_OP") {
			die "Cannot find tokens for \'$entry\'" if (! exists $tokens{$entry}) ;
			
			foreach my $token (keys %{$tokens{$entry}}) {
				my $line =  "$id\tCHART_Tokened_Diagnosis_OP\t$time\t$token\n" ;
				push @{$data->{$dataFile}->{$id}},$line ;
			}
		}
	}
	close IN ;	
}

# Add Microbiology 
sub addMB {
	my ($config,$dict,$microbiologyFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e $dataFile) ;
	
	# Read
	my $mb = readMBFile($microbiologyFile) ;

	# Update
	mbUpdateDictionary($dict,$newDict) ;
	$config->{DATA}->{$dataFile} = -1 ;

	my $infoLine = join "\t",("MicroBiology_Found","T_TimeVal","Numeric","MultipleValue","","MICROBIOLOGYEVENTS","T_TimeVal") ;	
	addSignal("MicroBiology_Found",$config,$dataFile,$newDict->{def}->{MicroBiology_Found},2,$signalInfoFile,$infoLine) ;

	# Write
	addMBSignals($mb,$dataFile,$dict,$data) ;
}

# Add Sepsis
sub addSepsis {
	my ($config,$dict,$sepsisFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e $dataFile) ;
	
	# Read
	my $sepsis = readLines($sepsisFile) ;

	# Update
	sepsisUpdateDictionary($dict,$newDict) ;
	$config->{DATA}->{$dataFile} = -1 ;
	
	my $infoLine = join "\t",("Sepsis_Indication","T_TimeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Sepsis_Indication",$config,$dataFile,$newDict->{def}->{Sepsis_Indication},2,$signalInfoFile,$infoLine) ;
	
	$infoLine = join "\t",("Infection_Indication","T_TimeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Infection_Indication",$config,$dataFile,$newDict->{def}->{Infection_Indication},2,$signalInfoFile,$infoLine) ;
	
	$infoLine = join "\t",("SOFA_Increase","T_TimeRangeVal","Numeric","MultipleValue","","Calculated","T_TimeRangeVal") ;	
	addSignal("SOFA_Increase",$config,$dataFile,$newDict->{def}->{SOFA_Increase},5,$signalInfoFile,$infoLine) ;
	
	$infoLine = join "\t",("Sepsis_Strict","T_TimeRangeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Sepsis_Strict",$config,$dataFile,$newDict->{def}->{Sepsis_Strict},5,$signalInfoFile,$infoLine) ;

	$infoLine = join "\t",("Sepsis","T_TimeRangeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Sepsis",$config,$dataFile,$newDict->{def}->{Sepsis},5,$signalInfoFile,$infoLine) ;	
	
	$infoLine = join "\t",("Sepsis_Stricter","T_TimeRangeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;
	addSignal("Sepsis_Stricter",$config,$dataFile,$newDict->{def}->{Sepsis_Stricter},5,$signalInfoFile,$infoLine) ;	
	
	# Write
	addSepsisSignals($sepsis,$dataFile,$data) ;
}

# Add antibiotics
sub addAntibiotics {
	my ($config,$dict,$antibioticsFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e $dataFile) ;
	
	# Read
	my $antibiotics = readLines($antibioticsFile) ;

	# Update
	antibioticsUpdateDictionary($dict,$newDict) ;
	$config->{DATA}->{$dataFile} = -1 ;
	
	my $infoLine = join "\t",("Min_Antibiotics_Prescription_Time","T_TimeVal","Numeric","SingleValue","","Calculated","T_TimeVal") ;	
	addSignal("Min_Antibiotics_Prescription_Time",$config,$dataFile,$newDict->{def}->{Min_Antibiotics_Prescription_Time},2,$signalInfoFile,$infoLine) ;
	
	my $infoLine = join "\t",("Min_Antibiotics_Input_Time","T_TimeVal","Numeric","SingleValue","","Calculated","T_TimeVal") ;	
	addSignal("Min_Antibiotics_Input_Time",$config,$dataFile,$newDict->{def}->{Min_Antibiotics_Input_Time},2,$signalInfoFile,$infoLine) ;	
	
	# Write
	addAntibioticsSignal($antibiotics,$dataFile,$data) ;
}

# Add Readmission info
sub addReadmision {
	my ($config,$dict,$readmissionFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e $dataFile) ;
	
	# Read
	my $readmission = readLines($readmissionFile) ;

	# Update
	readmissionUpdateDictionary($dict,$newDict) ;
	$config->{DATA}->{$dataFile} = -1 ;
	
	my $infoLine = join "\t",("readmitInterval","T_TimeVal","Numeric","SingleValue","","Calculated","T_TimeVal") ;	
	addSignal("readmitInterval",$config,$dataFile,$newDict->{def}->{readmitInterval},2,$signalInfoFile,$infoLine) ;
	
	my $infoLine = join "\t",("stayIndex","T_TimeVal","Numeric","SingleValue","","Calculated","T_TimeVal") ;	
	addSignal("stayIndex",$config,$dataFile,$newDict->{def}->{stayIndex},2,$signalInfoFile,$infoLine) ;	
	
	my $infoLine = join "\t",("stayCount","T_TimeVal","Numeric","SingleValue","","Calculated","T_TimeVal") ;	
	addSignal("stayCount",$config,$dataFile,$newDict->{def}->{stayCount},2,$signalInfoFile,$infoLine) ;		
	
	my $infoLine = join "\t",("ICU_DISCHARGE_ALIVE","T_TimeVal","Numeric","SingleValue","","Calculated","T_TimeVal") ;	
	addSignal("ICU_DISCHARGE_ALIVE",$config,$dataFile,$newDict->{def}->{ICU_DISCHARGE_ALIVE},2,$signalInfoFile,$infoLine) ;			
	
	# Write
	addReadmissionSignal($readmission,$dataFile,$data) ;
}

sub readConfigFile {
	my ($fileName) = @_ ;
	
	open (IN,$fileName) or die "Cannot open $fileName for reading" ;
	my %config ;
	my $iLine = 0 ;
	while (<IN>) {
		chomp ;
		my ($fieldName,$value) = split ;
		$config{$fieldName}->{$value} = $iLine ++ ;
	}
	close IN ;
	
	return \%config ;
}

sub writeConfigFile {
	my ($fileName,$config,$extraDict) = @_ ;
	
	open (OUT,">$fileName") or die "Cannot open $fileName for writing" ;
	my %config ;
	
	foreach my $field (keys %$config) {
		my $rec = $config->{$field} ;
		map {print OUT "$field $_\n"} (sort {$rec->{$a} <=> $rec->{$b}} grep {$rec->{$_} != -1} keys %$rec) ;
	}
	
	foreach my $field (keys %$config) {
		my $rec = $config->{$field} ;
		map {print OUT "$field $_\n"} (grep {$rec->{$_} == -1} keys %$rec) ;
	}	
	
	print OUT "DICTIONARY $extraDict\n" if ($extraDict) ;
	
	close OUT ;
	
	return ;
}

sub readLines {
	my ($fileName) = @_ ;
	
	open (IN,$fileName) or die "Cannot open $fileName for reading" ;
	my @lines ;
	while (<IN>) {
		next if (/id/i) ;
		chomp; 
		my @line = split;
		push @lines,\@line ;
	}
	close IN ;
	
	return \@lines ;
}

sub readNotesFile {
	my ($fileName) = @_ ;
	
	open (IN,$fileName) or die "Cannot open $fileName for reading" ;
	my @notes ;
	while (<IN>) {
		next if (/^#patientID/) ;
		chomp ;
		my ($patId,$stayId,$note,$date) = split /\t/,$_ ;
		push @notes,[$stayId,$note,$date] ;
	}
	close IN ;
	
	return \@notes ;
}

sub readDictionary {
	my ($dir,$dictFiles) = @_ ;
	
	my %dict ;
	$dict{max} = -1 ;
	
	foreach my $fileName (keys %$dictFiles) {
		open (IN,"$dir/$fileName") or die "Cannot open $dir/$fileName for reading" ;
		while (<IN>) {
			chomp ;
			my @line = split /\t/,$_ ;
			if ($line[0] eq "DEF") {
				$dict{def}->{$line[2]} = $line[1] ;
				$dict{max} = $line[1] if ($line[1] > $dict{max}) ;
			} elsif ($line[0] eq "SET") {
				push @{$dict{set}->{$line[1]}},$line[2] ;
			}
		}
		close IN ;
	}
	
	return \%dict ;
}

sub tokenedDiagnosisUpdateDictionary {
	
	my ($tokens,$dict,$newDict) = @_ ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{CHART_Tokened_Diagnosis_OP} = $dict->{max} ;
	
	foreach my $entry (keys %$tokens) {

		foreach my $token (keys %{$tokens->{$entry}}) {
			if (! exists $dict->{def}->{$token}) {
				$dict->{max} ++ ;
				$dict->{def}->{$token} = $dict->{max} ;
				$newDict->{def}->{$token} = $dict->{max} ;
			}
		
			$newDict->{sets}->{CHART_Tokened_Diagnosis_OP_Values}->{$token} = 1 ;
		}
	}
	
	$dict->{max} ++ ;
	$newDict->{def}->{CHART_Tokened_Diagnosis_OP_Values} = $dict->{max} ;
}

sub notesUpdateDictionary {
	my ($notes,$dict,$newDict) = @_ ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{Sepsis_Notes} = $dict->{max} ;
	
	foreach my $note (@$notes) {
		my ($id,$note,$date) = @$note ;
		
		if (! exists $dict->{def}->{$note}) {
			$dict->{max} ++ ;
			$dict->{def}->{$note} = $dict->{max} ;
			$newDict->{def}->{$note} = $dict->{max} ;
		}
		
		$newDict->{sets}->{Sepsis_Notes_Values}->{$note} = 1 ;
	}
	
	$dict->{max} ++ ;
	$newDict->{def}->{Sepsis_Notes_Values} = $dict->{max} ;
}

sub mbUpdateDictionary {
	my ($dict,$newDict) = @_ ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{MicroBiology_Found} = $dict->{max} ;	
}

sub sepsisUpdateDictionary {
	my ($dict,$newDict) = @_ ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{Sepsis_Indication} = $dict->{max} ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{Infection_Indication} = $dict->{max} ;

	$dict->{max} ++ ;
	$newDict->{def}->{SOFA_Increase} = $dict->{max} ;

	$dict->{max} ++ ;
	$newDict->{def}->{Sepsis} = $dict->{max} ;

	$dict->{max} ++ ;
	$newDict->{def}->{Sepsis_Strict} = $dict->{max} ;

	$dict->{max} ++ ;
	$newDict->{def}->{Sepsis_Stricter} = $dict->{max} ;	
}

sub antibioticsUpdateDictionary {
	my ($dict,$newDict) = @_ ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{Min_Antibiotics_Prescription_Time} = $dict->{max} ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{Min_Antibiotics_Input_Time} = $dict->{max} ;	
}

sub readmissionUpdateDictionary {
	my ($dict,$newDict) = @_ ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{readmitInterval} = $dict->{max} ;
	
	$dict->{max} ++ ;
	$newDict->{def}->{stayIndex} = $dict->{max} ;	
	
	$dict->{max} ++ ;
	$newDict->{def}->{stayCount} = $dict->{max} ;

	$dict->{max} ++ ;
	$newDict->{def}->{ICU_DISCHARGE_ALIVE} = $dict->{max} ;	
}

sub addNotesSignal {
	my ($notes,$dataFileName,$data) = @_ ;
	
	foreach my $note (@$notes) {
		my ($id,$note,$date) = @$note ;
		my $time = getMinutes($date) ;
		push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Notes\t$time\t$note\n" ;
	}
}

sub addAntibioticsSignal {
	my ($antibiotics,$dataFileName,$data) = @_ ;
	
	foreach my $entry (@$antibiotics) {
		my $id = $entry->[0] ;
		push @{$data->{$dataFileName}->{$id}},(join "\t",@$entry)."\n"  ;
	}
}

sub addReadmissionSignal {
	my ($readmission,$dataFileName,$data) = @_ ;
	
	foreach my $entry (@$readmission) {
		my $id = $entry->[0] ;
		push @{$data->{$dataFileName}->{$id}},(join "\t",@$entry)."\n"  ;
	}
}

sub addSepsisSignals {
	my ($sepsis,$dataFileName,$data) = @_ ;
	
	foreach my $entry (@$sepsis) {
		my ($id,$sepsisInd,$sepsisTime,$infectionInd,$infectionTime,$sofaStartTime,$sofaEndTime) = @$entry ;
		push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Indication\t$sepsisTime\t$sepsisInd\n" ;
		push @{$data->{$dataFileName}->{$id}},"$id\tInfection_Indication\t$infectionTime\t$infectionInd\n" ;
		push @{$data->{$dataFileName}->{$id}},"$id\tSOFA_Increase\t$sofaStartTime\t$sofaEndTime\t2.0\n" if ($sofaEndTime>=0) ;
		
		# Sepsis (Currently SepsisInd 4 (NotSepsis) or 1 (Sepsis)
		if ($sepsisInd == 1 and $infectionInd > 0 and $sofaEndTime >= 0) { # Sepsis, for sure
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Strict\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;
			
			# Is the first infection and sepsis indication within 24 hours of the dSOFA ?
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Stricter\t$sofaStartTime\t$sofaEndTime\t1.0\n" 
				if (($infectionTime >= $sofaStartTime - 24*60 and $infectionTime <= $sofaEndTime + 24*60) and ($sepsisTime >= $sofaStartTime - 24*60 and $sepsisTime <= $sofaEndTime + 24*60)) ;
			
		} elsif ($sepsisInd == 1 and $infectionInd > 0 and $sofaEndTime < 0) { # Sepsis in Test set
			my ($minTime,$maxTime) = ($sepsisTime > $infectionTime) ? ($infectionTime,$sepsisTime) : ($sepsisTime,$infectionTime) ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis\t$minTime\t$maxTime\t1.0\n" ;		
		} elsif ($sepsisInd == 1 and $infectionInd <= 0 and $sofaEndTime >= 0) { # Sepsis in Test set
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;				
		} elsif ($sepsisInd == 1 and $infectionInd <= 0 and $sofaEndTime < 0) { # Ignore
		} elsif ($sepsisInd == 4 and $infectionInd > 0 and $sofaEndTime >= 0) { # Sepsis in Test set
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;	
		} elsif ($sepsisInd == 4 and $infectionInd > 0 and $sofaEndTime < 0) { # Not Sepsis
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Strict\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;	
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Stricter\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
		} elsif ($sepsisInd == 4 and $infectionInd <= 0 and $sofaEndTime >= 0) { # Not Sepsis in Test Set
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
		} elsif ($sepsisInd == 4 and $infectionInd <= 0 and $sofaEndTime < 0) { # Not Sepsis, for sure
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Strict\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Stricter\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;		
		}
	}
}
	
sub writeSignals {
	my ($dir,$data) = @_ ;
	
	foreach my $dataFileName (keys %$data) {
		open (OUT,">$dir/$dataFileName") or die "Cannot open $dataFileName for writing" ;
		foreach my $id (sort {$a<=>$b} keys %{$data->{$dataFileName}}) {
			map {print OUT $_} @{$data->{$dataFileName}->{$id}} ;
		}
		close OUT ;
	}
}

sub writeDictionary {
	my ($dict,$dictFile) = @_ ;
	
	if ($dictFile) {
		open (OUT,">>$dictFile") or die "Cannot open $dictFile for appending" ;
		
		map {print OUT "DEF\t".($dict->{def}->{$_})."\t$_\n"} (keys %{$dict->{def}}) ;
		foreach my $set (keys %{$dict->{sets}}) {
			map {print OUT "SET\t$set\t$_\n"} keys %{$dict->{sets}->{$set}} ;
		}
		
		close OUT ;
	}
}

sub readMBFile {
	my ($mbFile) = @_ ;
	
	open (IN,$mbFile) or die "Cannot open $mbFile for reading " ;
	
	my @mb ;
	while (<IN>) {
		chomp ;
		my @line = split /\t/,$_ ;
		push @mb,\@line ;
	}
	close IN ;
	
	return \@mb ;
}

sub addMBSignals {
	my ($mb,$dataFile,$dict,$data) = @_ ;
	
	my %mbInfo ;
	foreach my $rec (@$mb) {
		my ($id,$name,$time,$value) = @$rec ;
		$mbInfo{$id}->{$time} += (((($value & 0x000FF80) >> 7) == $dict->{def}->{NoOrganism}) ? 0:1);
	}
	
	foreach my $id (keys %mbInfo) {
		foreach my $time (keys %{$mbInfo{$id}}) {
			my $line =  "$id\tMicroBiology_Found\t$time\t1\n" ;
			push @{$data->{$dataFile}->{$id}},$line ;
		}
	}
}

sub addSignal {
	my ($signalName,$config,$dataFile,$signalId,$signalType,$signalInfoFile,$signalInfoLine) = @_ ;
	
	my ($dir) = keys %{$config->{DIR}} ;
	# CODES
	my ($fileName) = keys %{$config->{CODES}} ;
	open (OUT,">>$dir/$fileName") or die "Cannot open $fileName for appending" ;
	print OUT "$signalName\t$signalName\n" ;
	close OUT ;
	
	# SIGNAL
	($fileName) = keys %{$config->{SIGNAL}} ;
	open (OUT,">>$dir/$fileName") or die "Cannot open $fileName for appending" ;
	print OUT "SIGNAL\t$signalName\t$signalId\t$signalType\n" ;
	close OUT ;	

	# SignalInfo
	open (OUT,">>$signalInfoFile") or die "Cannot open $signalInfoFile for appending" ;
	print OUT "$signalInfoLine\n" ;
	close OUT ;	
	
	if ($useOldInframed) {
		# FNAMES
		($fileName) = keys %{$config->{FNAMES}} ;
		open (IN,"$dir/$fileName") or die "Cannot open $fileName for reading" ;
		my $max = -1 ;
		my %files ;
		while (<IN>) {
			chomp ;
			my ($id,$file) = split /\t/,$_ ;
			$max = $id if ($id > $max) ;
			$files{$file} = $id ;
		}
		$max ++ ;
		close IN ;
		
		if (! exists $files{$dataFile}) {
			$files{$dataFile} = $max ;
			open (OUT,">>$dir/$fileName") or die "Cannot open $fileName for appending" ;
			print OUT "$max\t$dataFile\n" ;
			close OUT ;
		}

		# SFILES
		($fileName) = keys %{$config->{SFILES}} ;
		open (OUT,">>$dir/$fileName") or die "Cannot open $fileName for appending" ;
		print OUT "$files{$dataFile}\t$signalName\n" ;
		close OUT ;
	}

}

sub getMinutes {
	my ($date) = @_ ;
	
	$date =~ /(\d\d\d\d)(\d\d)(\d\d)/ or die "Cannot parse date $date" ;
	my ($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,23,59,0) ;
	
	my $days = 365 * ($year-1700) ;
	$days += int(($year-1697)/4) ;
	$days -= int(($year-1601)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	
	$minute ++ if ($second > 30) ;
	
	return ($days*24*60) + ($hour*60) + $minute ;
}	

		
			

