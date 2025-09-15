#!/usr/bin/env perl 
use strict(vars);

die "Usage : $0 OldDir NewDir [-periodic]" unless (@ARGV == 2 or (@ARGV == 3 and $ARGV[-1] eq "-periodic")) ;
my @dirs = map {$ARGV[$_]} (0,1) ;
my $periodic = (@ARGV == 3) ;

my @dataSets = qw/LearnPredict THIN_Train/ ;
my @genders = qw/men women combined/ ;
my @measures = qw/EarlySens1 EarlySens2 EarlySens3/ ;
my @points = qw/FP1 FP2.5 FP5/ ;

my %measures = map {($_=>1)} @measures ;
my %points = map {($_=>1)} @points ;

my $suffix = ($periodic) ? "PeriodicAutoSim" : "AutoSim" ;

my %data ;
foreach my $dir (@dirs) {
	foreach my $dataSet (@dataSets) {
		foreach my $gender (@genders) {
	
			my $file = "$dir/Analysis.$dataSet.$gender.$suffix" ;
			print STDERR "Collecting data from $file\n" ;
			
			open (IN,$file) or die "Cannot open $file for reading" ;
			
			my $header = 1;
			my %cols ;
			
			while (<IN>) {
				chomp ;
				my @line = split ;
				
				if ($header) {
					map {$cols{$1} = $_ if ($line[$_] =~ /(\S+)-Mean/)} (0..$#line) ;
					$header = 0 ;
				} else {
					map {$data{$dir}->{$dataSet}->{$gender}->{$_}->{$line[0]} = $line[$cols{$_}]} keys %cols ;
				}
			}
			close IN ;
		}
	}
}

my %compare ;
my %periods ;
my %age_ranges ;
foreach my $dataSet (@dataSets) {
	foreach my $gender (@genders) {
		
		if ($periodic) {
			foreach my $key (keys %{$data{$dirs[0]}->{$dataSet}->{$gender}}) {
				if ($key =~ /Period-(\S+)-(\S+)\@(\S+)/) {
					my ($period,$measure,$point) = ($1,$2,$3) ;
					if (exists $measures{$measure} and exists $points{$point}) {
						foreach my $age_range (keys %{$data{$dirs[0]}->{$dataSet}->{$gender}->{$key}}) {
							die "Problem at $dataSet $gender $key" if (!exists $data{$dirs[1]}->{$dataSet}->{$gender}->{$key}->{$age_range}) ;
							my $diff = $data{$dirs[0]}->{$dataSet}->{$gender}->{$key}->{$age_range} <=> $data{$dirs[1]}->{$dataSet}->{$gender}->{$key}->{$age_range} ;
							map {$compare{$_}->{$diff} ++} ($dataSet,$gender,$measure,$point,$period,$age_range,"ALL") ;
							$periods{$period} = 1 ;
							$age_ranges{$age_range} = 1 ;
						}
					}
				}
			}
		} else {
			foreach my $measure (@measures) {
				foreach my $point (@points) {
					my $key = "$measure\@$point" ;
					die "Problem at $dataSet $gender $measure $point" if (!exists $data{$dirs[0]}->{$dataSet}->{$gender}->{$key}) ;
					foreach my $age_range (keys %{$data{$dirs[0]}->{$dataSet}->{$gender}->{$key}}) {
						die "Problem at $dataSet $gender $measure $point" if (!exists $data{$dirs[1]}->{$dataSet}->{$gender}->{$key}->{$age_range}) ;
						my $diff = $data{$dirs[0]}->{$dataSet}->{$gender}->{$key}->{$age_range} <=> $data{$dirs[1]}->{$dataSet}->{$gender}->{$key}->{$age_range} ;
						map {$compare{$_}->{$diff} ++} ($dataSet,$gender,$measure,$point,$age_range,"ALL") ;
						$age_ranges{$age_range} = 1 ;
					}
				}
			}
		}
	}
}

my @types = (@dataSets,@genders,@measures,@points) ;
push @types,sort keys %periods ;
push @types,sort keys %age_ranges ;
push @types,"ALL" ;

foreach my $key (@types) {
	my @vals = map {$compare{$key}->{$_} + 0} (-1,0,1) ;
	my $out = join "\t",@vals ;
	printf "%15s $out\n",$key ;
}
			