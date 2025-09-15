#!/usr/bin/env perl 

use strict ;
use FileHandle;

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

die "Usage : $0 InDir OutDir EngineName" unless (@ARGV==3) ;
my ($inDir,$outDir,$engName) = @ARGV ;
		
my $setup = "$outDir/Setup" ;
my $setup_fh = open_file($setup, "w") ; 

$setup_fh->print("Features\tH:/Medial/Resources/MSCRC_Version_freezing_files/features_list\n") ;
$setup_fh->print("Extra\tH:/Medial/Resources/MSCRC_Version_freezing_files/engine_extra_params.txt\n") ;
foreach my $gender (qw/men women/) {
	$setup_fh->print($gender."Params\t$inDir/learn_$gender\_params\n") ;
	$setup_fh->print($gender."LM\t$inDir/learn_$gender\_params.init\n") ;
	$setup_fh->print($gender."RF\t$inDir/learn_$gender\_predictor.rf\n") ;
	$setup_fh->print($gender."GBM\t$inDir/learn_$gender\_predictor.gbm\n") ;
	$setup_fh->print($gender."Comb\t$inDir/learn_$gender\_predictor.comb\n") ;
}
$setup_fh->close ;	
system("H:/Medial/Projects/ColonCancer/prepare_engine_version/x64/Release/prepare_engine_version.exe rfgbm $setup $outDir") == 0 or die "Cannot prepare_engine_version" ;

my $version_fh = open_file("C:/MSCRC/Files/Versions.txt", "a") ;
$version_fh->print("$engName\t$outDir\n") ;
$version_fh->close ;
