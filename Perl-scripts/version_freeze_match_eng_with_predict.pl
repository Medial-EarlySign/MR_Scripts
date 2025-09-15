#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

# convert MS_CRC_Scorer date format to the standard 8-digit format				
my $month2num = {Jan => "01", Feb => "02", Mar => "03", Apr => "04", 
				 May => "05", Jun => "06", Jul => "07", Aug => "08", 
				 Sep => "09", Oct => "10", Nov => "11", Dec => "12", 
				};
				
sub std_mscrc_date {
	my ($str) = @_;
	my @D = split(/-/, $str);
	my $res = $D[0] . $month2num->{$D[1]} . $D[2];
	return $res;
}

sub mscrc_product_match_w_predict {
	my ($scorer_fn, $pred_fn, $match_output_fn) = @_;
		
	# initializations

	my $scorer_fh = open_file($scorer_fn, "r");
	my $pred_fh = open_file($pred_fn, "r");
	my $match_output_fh = open_file($match_output_fn, "w");

	# read MS_CRC_Scorer ouput
	my $scores = {};
	while (<$scorer_fh>) {
		chomp;
		my @F = split(/\t/);

		if ($F[2] eq "") {
			$match_output_fh->print("No score for: $_\n");
			next;
		}	
		push @{$scores->{$F[0]}}, [std_mscrc_date($F[1]), $F[2]];
	}

	# read predictions
	my $preds = {};
	while (<$pred_fh>) {
		next if ($. == 1); # skip first line
		chomp;
		
		my @F = split;
		die "Illegal date field in prediction file: $_" unless (length($F[1]) == 8);

		push @{$preds->{$F[0]}}, [$F[1], $F[2]];
	}

	# compare 
	my $has_diff = 0;
	for my $id (sort {$a <=> $b} keys %$scores) {
		if (not exists $preds->{$id}) {
			$match_output_fh->print("DIFF: id $id in MS_CRC_Scorer file but not in predict file\n");
			$has_diff = 1 ;
			next;
		}
		my @S = sort {$a->[0] <=> $b->[0]} @{$scores->{$id}};
		my @P = sort {$a->[0] <=> $b->[0]} @{$preds->{$id}};
	
		if ($S[-1]->[0] != $P[-1]->[0] or $S[-1]->[1] != $P[-1]->[1]) {
			$match_output_fh->print("DIFF: score and last pred for id $id are mismatching in single mode comparison\n");
			# print STDERR "ID: $id   Scorer: $S[-1]->[0] $S[-1]->[1]   Predictor: $P[-1]->[0] $P[-1]->[1]\n";
			$has_diff = 1;
			next;
		}
		
		$match_output_fh->print("Scores and preds for $id are matching\n");
	}

	for my $id (sort {$a <=> $b} keys %$preds) {
		if (not exists $scores->{$id}) {
			$match_output_fh->print("DIFF: id $id in predict file but not in MS_CRC_Scorer file\n");
			$has_diff = 1;
		}
	}	
	
	return ($has_diff == 1);
}

### Main ###				
my ($scorer_fn, $pred_fn, $match_output_fn) = @ARGV[0..2];
mscrc_product_match_w_predict($scorer_fn, $pred_fn, $match_output_fn);
