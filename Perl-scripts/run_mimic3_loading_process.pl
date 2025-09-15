#!/usr/bin/env perl 

use strict ;
use FileHandle ;
use Getopt::Long;

# Read Parameters
my $p  = {#splitDataDir => "/nas1/Work/Users/yaron/ICU/Mimic/Mimic3/Repository.Parallel",
		  #unitedDataDir => "/nas1/Work/Users/yaron/ICU/Mimic/Mimic3/Repository.Parallel/United",
		  #sepsisDir => "/nas1/Work/Users/yaron/ICU/Mimic/Sepsis/Mimic3/GetSepsisInfo/",
		  #repDir => "/home/Repositories/Mimic3/build_Aug16/",
		  #workRepDir => "/nas1/Work/ICU/Repositories/Mimic3/build_Aug16/",
		  #startStage => "mimic2inframed",
		  #endStage => "load3",
		  nSepsisSplits => 20,
		  copyTo => "condor2,node-01,node-02",
		 } ;
		  
my ($help) = (0) ;
GetOptions($p,
		  "splitDataDir=s",				# Directory for mimic3_to_inframed input/output [should have runner.mimic3inframed file]
		  "unitedDataDir=s",			# Directory for united mimic3_to_inframed outputs
		  "sepsisDir=s",				# Directory for getSepsis runs [should have runner.getSepsis]
		  "repDir=s",					# Directory for local output repositories
		  "workRepDir=s",				# Directory for server output repository
		  "startStage=s",				# Start stage
		  "endStage=s",					# End Stage
		  "nSepsisSplits",				# Number of splits in sepsis calculation
		  "copyTo=s",					# Computers for local repositories
		  "useOldInfraMed",				# Use old version of inframed
		  "noRun",						# Only print commands without running.
		  "noCondor",					# do not use condor for parallelizing
		  ) ;
	
my $noRun = $p->{noRun} ;
my $noCondor = $p->{noCondor} ;
my $careUnitsSplit = $p->{doCareUnitsSplit} ; 
my $oldVersion = $p->{useOldInfraMed} ;
my $enrichFlag = ($oldVersion) ? " --useOldInfraMed" : "" ;
map {print STDERR "$_ : $p->{$_}\n"} keys %$p ;
	
# Stages
my @stages = qw/mimic2inframed unite enrich load enrich2 load2 getSepsis enrich3 load3/ ;
my %stages = map {($stages[$_] => $_)} (0..$#stages) ;
map {die "Unknown stages $p->{$_}" if (! exists $stages{$p->{$_}})} qw/startStage endStage/ ;
my ($startStage,$endStage) = map {$stages{$p->{$_}}} qw/startStage endStage/ ;
print STDERR "Running stages $p->{startStage} [$startStage] - $p->{endStage} [$endStage]\n" ;

# Export to ...
my $currentHost  = $ENV{HOSTNAME} ;
my @targetHosts = grep {$_ ne $currentHost} split ",",$p->{copyTo} ;

# Directories 
my @dirs = qw/splitDataDir unitedDataDir sepsisDir repDir workRepDir/ ;
my ($splitDataDir,$unitedDir,$sepsisDir,$repDir,$workRepDir) = map {$p->{$_}} @dirs ;

# Mimic2Inframed : Create files for loading in a parallel way and unite
if ($stages{mimic2inframed} >= $startStage and $stages{mimic2inframed} <= $endStage) {
	if (not $noCondor) {
		run_cmd("condor_submit $splitDataDir/runner.mimic2inframed") ;
		run_cmd("condor_wait $splitDataDir/runner.log") ;
	} else {
		run_cmd("$splitDataDir/commands.mimic2inframed") ;
	}
}

## Unite mimic2inframed output files
if ($stages{unite} >= $startStage and $stages{unite} <= $endStage) {
	
	if (-e $unitedDir) {
		run_cmd("\\rm -f $unitedDir/*") ;
	} else {
		run_cmd("mkdir $unitedDir") ;
	}
	
	run_cmd("mimic3_to_inframed_unite.pl $splitDataDir/SubsetDirsList $unitedDir $splitDataDir/FilesToUnite") ;
	changeConfigFile("$unitedDir/ICU.convert_config","OUTDIR","$repDir") ;
}

# Enrich Data
if ($stages{enrich} >= $startStage and $stages{enrich} <= $endStage) {
	system("ls -l $unitedDir/ICU.ChartEvents_N") ;
	run_cmd("mimic3_to_inframed_enrich.pl -config_file $unitedDir/ICU.convert_config --signal_info_file $unitedDir/SignalInfoFile -numeric_signals_file ICU.MicroBiologyFlags --microbiology_file ".	
			"$unitedDir/ICU.MicroBiologyEvents_N --extra_dict_file ICU.mb_flags_dictionary $enrichFlag") ;
	system("ls -l $unitedDir/ICU.ChartEvents_N") ;
	run_cmd("extend_mimic_notes.pl /nas1/Work/ICU/AncillaryFiles/Sepsis.Notes.Mimic3 $unitedDir/ICU.ICU_Stays_N $unitedDir/newNotesFile") ;
	run_cmd("mimic3_to_inframed_enrich.pl -config_file $unitedDir/ICU.convert_config --signal_info_file $unitedDir/SignalInfoFile -text_signals_file ICU.Notes -notes_file ".
			"$unitedDir/newNotesFile --extra_dict_file ICU.notes_dictionary $enrichFlag") ;
	system("ls -l $unitedDir/ICU.ChartEvents_N") ;	
	run_cmd("mimic3_to_inframed_enrich.pl -config_file $unitedDir/ICU.convert_config --signal_info_file $unitedDir/SignalInfoFile -text_signals_file ICU.TokenedDiagnosis -diagnosis_file ".
			"$unitedDir/ICU.ChartEvents_S -extra_dict_file ICU.tokened_diagnosis_dictionary $enrichFlag") ;
	system("ls -l $unitedDir/ICU.ChartEvents_N") ;
	run_cmd("mimic3_to_inframed_enrich.pl -config_file $unitedDir/ICU.convert_config -numeric_signals_file ICU.ieRatioSignal -ie_file $unitedDir/ICU.ChartEvents_N $enrichFlag 2> $unitedDir/IE_Ratio_Warnings") ;
}

# Create Repository
if ($stages{load} >= $startStage and $stages{load} <= $endStage) {
	run_cmd("sudo mkdir $repDir") if (! -e $repDir) ;
	run_cmd("sudo time /nas1/UsersData/yaron/MR/Projects/Shared/ICU/repository_loader/Linux/Release/repository_loader --config $unitedDir/ICU.convert_config") ;
}

# Further enrich - GCS
if ($stages{enrich2} >= $startStage and $stages{enrich2} <= $endStage) {
	run_cmd("/nas1/UsersData/yaron//MR/Projects/Shared/ICU/repository_loader/Linux/Release/utils --config $repDir/ICU.repository --task complete_GCS --outFile  $unitedDir/calculatedGCS 2> $unitedDir/missingGCS") ;
	run_cmd("mimic_add_data_to_signal.pl $unitedDir/ICU.ChartEvents_N $unitedDir/calculatedGCS $unitedDir/tempFile") ;
}

# Create Repository
if ($stages{load2} >= $startStage and $stages{load2} <= $endStage) {

	my $convertFile = "ICU.convert_config" ;
	if (! $oldVersion){
		$convertFile = "ICU.convert_config2" ;
		my @signals = qw/CHART_GCS/ ;
		my @dataLines = ("DATA\tICU.ChartEvents_N") ;
		updateSignalsInConfigFile("$unitedDir/ICU.convert_config","$unitedDir/$convertFile",\@signals,\@dataLines) ;
	}
	
	run_cmd("sudo mkdir $repDir") if (! -e $repDir) ;
	run_cmd("sudo time /nas1/UsersData/yaron//MR/Projects/Shared/ICU/repository_loader/Linux/Release/repository_loader --config $unitedDir/$convertFile") ;
	run_cmd("sudo cp $unitedDir/SignalInfoFile $repDir/") ;

	# Copy to other computers
	map {run_cmd("sudo rsync -r $repDir/* $_:$repDir")} @targetHosts ;
}

# Create SepsisData
if ($stages{getSepsis} >= $startStage and $stages{getSepsis} <= $endStage) {

	createSepsisFiles("$unitedDir/ICU.ICU_Stays_N","$unitedDir/SignalInfoFile",$sepsisDir,$p->{nSepsisSplits},$repDir) ;
	run_cmd("awk \'{print \$1}\' $unitedDir/SignalInfoFile >$sepsisDir/allSignals") ;
	if (not $noCondor) {
		run_cmd("condor_submit $sepsisDir/runner.getSepsisInfo") ;
		run_cmd("condor_wait $sepsisDir/runner.log") ;
	} else {
		run_cmd("$sepsisDir/commands.getSepsisInfo") ;
	}
	run_cmd("cat $sepsisDir/GenerationOutput? $sepsisDir/GenerationOutput?? > $sepsisDir/GenerationOutput") ;
}

# Further enrichment
if ($stages{enrich3} >= $startStage and $stages{enrich3} <= $endStage) {
	run_cmd("/nas1/UsersData/yaron//MR/Projects/Shared/ICU/repository_loader/Linux/Release/utils --config $repDir/ICU.repository --task get_Antibiotics --outFile $unitedDir/ExtraAntibioticsInfo 2> $unitedDir/allAntiBiotics") ;
	run_cmd("mimic3_to_inframed_enrich.pl -config_file $unitedDir/ICU.convert_config --signal_info_file $unitedDir/SignalInfoFile -numeric_signals_file ICU.SepsisSignals --sepsis_file $sepsisDir/GenerationOutput ".
			"-extra_dict_file ICU.sepsis_signals_dictionary $enrichFlag") ;
	run_cmd("mimic3_to_inframed_enrich.pl -config_file $unitedDir/ICU.convert_config --signal_info_file $unitedDir/SignalInfoFile -numeric_signals_file ICU.MinABSignal --antibiotics_file $unitedDir/ExtraAntibioticsInfo ".
			"-extra_dict_file ICU.AB_time_dictionary $enrichFlag") ;
	run_cmd("/nas1/UsersData/yaron//MR/Projects/Shared/ICU/repository_loader/Linux/Release/utils --config $repDir/ICU.repository --task readmission_info --outFile $unitedDir/ReadmissionInfo 2> $unitedDir/Readmission") ;
	run_cmd("mimic3_to_inframed_enrich.pl -config_file $unitedDir/ICU.convert_config --signal_info_file $unitedDir/SignalInfoFile -numeric_signals_file ICU.ReadmissionSiganls --readmission_file $unitedDir/ReadmissionInfo ".
			"-extra_dict_file ICU.readmission_dictionary $enrichFlag") ;			
}

# New Repository
if ($stages{load3} >= $startStage and $stages{load3} <= $endStage) {

	my $convertFile = "ICU.convert_config" ;
	if (! $oldVersion) {
		$convertFile = "ICU.convert_config3" ;
		my @signals = 
			qw/Infection_Indication Sepsis Sepsis_Indication Sepsis_Strict Sepsis_Stricter SOFA_Increase Min_Antibiotics_Input_Time Min_Antibiotics_Prescription_Time ICU_DISCHARGE_ALIVE readmitInterval stayCount stayIndex/ ;
		my @dataLines = ("DATA\tICU.SepsisSignals","DATA\tICU.MinABSignal","DATA\tICU.ReadmissionSiganls") ;
		updateSignalsInConfigFile("$unitedDir/ICU.convert_config","$unitedDir/$convertFile",\@signals,\@dataLines) ;
	}
	
	run_cmd("sudo mkdir $repDir") if (! -e $repDir) ;
	run_cmd("sudo time /nas1/UsersData/yaron//MR/Projects/Shared/ICU/repository_loader/Linux/Release/repository_loader --config $unitedDir/$convertFile") ;
	run_cmd("sudo cp $unitedDir/SignalInfoFile $repDir") ;

	map {run_cmd("sudo rsync -r $repDir/* $_:$repDir")} @targetHosts ;
	
	run_cmd("\\cp -f $repDir/* $workRepDir") ;
	changeConfigFile("$workRepDir/ICU.repository","DIR",$workRepDir) ;
}

#############################################################
sub run_cmd {
	my ($command) = @_ ;
	
	print STDERR "Running \'$command\'\n" ;
	(system($command) == 0 or die "\'$command\' Failed" ) unless ($noRun) ;
	
	return ;
}

sub updateSignalsInConfigFile {
	my ($origFile,$newFile,$signals,$dataLines) = @_ ;
	
	open (IN,$origFile) or die "Cannot open $origFile for reading" ;
	open (OUT,">$newFile") or die "Cannot open $newFile for reading" ;
	
	while (<IN>) {
		print OUT $_ unless (/^DATA/) ;
	}
	close IN ;
	
	map {print OUT "$_\n"} @$dataLines ;
	my $signals = join ",",@$signals ;
	print OUT "LOAD_ONLY\t$signals\n" ;
	close OUT ;
}
sub changeConfigFile {
	my ($file,$field,$value) = @_ ;

	if ($noRun) {
		print STDERR "Changing field \'$field\' to $value in $file\n" ;
		return ;
	}
	
	my @lines ;
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($iField) = split /\s+/,$_ ;
		if ($iField eq $field) {
			push @lines,"$iField\t$value" ;
		} else {
			push @lines,$_ ;
		}
	}
	close IN ;
	
	open (OUT,">$file") or die "Cannot open $file for writing" ;
	map {print OUT "$_\n"} @lines ;
	close OUT ;
}

sub createSepsisFiles {
	my ($inFile,$signalsFile,$outDir,$nsplits,$repDir) = @_ ;
	
	#IDS
	my @fileHandles = map {FileHandle->new("$outDir/allIds$_","w") or die "Cannot create $outDir/allIds$_ for writing"} (0..($nsplits-1)) ;
	open (IN,$inFile) or die "Cannot open $inFile for reading" ;
	
	my %ids ;
	while (<IN>) {
		chomp ;
		my ($id) = split ;
		$ids{$id} = 1 ;
	}
	close IN ;
	
	my @ids = keys %ids ;
	for my $idx (0..$#ids) {
		my $id = $ids[$idx] ;
		$fileHandles[$idx%$nsplits]->print("$id\n") ;
	}
	map {$_->close()} @fileHandles ;
	
	#SIGNALS
	open (IN,$signalsFile) or die "Cannot open $signalsFile for reading" ;
	open (OUT,">$outDir/allSignals") or die "Cannot open $outDir/allSignals for writing" ;
	while (<IN>) {
		my ($name) = split ;
		print OUT "$name\n" ;
	}
	close IN ;
	close OUT ;
	
	# CONFIG FILES
	for my $i (0..($nsplits)-1) {
		open (IN,"$outDir/config_file$i") or die "Cannot open config file $i" ;
		my @lines ;
		while (<IN>) {
			if (/configFile/) {
				push @lines,"configFile = $repDir/ICU.repository\n" ;
			} else {
				push @lines,$_ ;
			}
		}
		close IN ;
		
		open (OUT,">$outDir/config_file$i") or die "Cannot open config file $i for writing" ;
		map {print OUT $_} @lines ;
		close OUT ;
	}
}

