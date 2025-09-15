#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

sub test_panel_white_cells {
	my ($panel, $id, $days) = @_;
	
	my ($sum_pct, $sum_num) = (0.0, 0.0);
	map {$sum_pct += $panel->{$_} if ($panel->{$_} ne "NA")} (11, 12, 13, 14, 18);
	map {$sum_num += $panel->{$_} if ($panel->{$_} ne "NA")} (15, 16, 10, 17, 19);
	
	my $wbc = (exists $panel->{1}) ? $panel->{1} : "NA";
	print STDERR join("\t", "White Cells:", "$id\@$days", "$sum_pct (100.0)", "$sum_num ($wbc)") . "\n";	
}

my $test_loc_in_panel = {
	RBC => 0, WBC => 1, MPV => 2,  HGB => 3, HCT => 4,
	MCV => 5, MCH => 6, MCHC => 7, RDW => 8, PLT => 9,
	Eosino_num => 10,  Eosino_auto_num => 10, Eosino_man_num => 10,
	Neutro_pct => 11,  Neutro_auto_pct => 11, Neutro_man_pct => 11,
	Bands_pct => 11.1,  Bands_auto_pct => 11.1, Bands_man_pct => 11.1,
	Segs_pct => 11.2,  Segs_auto_pct => 11.2, Segs_man_pct => 11.2,
	Mono_pct => 12,  Mono_auto_pct => 12, Mono_man_pct => 12,
	Eosino_pct => 13,  Eosino_auto_pct => 13, Eosino_man_pct => 13,
	Baso_pct => 14,  Baso_auto_pct => 14, Baso_man_pct => 14,
	Neutro_num => 15,  Neutro_auto_num => 15, Neutro_man_num => 15,
	Bands_num => 15.1,  Bands_auto_num => 15.1, Bands_man_num => 15.1,
	Segs_num => 15.2,  Segs_auto_num => 15.2, Segs_man_num => 15.2,
	Mono_num => 16,  Mono_auto_num => 16, Mono_man_num => 16,
	Baso_num => 17,  Baso_auto_num => 17, Baso_man_num => 17,
	Lymph_pct => 18,  Lymph_auto_pct => 18, Lymph_man_pct => 18,
	Lymph_num => 19,  Lymph_auto_num => 19, Lymph_man_num => 19,
};
						 
sub handle_single_id_date_recs {
	my ($recs) = @_;
	my ($id, $days) = ($recs->[0][0], $recs->[0][1]);
	printf STDERR "Working on %d@%d with %d records\n", $id, $days, scalar(@$recs);

	# grouping records by test codes
	my $test_vals = {};
	for my $rec (@$recs) {
		my ($id, $days, $sp_num, $test_code, $test_val) = @$rec[0..4];
		die "Illegal test value $test_val in record @$rec" unless ($test_val eq "" or $test_val =~ m/^\d+(\.\d+)?$/);
		die "Missing test code $test_code in record @$rec" unless (exists $test_loc_in_panel->{$test_code});
		
		push @{$test_vals->{$test_code}}, {rec => $rec, val => $test_val};
	}
	
	# check consistency of multiple values (drop NA-only cases and cases where two non-NA values differ)
	my $uniq_test_recs_s1 = {};
	for my $test_code (sort {$test_loc_in_panel->{$a} <=> $test_loc_in_panel->{$b}} keys %$test_vals) {
		my $test_val_ary = $test_vals->{$test_code}; # values for a specific test
		
		if (@$test_val_ary > 1) {
			print STDERR join("\t", "Dup vals:", $test_code, scalar(@$test_val_ary), 
									$test_val_ary->[0]{val}, $test_val_ary->[1]{val}, 
									"1st record:", @{$test_val_ary->[0]{rec}}, 
									"2nd record:", @{$test_val_ary->[1]{rec}}) . "\n";
		}
		
		my $vals = {};
		map {$vals->{$test_val_ary->[$_]{val}} = $_ if ($test_val_ary->[$_]{val} ne "")} (0 .. scalar(@$test_val_ary) - 1);
		my @V = keys %$vals;
		if (@V == 1) {
			$uniq_test_recs_s1->{$test_code} = $test_val_ary->[$vals->{$V[0]}];
			print STDERR join("\t", "UNIQ:", @{$uniq_test_recs_s1->{$test_code}{rec}}) . "\n";
			if (@$test_val_ary > 1) {
				print STDERR "$test_code: Multiple consistent values\n";
			}
		}
		elsif (@V == 0) {
			print STDERR "$test_code: All values are NA\n";
		}
		else {
			print STDERR "$test_code: Multiple inconsistent values, none taken\n";
		}
	}
	
	# decide among the different tests of the same white cell type percentage or count;
	# current priorities are: man, undesignated, auto
	my $uniq_test_recs_s2 = {};
	map {$uniq_test_recs_s2->{$_} = $uniq_test_recs_s1->{$_} if (exists $uniq_test_recs_s1->{$_})} qw(RBC WBC MPV HGB HCT MCV MCH MCHC RDW PLT);
	for my $wct (qw(Baso Eosino Lymph Mono Neutro Segs Bands)) {
		for my $msr (qw(num pct)) {
			my @test_list;
			map {push @test_list, "$wct\_$_$msr" if (exists $uniq_test_recs_s1->{"$wct\_$_$msr"})} ("man_", "auto_", "");
			print STDERR join("\t", "Tests for $wct\_$msr:", "$id\@$days", scalar(@test_list), @test_list) . "\n";
			next if (@test_list == 0);
			if (@test_list == 1) {
				$uniq_test_recs_s2->{$wct . "_" . $msr} = $uniq_test_recs_s1->{$test_list[0]};
			}
			elsif (@test_list == 3) {
				$uniq_test_recs_s2->{$wct . "_" . $msr} = $uniq_test_recs_s1->{$wct . "_man_" . $msr};
			}
			else { # @test_lits == 2
				 if (exists $uniq_test_recs_s1->{$wct . "_man_" . $msr}) {
					$uniq_test_recs_s2->{$wct . "_" . $msr} = $uniq_test_recs_s1->{$wct . "_man_" . $msr};
				}
				else {
					$uniq_test_recs_s2->{$wct . "_" . $msr} = $uniq_test_recs_s1->{$wct . "_" . $msr};
				}
			}
			print STDERR join("\t", "WCT $wct\_$msr:", "$id\@$days", scalar(@test_list), @{$uniq_test_recs_s2->{$wct . "_" . $msr}{rec}}) . "\n";	
		}
	}
	
	# summing values for various kinds of neutrophils (Neutro, Segs, Bands)
	my $uniq_test_recs_s3 = {};
	map {$uniq_test_recs_s3->{$_} = $uniq_test_recs_s2->{$_} if (exists $uniq_test_recs_s2->{$_})} qw(RBC WBC MPV HGB HCT MCV MCH MCHC RDW PLT 
																 Baso_num Baso_pct Eosino_num Eosino_pct 
																 Lymph_num Lymph_pct Mono_num Mono_pct);
	for my $msr (qw(num pct)) {
		if (exists $uniq_test_recs_s2->{"Neutro_$msr"} or
			exists $uniq_test_recs_s2->{"Bands_$msr"} or
			exists $uniq_test_recs_s2->{"Segs_$msr"}) {
			$uniq_test_recs_s3->{"Neutro_$msr"}{val} = 0.0;
			$uniq_test_recs_s3->{"Neutro_$msr"}{rec} = undef;
			map {$uniq_test_recs_s3->{"Neutro_$msr"}{val} += $uniq_test_recs_s2->{"$_\_$msr"}{val} if exists ($uniq_test_recs_s2->{"$_\_$msr"}{val})} qw(Neutro Bands Segs);
			map {print STDERR join("\t", "Neutro subtype:", @{$uniq_test_recs_s2->{"$_\_$msr"}{rec}}) . "\n" if (exists $uniq_test_recs_s2->{"$_\_$msr"}{rec})} qw(Neutro Bands Segs);
			print STDERR join("\t", "Neutro final:", "Neutro_$msr", $uniq_test_recs_s3->{"Neutro_$msr"}{val}) . "\n";
		}
	}	
	
	# create CBC panel in internal order
	my @S = sort {$test_loc_in_panel->{$a} <=> $test_loc_in_panel->{$b}} keys %$uniq_test_recs_s3;
	print STDERR join("\t", "Test codes for panel:", @S, "\nPanel Locations:", map {$test_loc_in_panel->{$_}} @S) . "\n";
	my $panel_vals = {}; 
	map {$panel_vals->{$test_loc_in_panel->{$_}} = $uniq_test_recs_s3->{$_}{val}} keys %$uniq_test_recs_s3;
	print STDERR join("\t", "CBC panel:", "$id\@$days", map {((exists $panel_vals->{$_}) ? $panel_vals->{$_} : "NA")} (0..19)) . "\n";
	test_panel_white_cells($panel_vals, $id, $days);
	print join("\t", $id, $days, map {((exists $panel_vals->{$_}) ? $panel_vals->{$_} : "NA")} (0..19)) . "\n";
}

### main ####
my $skip_test = {Creatinine => 1, Ferritin => 1, NRBC =>1, RDWSD => 1};

# go over lab records
my ($prev_id, $prev_date) = (-1, -1);
my $recs = [];

print join("\t", qw(StudyID Lab_Index_Days RBC WBC MPV HGB HCT MCV MCH MCHC RDW PLT Eosino_num Neutro_pct Mono_pct Eosino_pct Baso_pct Neutro_num Mono_num Baso_num Lymph_pct Lymph_num)) . "\n";
while (<>) {
	chomp;
	my @F = split(/\t/);
	next if ($F[0] eq "StudyID");
	print STDERR join("\t", $F[3], ((exists $skip_test->{$F[3]}) ? "SKIP" : "TAKE"), $_) . "\n";
	next if (exists $skip_test->{$F[3]});
	if ($F[0] != $prev_id or $F[1] != $prev_date) {
		handle_single_id_date_recs($recs) if (@$recs > 0);
		($prev_id, $prev_date) = @F[0, 1];
		$recs = [];
	}
	push @$recs, [@F];
}
handle_single_id_date_recs($recs) if (@$recs > 0);
