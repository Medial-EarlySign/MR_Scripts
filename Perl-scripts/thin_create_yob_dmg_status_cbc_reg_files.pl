#!/usr/bin/env perl 

use strict;
use FileHandle;

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

	print STDERR "Successfuly opened $fn in mode $mode\n" ;
	
    return $fh;
}

sub read_medcode_file {
    my ($fh) = @_;

    my $res = {};
    while (<$fh>) {
	chomp;
	my ($code, $nrec, $npat, $desc, $comment, $status, $type, $organ) = split(/\t/);
	$desc =~ s/ *$//;
	$res->{$code} = {desc => $desc, status => $status, type => $type, organ => $organ};
	print STDERR "CBC readcode $code:\t" . hash_to_str($res->{$code}) . "\n";
    }

    printf STDERR "Read %d CBC readcodes\n", scalar(keys %$res);
    return $res;
}

sub read_med_hist_codes_file {
    my ($fh) = @_;

    my $res = {};
    while (<$fh>) {
	chomp;
	my ($code, $info, $type, $intrnl_code) = split(/\t/);
	$res->{$code} = {code => $intrnl_code, desc => $type . "; " . $info};
	print STDERR "MEDHIST readcode $code:\t" . hash_to_str($res->{$code}) . "\n";
    }

    printf STDERR "Read %d MEDHIST readcodes\n", scalar(keys %$res);
    return $res;
}

sub check_date {
    my ($date) = @_; # 20070825

    my ($y, $m, $d) = 
	(substr($date, 0, 4),
	 substr($date, 4, 2),  
	 substr($date, 6, 2));
    
    return ($y >= 1900 && $m >= 1 && $m <= 12 && $d >= 1 && $d <= 31);
}

sub format_date {
    my ($date) = @_; # 20070825

    my $eDate = 
	substr($date, 4, 2) . "/" . 
	substr($date, 6, 2) . "/" .  
	substr($date, 0, 4);
    
    return $eDate; # 08/25/2007
}

sub date2num {
    my ($date) = @_; # 20070825

    my $res = 
	substr($date, 0, 4) * 372 + 
	substr($date, 4, 2) * 31 +  
	substr($date, 6, 2);
    
    return $res;
}

sub translate_medcode_to_icd9_primary_site_code {

	my $medcode_to_icd9_table = <<EOT
B130.00 C18.3   Malignant neoplasm of hepatic flexure of colon                  COLON: Hepatic flexure of colon
B803000 C18.3   Carcinoma in situ of hepatic flexure of colon                   COLON: Hepatic flexure of colon
B131.00 C18.4   Malignant neoplasm of transverse colon                          COLON: Transverse colon
B803100 C18.4   Carcinoma in situ of transverse colon                           COLON: Transverse colon
B132.00 C18.6   Malignant neoplasm of descending colon                          COLON: Descending colon
B133.00 C18.7   Malignant neoplasm of sigmoid colon                             COLON: Sigmoid colon
B803300 C18.7   Carcinoma in situ of sigmoid colon                              COLON: Sigmoid colon
B134.00 C18.0   Malignant neoplasm of caecum                                    COLON: Cecum
B134.11 C18.0   Carcinoma of caecum                                             COLON: Cecum
B803400 C18.0   Carcinoma in situ of caecum                                     COLON: Cecum
B135.00 C18.1   Malignant neoplasm of appendix                                  COLON: Appendix
B803500 C18.1   Carcinoma in situ of appendix                                   COLON: Appendix
B136.00 C18.2   Malignant neoplasm of ascending colon                           COLON: Ascending colon
B803600 C18.2   Carcinoma in situ of ascending colon                            COLON: Ascending colon
B137.00 C18.5   Malignant neoplasm of splenic flexure of colon                  COLON: Splenic flexure of colon
B803700 C18.5   Carcinoma in situ of splenic flexure of colon                   COLON: Splenic flexure of colon
B575.00 C18.8   Secondary malignant neoplasm of large intestine and rectum      COLON: Overlapping lesion of colon
B13..00 C18.9   Malignant neoplasm of colon                                     COLON: Colon, NOS
B13z.11 C18.9   Colonic cancer                                                  COLON: Colon, NOS
B1z0.11 C18.9   Cancer of bowel                                                 COLON: Colon, NOS
B13z.00 C18.9   Malignant neoplasm of colon NOS                                 COLON: Colon, NOS
B902400 C18.9   Neoplasm of uncertain behaviour of colon                        COLON: Colon, NOS
B13y.00 C18.9   Malignant neoplasm of other specified sites of colon            COLON: Colon, NOS
BB5N.00 C18.9   [M]Adenomatous and adenocarcinomatous polyps of colon           COLON: Colon, NOS
B803z00 C18.9   Carcinoma in situ of colon NOS                                  COLON: Colon, NOS
B803.00 C18.9   Carcinoma in situ of colon                                      COLON: Colon, NOS
B140.00 C19.9   Malignant neoplasm of rectosigmoid junction                     RECTOSIGMOID JUNCTION: Rectosigmoid junction
B804000 C19.9   Carcinoma in situ of rectosigmoid junction                      RECTOSIGMOID JUNCTION: Rectosigmoid junction
B141.00 C20.9   Malignant neoplasm of rectum                                    RECTUM: Rectum, NOS
B141.11 C20.9   Carcinoma of rectum                                             RECTUM: Rectum, NOS
B141.12 C20.9   Rectal carcinoma                                                RECTUM: Rectum, NOS
B804100 C20.9   Carcinoma in situ of rectum                                     RECTUM: Rectum, NOS
B14..00 C21.8   Malignant neoplasm of rectum, rectosigmoid junction and anus    ANUS AND ANAL CANAL: Overlapping lesion of rectum, anus and anal canal
B14y.00 C21.8   Malig neop other site rectum, rectosigmoid junction and anus    ANUS AND ANAL CANAL: Overlapping lesion of rectum, anus and anal canal
EOT

	my $med2icd = {
		"B130.00"	=> "C18.3",
		"B803000"	=> "C18.3",
		"B131.00"	=> "C18.4",
		"B803100"	=> "C18.4",
		"B132.00"	=> "C18.6",
		"B133.00"	=> "C18.7",
		"B803300"	=> "C18.7",
		"B134.00"	=> "C18.0",
		"B134.11"	=> "C18.0",
		"B803400"	=> "C18.0",
		"B135.00"	=> "C18.1",
		"B803500"	=> "C18.1",
		"B136.00"	=> "C18.2",
		"B803600"	=> "C18.2",
		"B137.00"	=> "C18.5",
		"B803700"	=> "C18.5",
		"B575.00"	=> "C18.8",
		"B13..00" 	=> "C18.9",
		"B13z.11"	=> "C18.9",
		"B1z0.11"	=> "C18.9",
		"B13z.00"	=> "C18.9",
		"B902400"	=> "C18.9",
		"B13y.00"	=> "C18.9",
		"BB5N.00"	=> "C18.9",
		"B803z00"	=> "C18.9",
		"B803.00"	=> "C18.9",
		"B140.00"	=> "C19.9",
		"B804000"	=> "C19.9",
		"B141.00"	=> "C20.9",
		"B141.11"	=> "C20.9",
		"B141.12"	=> "C20.9",
		"B804100"	=> "C20.9",
		"B14..00"	=> "C21.8",
		"B14y.00"	=> "C21.8",
	};
	
	my ($medcode) = @_;
	my $icd = (exists $med2icd->{$medcode}) ? $med2icd->{$medcode} : 0;
	
	return $icd;
}

sub handle_single_pat {
    my ($pat_recs, $nr, 
	$codes, $reg_fh,
	$med_hist_codes, $med_hist_recs_fh) = @_;

    # print STDERR "Working on patient $nr\n";
    my @pre_reg_recs;
    for (@$pat_recs) {
		# print STDERR $_ . "\n";
		my $medflag = substr($_, 40, 1);
		next if ($medflag ne "R" && $medflag ne "S");

		my $medcode = substr($_, 32, 7);
		my $date = substr($_, 11, 8);
	
		if (exists $med_hist_codes->{$medcode}) {
			my $mh = $med_hist_codes->{$medcode};
			$med_hist_recs_fh->print(join("\t", $nr, $mh->{code}, $date, $mh->{desc}) . "\n");
		}

		next unless (exists $codes->{$medcode}); 
		my $info = $codes->{$medcode};
	
		print STDERR join("\t", "MED:", $nr, $date, $medcode, $info->{desc},
						$info->{status}, $info->{type}, $info->{organ}) . "\n";

		push @pre_reg_recs, {
			date => $date, 
			desc => $info->{desc}, status => $info->{status}, 
			type => $info->{type}, organ => $info->{organ},
			medcode => $medcode,
		};
		print STDERR hash_to_str($pre_reg_recs[-1]) . "\n";
    }

    my $pre_reg_skip = {};
    my $back_date = {};
    # determine anciliary or morphology cancer records that should be associated with more specific cancer records
    for (my $i = 0; $i < @pre_reg_recs; $i++) {
		next unless ($pre_reg_recs[$i]->{status} eq "anc" || $pre_reg_recs[$i]->{status} eq "morph");
		my $date_i = date2num($pre_reg_recs[$i]->{date});
		for (my $j = 0; $j < @pre_reg_recs; $j++) {
			next if ($j == $i);
			# print STDERR "$i: " . hash_to_str($pre_reg_recs[$i]) . " <=> " . "$j: " . hash_to_str($pre_reg_recs[$j]) . "\n";
			next unless ($pre_reg_recs[$j]->{status} eq "cancer");
			my $date_j = date2num($pre_reg_recs[$j]->{date});
			if (($date_i > $date_j) ||
				($date_i + 62 > $date_j)) {
				# printf STDERR "$i: Cancer anciliary/morphology record $i is associated with record $j (%d days) and is skipped\n", $date_i - $date_j;
				$pre_reg_skip->{$i} = 1;
				$back_date->{$j} = $pre_reg_recs[$i]->{date} if ($date_i < $date_j);
				last;
			}   		
		}
    }

    for (my $i = 0; $i < @pre_reg_recs; $i++) {
		next if (exists $pre_reg_skip->{$i});
		my $prc = $pre_reg_recs[$i];
		# print STDERR $nr, ": ", hash_to_str($prc), "\n";
		my ($date, $status, $type, $organ, $medcode) = ($prc->{date}, 
												$prc->{status}, $prc->{type}, $prc->{organ}, $prc->{medcode});
		next if ($status eq "ignore" or $status eq "benign");
		$date = $back_date->{$i} if (exists $back_date->{$i});
		my $eDate = format_date($date);
		my $icd = translate_medcode_to_icd9_primary_site_code($medcode);

		# change certain cancer entries to the terms used in Maccabi's registry
		if ($status eq "cancer") {
			if ($type eq "crc") {
				$status = "Digestive Organs";
				$type = "Digestive Organs";;
				$organ = ($organ =~ m/rectum/i) ? "Rectum" : "Colon";
			}
			if ($type eq "oeso") {
				$status = "Digestive Organs";
				$type = "Digestive Organs";;
				$organ = "Esophagus";
			}
			if ($type eq "stom") {
				$status = "Digestive Organs";
				$type = "Digestive Organs";;
				$organ = "Stomach";
			}
			if ($type eq "liver") {
				$status = "Digestive Organs";
				$type = "Digestive Organs";;
				$organ = "Liver+intrahepatic bile";
			}
			if ($type eq "lung") {
				$status = "Respiratory system";
				$type = "Lung and Bronchus";
				$organ = "Unspecified";
			}
			if ($type eq "pancreas") {
				$status = "Digestive Organs";
				$type = "Digestive Organs";
				$organ = "Pancreas";
			}
			if ($type eq "bladder") {
				$status = "Urinary Organs";
				$type = "Urinary Organs";
				$organ = "Bladder";
			}
			if ($type eq "prostate") {
				$status = "Male genital organs";
				$type = "Prostate";
				$organ = "Prostate";
			}
			if ($type eq "ovary") {
				$status = "Female genital organs";
				$type = "Ovary";
				$organ = "Ovary";
			}
		}

		print STDERR "REG: $nr,0,0,0,0,$eDate,$medcode,$icd,0,0,0,0,0,0,$status,$type,$organ,0,0\n";	
		$reg_fh->print("$nr,0,0,0,0,$eDate,$medcode,$icd,0,0,0,0,0,0,$status,$type,$organ,0,0\n");
    }
}

# === main ===

# example arguments:
# --nr_offset 0 --pat_fn /cygdrive/x/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_pat.csv --rem_fn /cygdrive/c/Data/THIN/pat_half_code2nr --med_fn /cygdrive/x/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_med.csv --ahd_fn /cygdrive/x/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_ahd.csv --cbc_codes_fn /cygdrive/t/THIN_train_x/med_code_cbc_lookup.txt --cbc_dist_fn /cygdrive/c/Data/THIN/cbc_dist_params_after_edit.tsv --codes_fn //server/Work/CRC/FullOldTHIN/thin_cancer_medcodes_info_25Feb_2015_w_morph.txt --id2nr_fn /cygdrive/x/Test/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_id2nr --yob_fn /cygdrive/x/Test/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_yob --status_fn /cygdrive/x/Test/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_status --dmg_fn /cygdrive/x/Test/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_dmg --cbc_fn /cygdrive/x/Test/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_cbc --reg_fn /cygdrive/x/Test/THIN_w_New_Controls_Feb2013/old_aff_w_new_ctrl_reg

print STDERR "Command line: " . join(" ", $0, @ARGV) . "\n";

# parse arguments according to "--name1 val1 --flag1 --name2 val2" format (vals have no white space and no heading --)

# follows is a bypass allowing to write _ instead of space for some names
$ARGV[3] =~ s/EPIC_65/EPIC 65/;
$ARGV[5] =~ s/EPIC_88/EPIC 88/;
$ARGV[7] =~ s/EPIC_65/EPIC 65/;

my $p = parse_argv(\@ARGV); 

# offset for internal numbering
my $nr_offset = 0;
$nr_offset = $p->{nr_offset} if (exists $p->{nr_offset});

# input files
my $pat_fh = open_file($p->{pat_fn}, "r");

my $rem_fh = undef;
$rem_fh = open_file($p->{rem_fn}, "r") if (exists $p->{rem_fn});

my $med_fh = open_file($p->{med_fn}, "r");

my $ahd_fh = open_file($p->{ahd_fn}, "r");

my $cbc_codes_fh = open_file($p->{cbc_codes_fn}, "r");
my $cbc_dist_fh = open_file($p->{cbc_dist_fn}, "r");
my $codes_fh = open_file($p->{codes_fn}, "r");

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

# prepare a list of id codes that should be skipped (included in a previous data set)
my $skip_id = {};
if (defined $rem_fh) { 
    while (<$rem_fh>) {
	chomp;
	my @F = split(/\t/);
	$skip_id->{$F[0]} = 1;
    }
}

# go over pat records and extract yob, dmg, and status entries
my $id2nr = {};
my $nr2gender = {};
while (<$pat_fh>) {
    chomp;
    if (m/patid/) { # header line
	$nr_offset --; # adjust id to be 0-origin with respect to requested offset
	next;
    }
    my @F = split(/,/);
    my $id = $F[0] . $F[1];
    print STDERR "Skipping $id\n" if (exists $skip_id->{$id});
    next if (exists $skip_id->{$id});


    my $nr = $nr_offset + ($. - 1);
    $id2nr->{$id} = $nr;
    my ($yob, $sex, $rDate, $xDate, $dDate) = 
	(substr($F[3], 0, 4), $F[5], $F[6], $F[8], $F[10]); 
    my $gender = ($sex == 1) ? "M" : "F";
    $nr2gender->{$nr} = $gender;

    $id2nr_fh->print($id . "\t" . $nr . "\n");
    $yob_fh->print("$nr $yob\n");
    if ($dDate ne "00000000") {
	$status_fh->print("$nr 2 8 $dDate\n");
    }
    elsif ($xDate ne "00000000") {
	$status_fh->print("$nr 2 2 $xDate\n");
    }
    else {
	$status_fh->print("$nr 1 1 $rDate\n");
    }    
    $dmg_fh->print(join("\t", $nr, $yob, $gender) . "\n");
}
$id2nr_fh->close;
$yob_fh->close;
$status_fh->close;
$dmg_fh->close;

# process file of cancer-related medcodes with relevant annotation
my $codes = read_medcode_file($codes_fh);

# process file of CRC-related medical history medcodes
my $med_hist_codes = {};
if (exists $p->{med_hist_codes_fn}) {
    $med_hist_codes = read_med_hist_codes_file($med_hist_codes_fh);
}

# go over med records, extract registry entries and (optionally) med_hist entries
my $prev_nr = -1;
my $pat_recs;
while (<$med_fh>) {
    chomp;
    my $id = substr($_, 0, 10);
    $id =~ s/,//;
    next unless (exists $id2nr->{$id});
    my $nr = $id2nr->{$id};
    if ($nr != $prev_nr) {
	handle_single_pat($pat_recs, $prev_nr, 
			  $codes, $reg_fh,
			  $med_hist_codes, $med_hist_recs_fh) if ($prev_nr != -1);
	$prev_nr = $nr;
	$pat_recs = [];
    }
    push @$pat_recs, $_;
}
handle_single_pat($pat_recs, $prev_nr, 
		  $codes, $reg_fh,
		  $med_hist_codes, $med_hist_recs_fh) if ($prev_nr != -1);
$reg_fh->close;

die "Terminating after creation of Registry";

# read codes of blood tests in AHD records
my $cbc_codes = {};
while (<$cbc_codes_fh>) {
    chomp;
    my @F = split(/\t/);
    my $medcode = $F[2];
    $cbc_codes->{$medcode} = {
	medr => $F[0], 
	name => $F[1], 
	desc => $F[3], 
	mac => $F[4],
    };
}
map {
    print STDERR hash_to_str($cbc_codes->{$_}) . "\n";
} keys %$cbc_codes;

# read expected distributions of blood count values in THIN data
my $cbc_dists = {};
map {$cbc_dists->{$_}{F} = []; $cbc_dists->{$_}{M} = [];} (1 .. 20); 
while (<$cbc_dist_fh>) {
    chomp;
    my @F = split(/\s+/);
    my ($medr, $gender, $count, $mean, $sd, $scale, $losig, $hisig) = @F;
    next if ($scale == 0.0); # unused unit
    push @{$cbc_dists->{$medr}{$gender}}, {mean => $mean, sd => $sd, 
					   scale => $scale, losig => $losig, hisig => $hisig};
    print STDERR join("\t", @F) . "\n";
}

# go over ahd records and extract CBC results
my $n = 0;
while (<$ahd_fh>) {
    chomp;
    my @F = split(/,/);
    my $id = $F[0] . $F[1];
    next unless (exists $id2nr->{$id});
    next unless ($F[4] eq "Y"); # valid record
    next unless (exists $cbc_codes->{$F[11]}); # CBC record
    my $medr_code = $cbc_codes->{$F[11]}{medr};
    my ($val, $meacode) = ($F[6], $F[7]);
    next unless ($val =~ m/^[-+]?[0-9]*\.?[0-9]+/); # floating number

    my $nr = $id2nr->{$id};
    my $date = $F[2];
    my $is_legal_date = check_date($date);
    print STDERR "Illegal date $date at record: $_\n" if (! $is_legal_date);
    next unless ($is_legal_date);

    my $gender = $nr2gender->{$nr};

    # match against test value distributions
    my $unmatched = 1;
    for my $d (@{$cbc_dists->{$medr_code}{$gender}}) {
	my $test_val = ($val - $d->{mean}) / $d->{sd};
	if (($test_val > - $d->{losig}) && ($test_val < $d->{hisig})) {
	    if ($unmatched == 1) {
		$unmatched = 0;
		# print STDERR "First match: " . join("\t", $nr, $medr_code, $meacode, $date, $val * $d->{scale}) . "\n";
		$cbc_fh->print(join("\t", $nr, $medr_code, $date, $val * $d->{scale}) . "\n");
		$n++;
	    }
	    else {
		print STDERR "Duplicate match: " . join("\t", $nr, $medr_code, $meacode, $date, $val * $d->{scale}) . "\n";
	    }	    
	}
    }
    if ($unmatched == 1) {
	my $d1 = $cbc_dists->{$medr_code}{$gender}[0];
	print STDERR "Unmatched:  " . join("\t", $nr, $medr_code, $meacode, $date, $val, $gender, 
											 $d1->{mean}, $d1->{sd}, $d1->{losig}, $d1->{hisig}) . "\n"; 
    }
}
print STDERR "Found $n records with accepted CBC values for all patients\n";
$cbc_fh->close;


0