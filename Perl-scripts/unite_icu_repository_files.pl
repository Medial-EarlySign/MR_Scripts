#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

die "Usage : $0 InConfig1 InConfig2 OutDir repDir UniteLog" if (@ARGV!=5) ;
my ($inConfig1,$inConfig2,$outDir,$repDir,$uniteLog) = @ARGV ;

# LOG
open (LOG,">$outDir/$uniteLog") or die "Cannot open log file" ;

# Read Config files
my (%config1,%config2) ;
readConfigFile($inConfig1,\%config1) ;
readConfigFile($inConfig2,\%config2) ;

# Read Dictionaries
my (%dic1,%dic2) ;
readDictionaries(\%config1,\%dic1) ; 
readDictionaries(\%config2,\%dic2) ;

# Unite Dictionaries
my %dict ;
uniteDictionaries(\%dic1,\%dic2,\%dict) ;

# Write Dictionaries
my @outConfig ;
my $newSingalId = writeDictionaries(\%dict,$outDir,\@outConfig);

# Data Files
writeDataFiles(\%config1,\%config2,$outDir,\@outConfig) ;

# Signals File
writeSignalsFile(\%config1,\%config2,$outDir,\%dict,\@outConfig,$newSingalId) ;

# Config File
writeConfigFile($outDir,$repDir,\@outConfig) ;

### FUNCTIONS ####
sub readConfigFile {
	my ($fileName,$config) = @_ ;
	
	open (IN,$fileName) or die "Cannot open $fileName for reading";
	print STDERR "Reading Config file $fileName\n" ;

	while (<IN>) {
		chomp ;
		my ($key,$value) = split ;
		push @{$config->{$key}},$value ;
	}
	close IN ;
}

sub readDictionaries {
	my ($config,$dic) = @_ ;
	
	foreach my $dicName (@{$config->{DICTIONARY}}) {
		my $file = $config->{DIR}->[0] . "/".$dicName ;
		print STDERR "Reading Dictionary file $file\n" ;
		
		open (IN,$file) or die "Cannot open $file for reading" ;
		while (<IN>) {
			chomp ;
			my ($type,$key,$value) = split /\t/,$_ ;
			if ($type eq "SET") {
				$dic->{SET}->{$key}->{$value} = 1 ;
			} else {
				$dic->{DEF}->{$value} = 1 ;
			}
		}
		close IN ;
	}
}

sub uniteDictionaries {
	my ($dic1,$dic2,$dic) = @_ ;
	
	# DEFS
	foreach my $key (keys %{$dic1->{DEF}}) {
		
		push @{$dic->{DEF}},$key ;
		print LOG "DEF $key appears only in dic1\n" if (! exists $dic2->{DEF}->{$key}) ;
	}
	
	foreach my $key (keys %{$dic2->{DEF}}) {
		if (! exists $dic1->{DEF}->{$key}) {
			push @{$dic->{DEF}},$key ;
			print LOG "DEF $key appears only in dic2\n" 
		}
	}
	
	# SETS
	foreach my $set (keys %{$dic1->{SET}}) {
		if (! exists $dic2->{SET}->{$set}) {
			print LOG "SET $set appeas only in dic1\n" ;
		} else {
			foreach my $value (keys %{$dic1->{SET}->{$set}}) {
				print LOG "VALUE $value in set $set appears only in dic1\n" if (! exists $dic2->{SET}->{$set}->{$value}); 
				$dic->{SET}->{$set}->{$value} = 1 ;
			}
		}
	}
	
	foreach my $set (keys %{$dic2->{SET}}) {
		if (! exists $dic1->{SET}->{$set}) {
			print LOG "SET $set appeas only in dic2\n" ;
		} else {
			foreach my $value (keys %{$dic2->{SET}->{$set}}) {
				print LOG "VALUE $value in set $set appears only in dic2\n" if (! exists $dic1->{SET}->{$set}->{$value}); 
				$dic->{SET}->{$set}->{$value} = 1 ;
			}
		}
	}
}

sub writeDictionaries {
	my ($dict,$outDir,$config) = @_ ;
	
	# DEF
	my $file = "$outDir/ICU.dictionary" ;
	push @{$config},"DICTIONARY ICU.dictionary" ;
	
	open (OUT,">$file") or die "Cannot open $file for writing" ;
	
	my $nDef = scalar (@{$dict->{DEF}}) ;
	foreach my $index (0..$nDef-1) {
		my $value = $dict->{DEF}->[$index] ;
		print OUT "DEF\t$index\t$value\n" ;
		$dict->{codes}->{$value} = $index ;
	}
	
	my $signalId = $nDef ;
	print OUT "DEF\t$nDef\tDataBase\n" ; $nDef++ ;
	print OUT "DEF\t$nDef\tDataBase_Values\n" ; $nDef++ ;
	print OUT "DEF\t$nDef\tMimic3\n" ; $nDef++ ;
	print OUT "DEF\t$nDef\tMayo\n" ;
	close OUT ;
	
	# SET
	my $file = "$outDir/ICU.sets_dictionary" ;
	push @{$config},"DICTIONARY ICU.sets_dictionary" ;
	
	open (OUT,">$file") or die "Cannot open $file for writing" ;
	foreach my $set (keys %{$dict->{SET}}) {
		map {print OUT "SET\t$set\t$_\n"} keys %{$dict->{SET}->{$set}} ;
	}
	print OUT "SET\tDataBase_Values\tMimic3\n" ;
	print OUT "SET\tDataBase_Values\tMayo\n" ;
	close OUT ;
	
	return $signalId ;
}

sub writeDataFiles {
	my ($config1,$config2,$outDir,$outConfig) = @_ ;
	
	my %ids1 ;
	foreach my $type (qw/DATA DATA_S/) {
		foreach my $dataName (@{$config1->{$type}}) {
			my $inFile = $config1->{DIR}->[0] . "/".$dataName ;
			my $outFile = "$outDir/$dataName.1" ;
			push @{$outConfig},"$type $dataName.1" ;
			print STDERR "Copying Data file $inFile\n" ;

			open (IN,$inFile) or die "Cannot open $inFile for reading" ;
			open (OUT,">$outFile") or die "Cannot open $outFile for writing" ;
		
			while (<IN>) {
				my ($id) = split ;
				$ids1{$id} = 1 ;
				print OUT $_ ;
			}
			close IN ;
			close OUT ;
		}
	}
	
	my $maxId = -1 ;
	map {$maxId = $_ if ($_ > $maxId)} keys %ids1 ;
	print STDERR "MaxId = $maxId\n" ;
	
	my %ids2 ;
	foreach my $type (qw/DATA DATA_S/) {
		foreach my $dataName (@{$config2->{$type}}) {
			my $inFile = $config2->{DIR}->[0] . "/".$dataName ;
			my $outFile = "$outDir/$dataName.2" ;
			push @{$outConfig},"$type $dataName.2" ;
			print STDERR "Copying Data file $inFile\n" ;

			open (IN,$inFile) or die "Cannot open $inFile for reading" ;
			open (OUT,">$outFile") or die "Cannot open $outFile for writing" ;
		
			while (<IN>) {
				chomp; 
				my ($id,@data) = split /\t/,$_ ;;
				$id += $maxId ;
				$ids2{$id} = 1 ;
				my $out = join "\t", ($id,@data) ;
				print OUT "$out\n" ;
			}
			close IN ;
			close OUT ;
		}
	}
	
	push @{$outConfig},"DATA_S\tICU.DataBase" ;
	open (OUT,">$outDir/ICU.DataBase") or die "Cannot open dataBase file" ;
	map {print OUT "$_\tDataBase\tMimic3\n"} sort {$a<=>$b} keys %ids1 ;
	map {print OUT "$_\tDataBase\tMayo\n"} sort {$a<=>$b} keys %ids2 ;
	close OUT
	
}

sub writeSignalsFile {
	my ($config1,$config2,$outDir,$dict,$outConfig,$newSignalId) = @_ ;
	
	my (%signals1,%signals2) ;
	my $file = $config1->{DIR}->[0] . "/" . $config1->{SIGNAL}->[0] ;
	open (IN,$file) or die "Cannot read signal file $file" ;
	while (<IN>) {
		chomp ;
		my ($dummy,$signal,$code,$type) = split ;
		$signals1{$signal} = $type ;
	}
	close IN ;
	
	my %signals ;
	$file = $config2->{DIR}->[0] . "/" . $config2->{SIGNAL}->[0] ;
	open (IN,$file) or die "Cannot read signal file $file" ;
	while (<IN>) {
		chomp ;
		my ($dummy,$signal,$code,$type) = split ;
		$signals2{$signal} = $type ;
	}
	
	open (OUT,">$outDir/ICU.signals") or die "Cannot open ICU.signals for writing" ;
	push @{$outConfig},"SIGNAL ICU.signals" ;
	
	foreach my $signal (keys %signals1) {
		if (! exists $signals2{$signal}) {
			print LOG "SIGNAL $signal appears only in signals1\n" ;
		} else {
			die "signal type mismatch for $signal" if ($signals1{$signal} != $signals2{$signal}) ;
		}
		
		die "signal $signal is not in dictionary" if (! exists $dict->{codes}->{$signal}) ;
		print OUT "SIGNAL\t$signal\t$dict->{codes}->{$signal}\t$signals1{$signal}\n" ;
	}
	
	foreach my $signal (keys %signals2) {
		if (! exists $signals1{$signal}) {
			print LOG "SIGNAL $signal appears only in signals2\n" ;
			die "signal $signal is not in dictionary" if (! exists $dict->{codes}->{$signal}) ;
			print OUT "SIGNAL\t$signal\t$dict->{codes}->{$signal}\t$signals2{$signal}\n" ;
		}
	}	
	
	print OUT "SIGNAL\tDataBase\t$newSignalId\t0\n" ;
	close OUT ;
}

sub writeConfigFile {
	my ($outDir,$repDir,$outConfig) = @_ ;
	
	open (OUT,">$outDir/ICU.convert_config") or die "Cannot open convert_config file" ;
	
	map {print OUT "$_\n"} @{$outConfig} ;
	print OUT "DIR $outDir\n" ;
	print OUT "OUTDIR $repDir\n" ;
	print OUT "CONFIG ICU.repository\n" ;
	print OUT "MODE 3\n" ;
	
	close OUT ;
}