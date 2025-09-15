package VersionFreezeUtils ;
use Exporter qw(import) ;
use Getopt::Long;
use FileHandle;

our @EXPORT_OK = qw(txt2eng txt2expanded_eng dmg2tsv eng2prod de_expand_scores std_mscrc_date mscrc_engine_match_w_predict) ;

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

# Convert bin matrix (after bin2txt) to the engine input format (20 lines per panel)
sub txt2eng {
	my ($in_fn, $out_fn) = @_;
	my $in = open_file($in_fn, "r");
	my $out = open_file($out_fn, "w");
	
	while (<$in>) {
		chomp;
		my @F = split;
		map {$out->print(join("\t", int($F[0]), $_, int($F[1]), $F[8 + $_]) . "\n")} grep {$F[8+$_] != -1} (1..20);
	}
	$in->close;
	$out->close;
}

# Convert bin matrix (after bin2txt) and demographics to expanded input to engine, where each id is expanded to several ids - one per each CBC (with it's full history)
sub txt2expanded_eng {
	my ($inData,$outData,$inDmg,$outDmg) = @_ ;

	my %counters ;
	my $in = open_file($inData, "r");
	my $out = open_file($outData, "w");
	
	my @lines = () ;
	while (<$in>) {
		chomp;
		my @F = split;
		@lines = () if ((scalar(@lines) == 0) or ($F[0] != $lines[0]->[0])) ;

		my $ngood = scalar grep {$F[8+$_] != -1} (1..20) ;
		if ($ngood) {
			push @lines,\@F ;

			my $cnt = scalar @lines ;
			$counters{int($lines[0]->[0])} = $cnt ;
			foreach my $line (@lines) {
				map {$out->print(join("\t", int($line->[0])."_$cnt", $_, int($line->[1]), $line->[8 + $_]) . "\n")} grep {$line->[8+$_] != -1} (1..20);
			}
		}
	}
	$in->close;
	$out->close;
	
	$in = open_file($inDmg, "r") ;
	$out = open_file($outDmg, "w") ;
	
	while (<$in>) {
		chomp ;
		my ($id,@line) = split ;
		map {$out->print ("$id\_$_ @line\n")} (1..$counters{$id}) if (exists $counters{$id}) ;
	}
}

# Convert demographics file to a tab separated format
sub dmg2tsv {
	my ($in_fn, $out_fn) = @_;
	my $in = open_file($in_fn, "r");
	my $out = open_file($out_fn, "w");

	while (<$in>) {
		# print STDERR $_;
		s/ /\t/g;
		s/^/1\t/;
		# print STDERR $_;
		$out->print($_);
	}
	$in->close;
	$out->close;
}

# Convert engine input to the product emulator input format (20 lines per panel)
sub eng2prod {
	my ($in_pref, $out_pref) = @_;
	
	# Data
	my $in = open_file("$in_pref.Data.txt", "r");
	my $out = open_file("$out_pref.Data.txt", "w");

#	my @C = qw(5041 5048 50221 50223 50224 50225 50226 50227 50228 50229 50230 50232 50234 50235 50236 50237 50239 50241 50233 50238); 
	my @C = (1 .. 20);
	my @M = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
	
	while (<$in>) {
		chomp;
		my ($id,$test_id,$date,$val) = split;
		$date = join("-", substr($date, 0, 4), $M[substr($date, 4, 2) - 1], substr($date, 6, 2));
		$out->print(join("\t",1,$id,$C[$test_id - 1],$date,$val)."\n") ;
	}
	$in->close;
	$out->close;
	
	dmg2tsv("$in_pref.Demographics.txt","$out_pref.Demographics.txt") ;
}

# Convert output of scorer on expanded input to input for performance measurements
sub de_expand_scores {
	my ($in_fn, $out_fn) = @_;
	my $in = open_file($in_fn, "r");
	my $out = open_file($out_fn, "w");

	my $M = {Jan => 1,  Feb => 2,  Mar => 3,  
			 Apr => 4,  May => 5,  Jun => 6, 
			 Jul => 7,  Aug => 8,  Sep => 9,  
			 Oct => 10, Nov => 11, Dec => 12
			 };

	my %notLastMessages = (211 => 1) ;
	my %noScoreMessages = (201 => 1, 202 => 1, 203 => 1, 204 => 1, 205 => 1,225 => 1) ;
			 
	$out->print("Predictions\n");			 
	while (<$in>) {
		chomp ;
		my @F = split /\t/;
		my @messages = split " ",$F[3] ;
		my $notLastFlag = grep {exists $notLastMessages{$_}} @messages ;
		my $noScoreFlag = grep {exists $noScoreMessages{$_}} @messages ;
		
		die "Found score for $F[0] with messages = $F[3]" if ($noScoreFlag and $F[2] ne "") ;
		die "No score for $F[0] with messages = $F[3]" if ($F[2] eq "" and not $noScoreFlag) ;
		
		if ($F[2] ne "" and not $notLastFlag) { # Score given, and for the last CBC.
			$F[1] = sprintf("%04d%02d%02d", $1, $M->{$2}, $3) if ($F[1] =~ /(\d+)-(\S\S\S)-(\d+)/) ;
			my $id = ($F[0] =~/(\S+)_/) ? $1 : $F[0] ;
			$out->print("$id $F[1] $F[2]\n") ;
		}
	}
	
	$in->close ;
	$out->close ;
}

# Convert MS_CRC_Scorer date format to the standard 8-digit format				
sub std_mscrc_date {
	my $month2num = {Jan => "01", Feb => "02", Mar => "03", Apr => "04", 
				 May => "05", Jun => "06", Jul => "07", Aug => "08", 
				 Sep => "09", Oct => "10", Nov => "11", Dec => "12", 
				};

	my ($str) = @_;
	my @D = split(/-/, $str);
	
	my $res = $D[0] . $month2num->{$D[1]} . $D[2];
	return $res;
}

# Compare predictor output to engine output
# Compares only the score for the last CBC per patient
# Prints a detailed log into $match_output_fn argument
sub mscrc_engine_match_w_predict {
	my ($scorer_fn, $pred_fn, $match_output_fn, $demog_fn, $min_age, $max_age, $not_last_cbc_error_code) = @_;
		
	# initializations
	my $scorer_fh = open_file($scorer_fn, "r");
	my $pred_fh = open_file($pred_fn, "r");
	my $match_output_fh = open_file($match_output_fn, "w");
	my $demog_fh = open_file($demog_fn, "r");
	
	# read birth years
	my $id2byear = {};
	while (<$demog_fh>) {
		chomp;
		my @F = split;
		die "Line $. in demographics file $demog_fn pf illegal format: $_\n" unless (@F == 3);
		$id2byear->{$F[0]} = $F[1];
	}
	
	# read MeScorer ouput
	my $scores = {};
	my $ingored = {} ;
	
	while (<$scorer_fh>) {
		chomp;
		my @F = split(/\t/);

		# ignore uncalculated scores
		if ($F[2] eq "") {
			$match_output_fh->print("No score for: $_\n");
			next;
		}
		# ignore scores that were calculated for a past blood test
		if (index($F[3]," $not_last_cbc_error_code,") != -1 || index($F[3],"\t$not_last_cbc_error_code,") != -1) {
			$match_output_fh->print("Ignoring score due to NOT_LAST_CBC: $_\n");
			$ignored->{$F[0]} = 1 ;
		} else {
			push @{$scores->{$F[0]}}, [std_mscrc_date($F[1]), $F[2]];
		}
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
		# we only compare last score
		my @S = sort {$a->[0] <=> $b->[0]} @{$scores->{$id}};
		my @P = sort {$a->[0] <=> $b->[0]} @{$preds->{$id}};
	
		if ($S[-1]->[0] != $P[-1]->[0] or $S[-1]->[1] != $P[-1]->[1]) {
			$match_output_fh->print("DIFF: score (".$S[-1]->[0].": ".$S[-1]->[1].") and last pred (".$P[-1]->[0].": ".$P[-1]->[1].") for id $id are mismatching in single mode comparison\n");
			$has_diff = 1;
			next;
		}
		
		$match_output_fh->print("Scores and preds for $id are matching\n");
	}

	for my $id (sort {$a <=> $b} keys %$preds) {
		if (not exists $scores->{$id} and not exists $ignored->{$id}) {
			if (not exists $id2byear->{$id}) {
				$match_output_fh->print("DIFF: id $id in predict file but lacks birth year in MS_CRC_Scorer demographics file\n");
				$has_diff = 1;
			}
			else {
				my @P = sort {$a->[0] <=> $b->[0]} @{$preds->{$id}};
				my $age_at_test = int(($P[-1]->[0] / 10000) - $id2byear->{$id});				
				if ($age_at_test > $max_age or $age_at_test < $min_age) {
					$match_output_fh->print("No score for id $id from predict file in MS_CRC_Scorer file due to age ($age_at_test) out of range ($min_age, $max_age)\n");
				}
				else {
					$match_output_fh->print("DIFF: $id in predict file but not in MeScorer file\n");
					$has_diff = 1;
				}
			}
		}
	}	
	
	return ($has_diff == 1);
}