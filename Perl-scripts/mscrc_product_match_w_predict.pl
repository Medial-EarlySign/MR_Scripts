#!/usr/bin/env perl 
use strict(vars) ;
use Getopt::Long;
use FileHandle;
use Dumpvalue;

my $dumper = new Dumpvalue;

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

my $month2num = {Jan => "01", Feb => "02", Mar => "03", Apr => "04", 
				 May => "05", Jun => "06", Jul => "07", Aug => "08", 
				 Sep => "09", Oct => "10", Nov => "11", Dec => "12", 
				};

# convert MS_CRC_Scorer date format to the standard 8-digit format				
sub std_mscrc_date {
	my ($str) = @_;
	my @D = split(/-/, $str);
	
	my $res = $D[0] . $month2num->{$D[1]} . $D[2];
	return $res;
}

# === main ===

# processing paramters
my $P = [
	"scorer_fn | s | MS_CRC_Scorer output file| \"\"",
	"pred_fn | s | output file of predict.exe from development environment | \"W:/Users/Ami/Mac70.new/MaccabiValidation_predictions.men\"",
	"full_mode | i | true if MS_CRC_Scorer is scoring all CBCs | 0",
 ];

if ($ARGV[0] eq "\-h" || $ARGV[0] eq "\-\-help") {
	print STDERR "$0 version 1.0.13\nUsage:\n";
	map {my @F = split(/ \| /, $_); print STDERR "\-\-" . $F[0] . " (" . $F[1] . ") : " . $F[2] . (($F[3] ne  "") ? (" (default: " . $F[3] . ")") : "") . "\n";} @$P;
	exit(0);
}
	
my $params;
my $getopt_txt = "\$params = \{\n";
map {my @F = split(/ \| /, $_); $getopt_txt .= "\t" . $F[0] . " => " . $F[3] . ",\n" if ($F[3] ne "")} @$P;
$getopt_txt .= "\t};\n\n";

$getopt_txt .= "GetOptions(\$params,\n";
map {my @F = split(/ \| /, $_); $getopt_txt .= "\t\"" . $F[0] . "=" . $F[1] . "\",\t # " . $F[2] . "\n"} @$P;
$getopt_txt .= "\t);\n";
print STDERR "code for getopt:\n$getopt_txt\n";

eval($getopt_txt);   
print STDERR "Paramaters: " . join("; ", map {"$_ => $params->{$_}"} sort keys %$params) . "\n";

# initializations
my $scorer_fh = open_file($params->{scorer_fn}, "r");
my $pred_fh = open_file($params->{pred_fn}, "r");

# read MS_CRC_Scorer ouput
my $scores = {};
while (<$scorer_fh>) {
	chomp;
	my @F = split(/\t/);

	if ($F[2] eq "") {
		print STDERR "No score for: $_\n";
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
		print STDERR "DIFF: id $id in MS_CRC_Scorer file but not in predict file\n";
		$has_diff = 1 ;
		next;
	}
	my @S = sort {$a->[0] <=> $b->[0]} @{$scores->{$id}};
	my @P = sort {$a->[0] <=> $b->[0]} @{$preds->{$id}};
	
	if ($params->{full_mode}) {
		if ($#S != $#P) {
			print STDERR "DIFF: unequal number of scores and preds for id $id in full mode comparison\n";
			$has_diff = 1;
			next;
		}
		
		my $mismatch = -1;
		for my $idx (0..$#S) {
			if ($S[$idx]->[0] != $P[$idx]->[0] or $S[$idx]->[1] != $P[$idx]->[1]) {
				$mismatch = $_; 
				last ;
			}
		} 
		if ($mismatch >= 0) {
			print STDERR "DIFF: score and pred $mismatch for id $id are mismatching in full mode comparison\n" if ($mismatch >= 0);
			$has_diff = 1;
			next;
		}
	}
	else {
		if ($S[-1]->[0] != $P[-1]->[0] or $S[-1]->[1] != $P[-1]->[1]) {
			print STDERR "DIFF: score and last pred for id $id are mismatching in single mode comparison\n";
			$has_diff = 1;
			next;
		}
	}
	print STDERR "Scores and preds for $id are matching\n";
}

for my $id (sort {$a <=> $b} keys %$preds) {
	if (not exists $scores->{$id}) {
		print STDERR "DIFF: id $id in predict file but not in MS_CRC_Scorer file\n";
		$has_diff = 1;
	}
}

exit(1) if ($has_diff == 1);






