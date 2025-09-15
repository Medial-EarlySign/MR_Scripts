#!/usr/bin/env perl 

use strict;

# (1) quit unless we have the correct number of command-line args
my $num_args = $#ARGV + 1;
if ($num_args != 2) {
	print "\nUsage: transpose_bootstrap_results.pl input_file output_file\n";
	exit;
}
my $input = $ARGV[0];
my $output = $ARGV[1];

# (2) open files for reading and writing
open(FILE, "<$input") || die "File not found: "+$input;
open(OUT, ">$output") || die "File not found: "+$output;
my @lines = <FILE>;
close(FILE);

my $num_of_constant_columns = 4; # num of columns that are not bootstraped (do not have mean, sdv, etc.)
my $num_fields;
my $measure_set_size = 0;
my (%work_point_type, %work_point_val, %measure); # key = index of first col out of 4


my $first = 1;
foreach my $line (@lines) {
	chomp $line;
	my @fields = split("\t" ,$line);
	$num_fields = scalar @fields;
	# parse header - for each set of 4 columns save (1) working point type (SENS\SPEC) (2) working point value (3) measure name (AUC\SENS\...)
	if ($first == 1) {
		my $i = $num_of_constant_columns;
		while ($i < $num_fields) {
			my $curr_col = $fields[$i];
			
			# strip off the "-Mean"/"-Obs" string (depending on btstrp version)
			$measure_set_size = ($curr_col =~ /-Obs/ ? 5 : 4);
			$curr_col =~ s/-Mean|-Obs//ig;
			
			# is this a working-point-specific measure?
			my $at_index = index($curr_col, '@');
			if ($at_index == -1) { # not WP specific (e.g. AUC, NPOS, ...)
				$measure{$i} = $curr_col;
				$work_point_type{$i} = 'NA';
				$work_point_val{$i} = -1;	
			} else { # WP specific (e.g. SENS, PPV, ...)
				$measure{$i} = substr($curr_col, 0, $at_index);	
				if (index($curr_col, 'FP') == -1) {
					$work_point_type{$i} = 'Sensitivity';	
					$work_point_val{$i} = substr($curr_col, $at_index+1);	
				} else {
					$work_point_type{$i} = '100-Specificity';	
					$work_point_val{$i} = substr($curr_col, $at_index+3);	
				}
			}
			$i = $i + $measure_set_size;
		}
		# print headers for new file
		if ($measure_set_size == 4) {
			print OUT "Time_Window\tAge_Range\tWorking_Point_Type\tWorking_Point_Value\tMeasure\tMean\tSDV\tCI_Lower\tCI_Upper\n";
		} else {
			print OUT "Time_Window\tAge_Range\tWorking_Point_Type\tWorking_Point_Value\tMeasure\tObserved\tMean\tSDV\tCI_Lower\tCI_Upper\n";
		}
		$first = 0;
		
	# 2nd row and below
	} else {
		my $i = $num_of_constant_columns;
		while ($i < $num_fields) {
			if ($measure_set_size == 4) {
				print OUT $fields[0]."\t".$fields[1]."\t".$work_point_type{$i}."\t".$work_point_val{$i}."\t".$measure{$i}."\t".$fields[$i]."\t".$fields[$i+1]."\t".$fields[$i+2]."\t".$fields[$i+3]."\n";
			} else {
				print OUT $fields[0]."\t".$fields[1]."\t".$work_point_type{$i}."\t".$work_point_val{$i}."\t".$measure{$i}."\t".$fields[$i]."\t".$fields[$i+1]."\t".$fields[$i+2]."\t".$fields[$i+3]."\t".$fields[$i+4]."\n";
			}
			$i = $i + $measure_set_size;
		}
	}
}
close(OUT);
print STDERR "Completed transformation of bootstrap results file.\n";