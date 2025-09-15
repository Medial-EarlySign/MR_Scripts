#!/cygdrive/w/Applications/Perl64/bin/cygwin_perl

use strict;

#
# in file format:
# each line: 
# <signal name> <round factor> <normval dist> 

my $prog = "H:/Medial/Projects/General/MedExamples/x64/Release/Example1.exe";
my $lab_dir = "D:/medial/work/raw/Lab";

my $in_f = shift;
my $run_stages = shift;

my @stages = split /\,/,$run_stages; 
my $n_stages = @stages;

###--------------------------------------------------------------------------------------------------

print "Running distibution estimation on all signals\n";
#print "$prog\n";
#system("$prog --help");


open (INF,$in_f) or die "Can't open $in_f\n";

my $cmd;

while (<INF>) {
	next if /^#/;
	chomp;
	my @f = split / /,$_;
	my $nf = @f;
	
	my $i;
	my $run;
	my $sig = $f[0];
	$sig =~ s/\%/_p/g;
	print "sig is $f[0] -> $sig\n";
	my $hist_p = 0.999;
	if ($nf >= 4 && $f[3] =~ /^0/) {
		$hist_p = $f[3];
	}
	print "hist_p = $hist_p\n";
	my $sdir = $lab_dir."/".$sig;
	print "sdir = $sdir\n";
	system("mkdir -p $sdir");
	unlink glob("./*.csv");
	unlink "./general.txt";
	
	for ($i=0; $i<$n_stages; $i++) {
	
		print "running stage $stages[$i] for signal $f[0]\n";
		
		if ($stages[$i] eq "general") {
			$run = "$prog --describe --sig $f[0] --describe_mode general > $sdir/general.txt\n";
			print "running: $run";
			system("$run");
		}
		
		if ($stages[$i] eq "fit") {
			$run = "$prog --describe --sig $f[0] --describe_mode fit --describe_csv --round_factor $f[1] --max_hist_p $hist_p\n";
			print "running: $run";
			system("$run");
			system("cp dists.csv $sdir");
			system("cp hists.csv $sdir");
		}

		if ($stages[$i] eq "normval") {
			$run = "$prog --describe --sig $f[0] --describe_mode normval --describe_csv --round_factor $f[1] --normval_method $f[2]\n";
			print "running: $run";
			system("$run");
			system("cp ages.csv $sdir");			
		}
		
		if ($stages[$i] eq "delta") {
			$run = "$prog --describe --sig $f[0] --describe_mode delta --describe_csv --round_factor $f[1] --normval_method normal\n";
			print "running: $run";
			system("$run");
			system("cp deltas.csv $sdir");			
		}		
	}
}