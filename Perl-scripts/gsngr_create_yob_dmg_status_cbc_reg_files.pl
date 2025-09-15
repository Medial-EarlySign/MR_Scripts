#!/usr/bin/env perl  -w

use strict;
use FileHandle;
use List::MoreUtils qw(uniq);
use Date::Calc qw(Add_Delta_Days);

sub hash_to_str {
    my ($h) = @_;

    my $res = "";
    map {$res .= $_ . " => " . $h->{$_} . "; ";} sort keys %$h;

    return $res;
}

sub parse_argv {
    my ($args) = (@_);
    my $res = {};

    my $iarg = 0;
    while ($iarg < @$args) {
		my $arg = $args->[$iarg];
		die "Argument $iarg ($arg) must be in --name format" unless ($arg =~ m/^\-\-([^\-]\S*)$/);
		my $name = $1;
		# check the next argument
		if (($iarg == @$args - 1) || # last argument
			($args->[$iarg + 1] =~ m/^\-\-/)) {
			$res->{$name} = 1; # a flag
			$iarg += 1;
		}
		else {
			my $next_arg = $args->[$iarg + 1];
			die "Argument $iarg ($next_arg) must be in a valid value format" unless ($next_arg =~ m/^([\S ]+)$/);
			$res->{$name} = $1;
			$iarg += 2;
		}
    }

    print STDERR hash_to_str($res) . "\n";
    return $res;
}

sub open_file {
    my ($fn, $mode) = @_;
    my $fh;
    
#   print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode";

    return $fh;
}

# split one line of comma delimited values with double quoted strings
#  ==> first value must be non-string
sub split_one_line {
 	my ($line) = @_;
	
	my @F = split(/,/, $line);
	my @R;
	my $same_val = 0;
	map {push @R, $_ if ($same_val == 0); $R[-1] .= $_ if ($same_val == 1); $same_val = ($R[-1] =~ m/^\"/ and not $R[-1] =~ m/\"$/) ? 1 : 0;} @F;
	map {$_ =~ s/^\"//; $_ =~ s/\"$//;} @R;
	
	return @R;
}

sub shift_gsngr_date {
	my ($dayDelta,  $index_day_year) = @_;
	
	my ($yr, $mo, $dy) = Add_Delta_Days($index_day_year, 07, 01, $dayDelta); # shifting with respect to the middle of index day year
	# print STDERR "Shifting middle of $index_day_year by $dayDelta days, reaching $yr-$mo-$dy\n";
	
	my $res = sprintf("%04d%02d%02d", $yr, $mo, $dy);
	# print STDERR "Formatted return date is $res\n";
	
	return $res;
}

sub day_diff_is_in_excluded_intrvls {
	my ($day_diff, $intrvl_array) = @_;
	# print STDERR "searching $day_diff in: " . join("; ", map {"(" . $_->[0] . ", " . $_->[1] . ")"} @$intrvl_array) . "\n";
	
	# simple linear search using built-in grep is fast enough
	my @cont_intrvls = grep {$intrvl_array->[$_][0] <= $day_diff and $day_diff <= $intrvl_array->[$_][1]} (0 .. @$intrvl_array - 1);
	# print STDERR "$day_diff is contained in intervals " . join(", ", @cont_intrvls) . "\n";
	
	return scalar(@cont_intrvls); 
}

sub print_cbc_info {
	my ($cbc_info, $nr, $cbc_fh, $nr2info, $skip_encntr_id) = @_;
	
	for my $fDate (sort {$a <=> $b} keys %$cbc_info) {
		next if (exists $skip_encntr_id->{$nr} and day_diff_is_in_excluded_intrvls($fDate, $skip_encntr_id->{$nr})); # CBC taken at a time close to a significant medcal event (e.g.; inpatient encounter)
		for my $encntr (keys %{$cbc_info->{$fDate}}) {
			my $panel = $cbc_info->{$fDate}{$encntr};
			# summing segs and bands percentages to get neutros percentage
			$panel->{12} = 0.0 if (exists $panel->{"12A"} or exists $panel->{"12B"});
			$panel->{12} += $panel->{"12A"} if (exists $panel->{"12A"});
			$panel->{12} += $panel->{"12B"} if (exists $panel->{"12B"});
			# summing segs and bands counts to get count
			$panel->{16} = 0.0 if (exists $panel->{"16A"} or exists $panel->{"16B"});
			$panel->{16} += $panel->{"16A"} if (exists $panel->{"16A"});
			$panel->{16} += $panel->{"16B"} if (exists $panel->{"16B"});
			
			# printing CBC info to file
			my $fDate_str = shift_gsngr_date($fDate, $nr2info->{$nr}{idy});
			map {$cbc_fh->print(join("\t", $nr, $_, $fDate_str, $panel->{$_}) . "\n")} grep {exists $panel->{$_}} (1 .. 20);
			
			# output panel info for stats
			my $reg_str = (exists $nr2info->{$nr}{reg}) ? join("; ", @{$nr2info->{$nr}{reg}}) : "Ctrl";
			my $panel_str = "";
			map {$panel_str .= (exists $panel->{$_}) ? 1 : 0} (1 .. 20);
			print STDERR join("\t", "CBC:", $nr, $nr2info->{$nr}{gender}, $nr2info->{$nr}{yob}, $reg_str, $fDate, $encntr, $panel_str) . "\n";
		}
	}
}

# === main ===

# example arguments:
# C:/Medial/Perl-scripts/gsngr_create_yob_dmg_status_cbc_reg_files.pl  --nr_offset 6000000 
# --pat_fn /cygdrive/w/CRC/MedMining04Jul2013/MEDREONC_DEMOGRAPHIC_FILE.csv 
# --med_fn /cygdrive/w/CRC/MedMining04Jul2013/MEDREONC_ONCOLOGY_FILE.csv 
# --ahd_fn /cygdrive/w/CRC/MedMining04Jul2013/FINDINGS_SORTED_BY_PT_ID.csv 
# --id2nr_fn /cygdrive/w/CRC/MedMining04Jul2013/ID2NR --yob_fn /cygdrive/w/CRC/MedMining04Jul2013/Byears 
# --status_fn /cygdrive/w/CRC/MedMining04Jul2013/Censor --dmg_fn /cygdrive/w/CRC/MedMining04Jul2013/Demographics 
# --cbc_fn /cygdrive/w/CRC/MedMining04Jul2013/PRE_SORT_CBC_Matrix --reg_fn /cygdrive/w/CRC/MedMining04Jul2013/PRE_SORT_Registry

# latest command line:
# C:/Medial/Perl-scripts/gsngr_create_yob_dmg_status_cbc_reg_files.pl  --nr_off
# set 6000000  --pat_fn /cygdrive/w/CRC/MedMining04Jul2013/MEDREONC_DEMOGRAPHIC_F
# ILE.csv  --rem_fn /cygdrive/w/CRC/MedMining04Jul2013/PT_ID_CTRL_W_MALIG_DX --me
# d_fn /cygdrive/w/CRC/MedMining04Jul2013/MEDREONC_ONCOLOGY_FILE.csv  
# --add_to_reg_fn /cygdrive/w/CRC/MedMining04Jul2013/CTRL_W_CRC_MALIG_DX_ADD_TO_REG_INFO 
# --ahd_fn /cygdrive/w/CRC/MedMining04Jul2013/FINDINGS_SORTED_BY_PT_ID.csv  --ignore_encntr_
# fn /cygdrive/w/CRC/MedMining04Jul2013/ENCNTR_ID_LOS_NOT_9X9X_INFO --ignore_encntr_win_size  30 --id2nr_fn /cygdri
# ve/w/CRC/MedMining04Jul2013/ID2NR --yob_fn /cygdrive/w/CRC/MedMining04Jul2013/B
# years  --status_fn /cygdrive/w/CRC/MedMining04Jul2013/Censor --dmg_fn /cygdrive
# /w/CRC/MedMining04Jul2013/Demographics  --cbc_fn /cygdrive/w/CRC/MedMining04Jul
# 2013/CBC_Matrix_LOS_9X9X --reg_fn /cygdrive/w/CRC/MedMining04Jul2013/Registry 

print STDERR "Command line: " . join(" ", $0, @ARGV) . "\n";

# parse arguments according to "--name1 val1 --flag1 --name2 val2" format (vals have no white space and no heading --)
my $p = parse_argv(\@ARGV); 

# offset for internal numbering
my $nr_offset = undef;
$nr_offset = $p->{nr_offset} if (exists $p->{nr_offset});
die "WRONG nr_offset $nr_offset" if (not defined $nr_offset or $nr_offset == 0);

# input files
my $pat_fh = open_file($p->{pat_fn}, "r");

my $rem_fh = undef;
$rem_fh = open_file($p->{rem_fn}, "r") if (exists $p->{rem_fn});

my $ignore_encntr_fh = undef;
$ignore_encntr_fh = open_file($p->{ignore_encntr_fn}, "r") if (exists $p->{ignore_encntr_fn});
my $ignore_encntr_win_size = 0;
$ignore_encntr_win_size = $p->{ignore_encntr_win_size} if (exists $p->{ignore_encntr_win_size});

my $med_fh = open_file($p->{med_fn}, "r");
my $add_to_reg_fh = undef;
$add_to_reg_fh = open_file($p->{add_to_reg_fn}, "r") if (exists $p->{add_to_reg_fn});

my $ahd_fh = open_file($p->{ahd_fn}, "r");
my $med_hist_codes_fh = undef;
if (exists $p->{med_hist_codes_fn}) { # read medical history codes
    $med_hist_codes_fh = open_file($p->{med_hist_codes_fn}, "r");
}

# output files
my $id2nr_fh = open_file($p->{id2nr_fn}, "w");
my $yob_fh = open_file($p->{yob_fn}, "w");
my $status_fh = open_file($p->{status_fn}, "w");
my $dmg_fh = open_file($p->{dmg_fn}, "w");
my $cbc_fh = open_file($p->{cbc_fn}, "w");
my $reg_fh = open_file($p->{reg_fn}, "w");
my $med_hist_recs_fh = undef;
if (exists $p->{med_hist_codes_fn}) { 
    $med_hist_recs_fh = open_file($p->{med_hist_recs_fn}, "w");
}

# prepare a list of id codes that should be skipped (included in a previous data set or otherwise considered inappropriate)
my $skip_id = {};
if (defined $rem_fh) { 
    while (<$rem_fh>) {
		chomp;
		my @F = split(/\t/);
		$skip_id->{$F[0]} = 1;
    }
	$rem_fh->close;
}

# prepare a list of id codes that should be added to the cancer registry (overrides the skip list)
my $add2reg_info = {};
if (defined $add_to_reg_fh) { 
    while (<$add_to_reg_fh>) {
		chomp;
		my @F = split(/\t/);
		$add2reg_info->{$F[0]} = {dx_day => $F[1], site	=> $F[2]};
    }
	$add_to_reg_fh->close;
}

# go over patient records and extract yob, dmg, and status entries
my $id2nr = {};
my $nr2info = {};
while (<$pat_fh>) {
    my @F = split_one_line($_);
	# print STDERR join("\t", @F) . "\n";
    if ($F[0] =~ m/PT_ID/) { # header line
		$nr_offset --; # adjust id to be 0-origin with respect to requested offset
		next;
    }
	
    my $id = $F[0];
    print STDERR "Skipping $id\n" if (exists $skip_id->{$id} and not exists $add2reg_info->{$id});
    next if (exists $skip_id->{$id} and not exists $add2reg_info->{$id});

    my $nr = $nr_offset + ($. - 1);
	
    my ($yob, $sex, $rDate, $xDate, $dDate) = 
	(substr($F[3], 0, 4), $F[5], $F[6], $F[8], $F[9]); 
    
	# year of birth
	my $age_at_index_day = $F[1];
	$age_at_index_day = 90 if ($age_at_index_day == 999);
	my $index_day_year = $F[10];
	if ($index_day_year eq "9X9X") {
		print STDERR "Unknown index day year for $id, set to 2008\n";
		$index_day_year = 2008;
	}
	$nr2info->{$nr}{idy} = $index_day_year;
	$yob = $index_day_year - $age_at_index_day;
	$nr2info->{$nr}{yob} = $yob;
	
	# gender
	my $gender = $F[2];
	do {print STDERR "Unknown gender for $id\n"; next;} if ($gender eq "Unknown");
	$gender = ($gender eq "Female") ? "F" : "M";
    $nr2info->{$nr}{gender} = $gender;
	
	# output all info bits together to keep in sync
	$id2nr->{$id} = $nr;
	$id2nr_fh->print($id . "\t" . $nr . "\n");
	$yob_fh->print("$nr $yob\n");
	$dmg_fh->print(join("\t", $nr, $yob, $gender) . "\n");
	
    # status (censor file)
	my $vital_stat = $F[8];
	if ($vital_stat eq "Deceased" or $vital_stat eq "Coroner\'s Case") {
		my $dDate = $F[9]; # day of death relative to index day
		if ($dDate eq "9X9X") {
			print STDERR "Bad death date $dDate for $id, set to index day\n";
			$dDate = 0;
		}
		$dDate = shift_gsngr_date($dDate, $index_day_year);
		$status_fh->print("$nr 2 8 $dDate\n");
		next;
    }
    if ($vital_stat eq "9X9X") { # missing, probably patient left the insurer
		my $xDate = $F[6]; # last active day relative to index day, assumed to indicate leaving date
		if ($xDate eq "9X9X") {
			print STDERR "Bad last active date $xDate for $id, set to index day\n";
			$xDate = 0;
		}	
		$xDate = shift_gsngr_date($xDate, $index_day_year);
		$status_fh->print("$nr 2 2 $xDate\n");
		next;
    }
    if ($vital_stat eq "Alive") {
		my $rDate = $F[5]; # first active day relative to index day
		if ($rDate eq "9X9X") {
			print STDERR "Bad first active date $rDate for $id, set to index day\n";
			$rDate = 0;
		}	
		$rDate = shift_gsngr_date($rDate, $index_day_year);
		$status_fh->print("$nr 1 1 $rDate\n");
		next;
    }    
    die "Illegal vital_stat code $vital_stat for $id";
}
$id2nr_fh->close;
$yob_fh->close;
$status_fh->close;
$dmg_fh->close;

# exit(0);

# Medhist file is left empty for now
if (exists $p->{med_hist_codes_fn}) {
    $med_hist_recs_fh->close;
}

# process cancer registry file
my $in_reg = {};
while (<$med_fh>) {
	my @F = split_one_line($_);
	my ($id, $seqnum, $icd, $site) = @F[0 .. 3];
	$in_reg->{$id} = 1;
	next unless (exists $id2nr->{$id});
	my $nr = $id2nr->{$id};
	
	if ($seqnum >= 60 && $seqnum <= 88) {
		print STDERR "Non-malignant neoplasm for $id:\n$_"; 
		next;
	}
	
	# registry date
	my $eDate = $F[38]; # date of first diagnosis, relative to index day
	if ($eDate eq "9X9X") {
		print STDERR "Missing first diagnosis date for nr=$nr, id=$id, record is ignored\n";
		next;
	}	
	$eDate = shift_gsngr_date($eDate, $nr2info->{$nr}{idy});
	$eDate = join("/", substr($eDate, 4, 2), substr($eDate, 6, 2), substr($eDate, 0, 4));
	
	# cancer type
	my ($status, $type, $organ) = ("cancer", "na", "na");
	
	# to be replaced or refined by using ICD codes
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Colon") if ($site =~ m/Colon/i or $site =~ m/Cecum/ or $site =~ m/Appendix/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Rectum") if ($site =~ m/Rectum/i or $site =~ m/Rectosigmoid/i or $site =~ m/Anus/i or $site =~ m/Anal canal/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Esophagus") if ($site =~ m/Esophagus/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Stomach") if ($site =~ m/Stomach/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Liver+intrahepatic bile") if ($site =~ m/Liver/i or $site =~ m/interhaptic bile/i);
	($status, $type, $organ) = 
		("Respiratory system", "Lung and Bronchus", "Unspecified") if ($site =~ m/Lung/i or $site =~ m/bronchus/i);
	
	my $reg_str = "Other cancer";
	$reg_str = $organ if ($status eq "Digestive Organs");
	$reg_str = $type if ($status eq "Respiratory system");
	push @{$nr2info->{$nr}{reg}}, $reg_str;
	
	print STDERR "REG: $nr,0,0,0,0,$eDate,0,$icd,0,0,0,0,0,0,$status,$type,$organ,0,0\n";	
	$reg_fh->print("$nr,0,0,0,0,$eDate,0,$icd,0,0,0,0,0,0,$status,$type,$organ,0,0\n");
}

# die "Terminating after creating Registry file";

# process additional registry records
for my $id (sort keys %$add2reg_info) {
	next if (exists $in_reg->{$id}); # already in original cancer registry
	next unless (exists $id2nr->{$id});
	my $nr = $id2nr->{$id};
	
	# registry date
	my $eDate = $add2reg_info->{$id}{dx_date}; # date of first diagnosis, relative to index day
	if ($eDate eq "9X9X") {
		print STDERR "Missing first diagnosis date for additional registry candidate nr=$nr, id=$id, record is ignored\n";
		next;
	}	
	$eDate = shift_gsngr_date($eDate, $nr2info->{$nr}{idy});
	$eDate = join("/", substr($eDate, 4, 2), substr($eDate, 6, 2), substr($eDate, 0, 4));
	
	# cancer type
	my ($status, $type, $organ) = ("cancer", "na", "na");
	my $site = $add2reg_info->{$id}{site};
	
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Colon") if ($site =~ m/Colon/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Rectum") if ($site =~ m/Rectum/i or $site =~ m/Rectosigmoid/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Esophagus") if ($site =~ m/Esophagus/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Stomach") if ($site =~ m/Stomach/i);
	($status, $type, $organ) = 
		("Digestive Organs", "Digestive Organs", "Liver+intrahepatic bile") if ($site =~ m/Liver/i or $site =~ m/interhaptic bile/i);
	($status, $type, $organ) = 
		("Respiratory system", "Lung and Bronchus", "Unspecified") if ($site =~ m/Lung/i or $site =~ m/bronchus/i);
	
	my $reg_str = "Other cancer";
	$reg_str = $organ if ($status eq "Digestive Organs");
	$reg_str = $type if ($status eq "Respiratory system");
	push @{$nr2info->{$nr}{reg}}, $reg_str;
	
	print STDERR "ADD2REG: $nr,0,0,0,0,$eDate,0,0,0,0,0,0,0,0,$status,$type,$organ,0,0\n";	
	$reg_fh->print("$nr,0,0,0,0,$eDate,0,0,0,0,0,0,0,0,$status,$type,$organ,0,0\n");
}
$reg_fh->close;

exit(0);

# translating Geisingr FIND_TYPE and FIND_UNIT to Medial CBC codes (partial list with most frequent type/unit pairs)
my $cbc_codes = {
	"RBC_M/UL" => 1, "RBC X 10 6" => 1, "RBC_10*6/UL" => 1, "RBC_X10*6" => 1, "RBC_10-6/UL" => 1,
	"WBC_K/UL" => 2, "WBC X 10 3" => 2, "WBC_10*3/UL" => 2, "WBC_X10*3" => 2, "WBC_10-3/UL" => 2,
	"MPV_FL" => 3, "MPV-OUTSIDE LAB_FL" => 3, 
	"HGB_G/DL" => 4, "HGB_GM/DL" => 4,
	"HCT_%" => 5,
	"MCV_FL" => 6, "MCV-OUTSIDE LAB_FL" => 6, 
	"MCH_PG" => 7, 
	"MCHC_G/DL" => 8, "MCHC_GM/DL" => 8,
	"RDW-OUTSIDE LAB_%" => 9,
	"PLATELET COUNT_K/UL" => 10, "PLATELET COUNT_10*3/UL" => 10, "PLATELET COUNT_X10-3" => 10, 
	"PLATELET COUNT_X10*3" => 10, "PLATELET COUNT_10-3/UL" => 10,
	"ABS. EOS_K/UL" => 11, "ABS. EOS_X 10 3" => 11, "ABS. EOS_X10*3" => 11,
	"EOS_%" => 14,
	"ABS. SEGS_K/UL" => "16A", "ABS. SEGS_X 10 3/UL" => "16A", "ABS. SEGS_X10*3/UL" => "16A",
	"SEGS_%" => "12A",
	"ABS. BANDS_K/UL" => "16B",
	"BANDS_%" => "12B", 
	"ABS. BASOS_K/UL" => 18, "ABS. BASOS_X 10 3/UL" => 18,
	"BASOS_%" => 15,
	"ABS. MONOS_K/UL" => 17, "ABS. MONOS_X 10 3/UL" => 17,
	"MONOS_%" => 13,
	"ABS. LYMPHS_K/UL" => 20, "ABS. LYMPHS_X 10 3/UL" => 20,
	"LYMPHS_%" => 19,
};
print STDERR "CBC keys: " . join("##-##", sort keys %$cbc_codes) . "\n";

# prepare a list of encntr_id such that encounters at certain window around them should be skipped when collecting CBC values 
# (e.g., encounters during hospitalization)
my $skip_encntr_id = {};
if (defined $ignore_encntr_fh) {
    while (<$ignore_encntr_fh>) {
		chomp;
		my @F = split(/\t/); # format: pt_id, encntr_id, first_day, last_day, <possibly additional fields>
		next if (not exists $id2nr->{$F[0]});
		push @{$skip_encntr_id->{$id2nr->{$F[0]}}}, [$F[2] - $ignore_encntr_win_size, $F[3] + $ignore_encntr_win_size];
    }
}

# sort skip intervals for each patient by start points, then end points, and uniqify
map {$skip_encntr_id->{$_} = [uniq sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @{$skip_encntr_id->{$_}}]} keys %$skip_encntr_id;

# go over Findings file records (pre-sorted by pt_id) and extract CBC results
my $cbc_info = {};
my $prev_nr = -1;
while (<$ahd_fh>) {
	print STDERR "Processing line $. in FINDINGS file\n" if ($. % 100000 == 0);
    my @F = split_one_line($_);
	# print STDERR join("\t", @F) . "\n";

    my ($id, $encntr, $fDate, $fTime, $fType, $fVal, $fUnit) = @F[0 .. 6];
    next unless (exists $id2nr->{$id});
	
	my $tu = uc($fType . "_" . $fUnit);
	# print STDERR "CBC key: ##" . $tu . "##\n";
    next unless (exists $cbc_codes->{$tu}); # CBC record
		
    if (not $fVal =~ m/^[-+]?[0-9]*\.?[0-9]+$/) { # floating number
		print STDERR "Illegal value in CBC test: $_";
		next;
	}
	
	# print STDERR "=> Found CBC record\n";

    my $nr = $id2nr->{$id};
	if ($nr != $prev_nr) {
		print_cbc_info($cbc_info, $prev_nr, $cbc_fh, $nr2info, $skip_encntr_id) if ($prev_nr != -1);
		$cbc_info = {};
		$prev_nr = $nr;
	}
	
	my $medr_code = $cbc_codes->{$tu};
	$cbc_info->{$fDate}{$encntr}{$medr_code} = $fVal;
}
print_cbc_info($cbc_info, $prev_nr, $cbc_fh, $nr2info, $skip_encntr_id) if ($prev_nr != -1);


