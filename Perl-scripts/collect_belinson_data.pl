#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my %stats ;

die "Usage : $0 inFile1 [inFile2 ....] signalNamesFile VenSignalsFile outFile" if (@ARGV < 3) ;
my $outFile = pop @ARGV ;
my $venSignalsFile = pop @ARGV ;
my $signalNamesFile = pop @ARGV ;
my @inFiles = @ARGV ;

my $outFileHandle = FileHandle->new($outFile,"w") or die "Cannot open \'$outFile\' for writing" ;

# Read Names
my $namesFileHandle = FileHandle->new($signalNamesFile,"r") or die "Cannot open $signalNamesFile for reading" ;

my %signalNames ;
while (<$namesFileHandle>) {
	chomp ; 
	my ($origin,$name) = split /\t/,$_ ;
	$signalNames{$origin} = $name ;
}
$namesFileHandle->close() ;
print STDERR "Done Reading Signal Names\n" ;

# Read Ven Signal File
my $venSignalsFileHandle = FileHandle->new($venSignalsFile,"r") or die "Cannot open $venSignalsFile for reading" ;

my %venSignals ;
while (<$venSignalsFileHandle>) {
	chomp ; 
	$venSignals{$_} = 1 ;
}
$venSignalsFileHandle->close() ;
print STDERR "Done Reading Ven signals\n" ;


# Read Files
my %signals ;
foreach my $inFile (@inFiles) {
	print STDERR "Working on $inFile\n" ;
	my $inFileHandle = FileHandle->new($inFile,"r") or die "Cannot open $inFile for reading" ;
	
	my $header = 1;
	while (<$inFileHandle>) {
		if ($header) {
			$header = 0 ;
		} else {
			chomp ;
			my ($id,$signal,$value,$unit,$time) = split /\t/,$_ ;
			next if ($time eq "") ;
			
			$time .= " 00:00:00" if ($time =~ /^(\d\d)\/(\d\d)\/(\d\d\d\d)$/) ;
			die "Cannot find name for signal \'$signal\'" if (! exists $signalNames{$signal}) ;
			$signals{$id}->{$signalNames{$signal}}->{$time} = [$value,$unit] ;
		}
	}
	$inFileHandle->close() ;
}

# Print
foreach my $id (keys %signals) {
	my %times ;
	map {$times{$_} = $signals{$id}->{"Art/Ven"}->{$_}->[0]} (keys %{$signals{$id}->{"Art/Ven"}}) if (exists $signals{$id}->{"Art/Ven"}) ;

	foreach my $signalName (keys %{$signals{$id}}) {
		if (exists $venSignals{$signalName}) {
			foreach my $time (keys %{$signals{$id}->{$signalName}}) {
				my $val = join "\t",@{$signals{$id}->{$signalName}->{$time}} ;
				if (exists $times{$time} and $times{$time} eq "Ven") {
					$outFileHandle->print("$id\t1\tVen$signalName\t$val\t$time\n") ;
				} elsif ((exists $times{$time} and $times{$time} eq "Art") or (!exists $times{$time})) {
					$outFileHandle->print("$id\t1\t$signalName\t$val\t$time\n") ;
				}
			}
		} else {
			foreach my $time (keys %{$signals{$id}->{$signalName}}) {
				my $val = join "\t",@{$signals{$id}->{$signalName}->{$time}} ;
				$outFileHandle->print("$id\t1\t$signalName\t$val\t$time\n") ;
			}
		}
	}
}