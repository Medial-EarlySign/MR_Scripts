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
		  "diagnosis_file=s",				# Diagnosis Signals File
		  ) ;
		  
die "text_signals_file required for notes" if (exists $p->{notes_file} and not exists $p->{text_signals_file}) ;
die "numeric_signals_file required for microbiologySignals and sepsisSignals" if ((exists $p->{microbiology_file} or exists $p->{sepsis_file}) and not exists $p->{numeric_signals_file}) ;

map {die "Cannot find $p->{$_}" if (exists $p->{$_} and not -e $p->{$_})} qw/notes_file microbiology_file sepsis_file/ ;

# Read
my $config = readConfigFile($p->{config_file}) ;
my $dict = readDictionary($config->{DICTIONARY}) ;
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

# Write
writeDictionary(\%newDict,$p->{extra_dict_file}) ;
writeConfigFile($p->{config_file},$config,$p->{extra_dict_file}) ;
writeSignals(\%data) ;

print STDERR "Done\n" ;

###########################
# Functions
###########################

## Add notes
sub addNotes {
	my ($config,$dict,$notesFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e "ICU.$dataFile") ;
	
	# Read
	my $notes = readNotesFile($notesFile) ;
	
	# Update
	notesUpdateDictionary($notes,$dict,$newDict) ;
	$config->{DATA_S}->{"ICU.$dataFile"} = -1 ;
	
	my $infoLine = join "\t",("Sepsis_Notes","T_TimeVal","Categorial","MultipleValue","","NOTESEVENTS","T_DateVal") ;
	addSignal("Sepsis_Notes",$config,$dataFile,$newDict->{def}->{Sepsis_Notes},2,$signalInfoFile,$infoLine) ;

	# Write
	addNotesSignal($notes,"ICU.$dataFile",$data) ;
}

# Tokenize diagnosis
sub addDiagnosis {
	my ($config,$dict,$diagnosisFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;
	
	die "Cannot use existing dataFile \'$dataFile\'" if (-e "ICU.$dataFile") ;
	
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
	$config->{DATA_S}->{"ICU.$dataFile"} = -1 ;	
	open (IN,$diagnosisFile) or die "Cannot open $diagnosisFile for reading " ;
	
	while (<IN>) {
		chomp ;
		my ($id,$signal,$time,$entry) = split /\t/,$_ ;
		if ($signal eq "CHART_Diagnosis_OP") {
			die "Cannot find tokens for \'$entry\'" if (! exists $tokens{$entry}) ;
			foreach my $token (keys %{$tokens{$entry}}) {
				my $line =  "$id\tCHART_Tokened_Diagnosis_OP\t$time\t$token\n" ;
				push @{$data->{"ICU.$dataFile"}->{$id}},$line ;
			}
		}
	}
	close IN ;	
}

# Add Microbiology 
sub addMB {
	my ($config,$dict,$microbiologyFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e "ICU.$dataFile") ;
	
	# Read
	my $mb = readMBFile($microbiologyFile) ;

	# Update
	mbUpdateDictionary($dict,$newDict) ;
	$config->{DATA}->{"ICU.$dataFile"} = -1 ;
	
	my $infoLine = join "\t",("MicroBiology_Taken","T_TimeVal","Numeric","MultipleValue","","MICROBIOLOGYEVENTS","T_TimeVal") ;
	addSignal("MicroBiology_Taken",$config,$dataFile,$newDict->{def}->{MicroBiology_Taken},2,$signalInfoFile,$infoLine) ;
	
	$infoLine = join "\t",("MicroBiology_Found","T_TimeVal","Numeric","MultipleValue","","MICROBIOLOGYEVENTS","T_TimeVal") ;	
	addSignal("MicroBiology_Found",$config,$dataFile,$newDict->{def}->{MicroBiology_Found},2,$signalInfoFile,$infoLine) ;

	# Write
	addMBSignals($mb,"ICU.$dataFile",$dict,$data) ;
}

# Add Sepsis
sub addSepsis {
	my ($config,$dict,$sepsisFile,$dataFile,$signalInfoFile,$newDict,$data) = @_ ;

	die "Cannot use existing dataFile \'$dataFile\'" if (-e "ICU.$dataFile") ;
	
	# Read
	my $sepsis = readSepsisFile($sepsisFile) ;

	# Update
	sepsisUpdateDictionary($dict,$newDict) ;
	$config->{DATA}->{"ICU.$dataFile"} = -1 ;
	
	my $infoLine = join "\t",("Sepsis_Indication","T_TimeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Sepsis_Indication",$config,$dataFile,$newDict->{def}->{Sepsis_Indication},2,$signalInfoFile,$infoLine) ;
	
	$infoLine = join "\t",("Infection_Indication","T_TimeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Infection_Indication",$config,$dataFile,$newDict->{def}->{Infection_Indication},2,$signalInfoFile,$infoLine) ;
	
	$infoLine = join "\t",("SOFA_Increase","T_TimeRangeVal","Numeric","MultipleValue","","Calculated","T_TimeRangeVal") ;	
	addSignal("SOFA_Increase",$config,$dataFile,$newDict->{def}->{SOFA_Increase},5,$signalInfoFile,$infoLine) ;
	
	$infoLine = join "\t",("Sepsis_for_Learn","T_TimeRangeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Sepsis_for_Learn",$config,$dataFile,$newDict->{def}->{Sepsis_for_Learn},5,$signalInfoFile,$infoLine) ;

	$infoLine = join "\t",("Sepsis_for_Test","T_TimeRangeVal","Numeric","MultipleValue","","Calculated","T_TimeVal") ;	
	addSignal("Sepsis_for_Test",$config,$dataFile,$newDict->{def}->{Sepsis_for_Test},5,$signalInfoFile,$infoLine) ;	
	
	# Write
	addSepsisSignals($sepsis,"ICU.$dataFile",$data) ;
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

sub readSepsisFile {
	my ($fileName) = @_ ;
	
	open (IN,$fileName) or die "Cannot open $fileName for reading" ;
	my @sepsis ;
	while (<IN>) {
		next if (/id/i) ;
		chomp; 
		my @line = split;
		push @sepsis,\@line ;
	}
	close IN ;
	
	return \@sepsis ;
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
	my ($dictFiles) = @_ ;
	
	my %dict ;
	$dict{max} = -1 ;
	
	foreach my $fileName (keys %$dictFiles) {
		open (IN,$fileName) or die "Cannot open $fileName for reading" ;
			
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
	$newDict->{def}->{MicroBiology_Taken} = $dict->{max} ;
	
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
	$newDict->{def}->{Sepsis_for_Learn} = $dict->{max} ;	

	$dict->{max} ++ ;
	$newDict->{def}->{Sepsis_for_Test} = $dict->{max} ;	
}

sub addNotesSignal {
	my ($notes,$dataFileName,$data) = @_ ;
	
	foreach my $note (@$notes) {
		my ($id,$note,$date) = @$note ;
		my $time = getMinutes($date) ;
		push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Notes\t$time\t$note\n" ;
	}
}

sub addSepsisSignals {
	my ($sepsis,$dataFileName,$data) = @_ ;
	
	foreach my $entry (@$sepsis) {
		my ($id,$sepsisInd,$sepsisTime,$infectionInd,$infectionTime,$sofaStartTime,$sofaEndTime) = @$entry ;
		push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_Indication\t$sepsisTime\t$sepsisInd\n" ;
		push @{$data->{$dataFileName}->{$id}},"$id\tInfection_Indication\t$infectionTime\t$infectionInd\n" ;
		push @{$data->{$dataFileName}->{$id}},"$id\tSOFA_Increase\t$sofaStartTime\t$sofaEndTime\t2.0\n" if ($sofaEndTime>=0) ;
		
		# SOFA (Currently SepsisInd 4 (NotSepsis) or 1 (Sepsis)
		if ($sepsisInd == 1 and $infectionInd > 0 and $sofaEndTime >= 0) { # Sepsis, for sure
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Learn\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Test\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;
		} elsif ($sepsisInd == 1 and $infectionInd > 0 and $sofaEndTime < 0) { # Sepsis in Test set
			my ($minTime,$maxTime) = ($sepsisTime > $infectionTime) ? ($infectionTime,$sepsisTime) : ($sepsisTime,$infectionTime) ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Test\t$minTime\t$maxTime\t1.0\n" ;		
		} elsif ($sepsisInd == 1 and $infectionInd <= 0 and $sofaEndTime >= 0) { # Sepsis in Test set
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Test\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;				
		} elsif ($sepsisInd == 1 and $infectionInd <= 0 and $sofaEndTime < 0) { # Ignore
		} elsif ($sepsisInd == 4 and $infectionInd > 0 and $sofaEndTime >= 0) { # Sepsis in Test set
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Test\t$sofaStartTime\t$sofaEndTime\t1.0\n" ;	
		} elsif ($sepsisInd == 4 and $infectionInd > 0 and $sofaEndTime < 0) { # Not Sepsis
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Learn\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Test\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;			
		} elsif ($sepsisInd == 4 and $infectionInd <= 0 and $sofaEndTime >= 0) { # Not Sepsis in Test Set
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Test\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
		} elsif ($sepsisInd == 4 and $infectionInd <= 0 and $sofaEndTime < 0) { # Not Sepsis, for sure
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Learn\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;
			push @{$data->{$dataFileName}->{$id}},"$id\tSepsis_for_Test\t$sofaStartTime\t$sofaEndTime\t0.0\n" ;		
		}
	}
}
	
sub writeSignals {
	my ($data) = @_ ;
	
	foreach my $dataFileName (keys %$data) {
		open (OUT,">$dataFileName") or die "Cannot open $dataFileName for writing" ;
		foreach my $id (sort {$a<=>$b} keys %{$data->{$dataFileName}}) {
			map {print OUT $_} @{$data->{$dataFileName}->{$id}} ;
		}
		close OUT ;
	}
}

sub writeDictionary {
	my ($dict,$dictFile) = @_ ;
	
	open (OUT,">>$dictFile") or die "Cannot open $dictFile for appending" ;
	
	map {print OUT "DEF\t".($dict->{def}->{$_})."\t$_\n"} (keys %{$dict->{def}}) ;
	foreach my $set (keys %{$dict->{sets}}) {
		map {print OUT "SET\t$set\t$_\n"} keys %{$dict->{sets}->{$set}} ;
	}
	
	close OUT ;
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
#		print STDERR "$id $name -- $value -- ".(($value & 0x000FF80) >> 7)."\n" ;
		$mbInfo{$id}->{$time} += (((($value & 0x000FF80) >> 7) == $dict->{def}->{NoOrganism}) ? 0:1);
	}
	
	foreach my $id (keys %mbInfo) {
		foreach my $time (keys %{$mbInfo{$id}}) {
			my $line1 =  "$id\tMicroBiology_Taken\t$time\t1.0\n" ;
			my $orgFlag = ($mbInfo{$id}->{$time} > 0) ? 1 : 0 ;
			my $line2 =  "$id\tMicroBiology_Found\t$time\t$orgFlag\n" ;
			push @{$data->{$dataFile}->{$id}},($line1,$line2) ;
		}
	}
}

sub addSignal {
	my ($signalName,$config,$dataFile,$signalId,$signalType,$signalInfoFile,$signalInfoLine) = @_ ;
	
	# CODES
	my ($fileName) = keys %{$config->{CODES}} ;
	open (OUT,">>$fileName") or die "Cannot open $fileName for appending" ;
	print OUT "$signalName\t$signalName\n" ;
	close OUT ;
	
	# SIGNAL
	($fileName) = keys %{$config->{SIGNAL}} ;
	open (OUT,">>$fileName") or die "Cannot open $fileName for appending" ;
	print OUT "SIGNAL\t$signalName\t$signalId\t$signalType\n" ;
	close OUT ;	

	# SignalInfo
	open (OUT,">>$signalInfoFile") or die "Cannot open $signalInfoFile for appending" ;
	print OUT "$signalInfoLine\n" ;
	close OUT ;	
	
	# FNAMES
	($fileName) = keys %{$config->{FNAMES}} ;
	open (IN,$fileName) or die "Cannot open $fileName for reading" ;
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
		open (OUT,">>$fileName") or die "Cannot open $fileName for appending" ;
		print OUT "$max\t$dataFile\n" ;
		close OUT ;
	}

	# SFILES
	($fileName) = keys %{$config->{SFILES}} ;
	open (OUT,">>$fileName") or die "Cannot open $fileName for appending" ;
	print OUT "$files{$dataFile}\t$signalName\n" ;
	close OUT ;

}

sub getMinutes {
	my ($date) = @_ ;
	
	$date =~ /(\d\d\d\d)(\d\d)(\d\d)/ or die "Cannot parse date $date" ;
	my ($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,23,59,0) ;
	
	my $days = 365 * ($year-2500) ;
	$days += int(($year-2497)/4) ;
	$days -= int(($year-2401)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	
	$minute ++ if ($second > 30) ;
	
	return ($days*24*60) + ($hour*60) + $minute ;
}	

		
			

