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

sub print_reg_entry {
	my ($nr, $dx_day, $idy, $site, $reg_fh) = @_;
	
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
	
	my $eDate = shift_gsngr_date($dx_day, $idy);
	$eDate = join("/", substr($eDate, 4, 2), substr($eDate, 6, 2), substr($eDate, 0, 4));
	
	print STDERR "REG: $nr,0,0,0,0,$eDate,0,0,0,0,0,0,0,0,$status,$type,$organ,0,0\n";	
	$reg_fh->print("$nr,0,0,0,0,$eDate,0,0,0,0,0,0,0,0,$status,$type,$organ,0,0\n");
}

### main ###

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
my $dx_info_fh = open_file($p->{dx_info_fn}, "r");

# output file
my $reg_fh = open_file($p->{reg_fn}, "w");

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
    print STDERR "Skipping $id\n" if (exists $skip_id->{$id});
    next if (exists $skip_id->{$id});

    my $nr = $nr_offset + ($. - 1); 
    
	$nr2info->{$nr}{idy} = $F[10]; # index day year
	
	if ($F[2] eq "Unknown") {
		print STDERR "Unknown gender for $id\n"; 
		next;
	} 
	
	# output all info bits together to keep in sync
	$id2nr->{$id} = $nr;
}

# process file with information about ICD-9 140-209 patient diagnostics;
# aiming not to construct a complete registry but one that is sufficient for CRC performance evaluation
my $in_reg = {};
while (<$dx_info_fh>) {
	chomp;
	my ($id, $icd9_str, $dx_day_str, $desc_str) = split(/\t/);
	$in_reg->{$id} = 1;
	next unless (exists $id2nr->{$id});
	my $nr = $id2nr->{$id};
	
	print STDERR "Working on DX info line: $_\n";
	my @icd9_list = split(/,/, $icd9_str);
	my @top_lvl_list = map {substr($_, 0, 3)} @icd9_list;
	my @dx_day_list = split(/,/, $dx_day_str); # sorted from earliest to latest
	my @desc_list = split(/,/, $desc_str);
	
	my @pri_list = 
		grep {$top_lvl_list[$_] < 195 or $top_lvl_list[$_] > 199} (0 .. $#top_lvl_list); # ignore, if possible, secondary and and site unspecified neoplasms
	if (@pri_list == 0) { # output earliest entry
		print_reg_entry($nr, $dx_day_list[0], $nr2info->{$nr}{idy}, "Other", $reg_fh);
		next;
	}

	my $top_lvl_out = {};
	for my $i (@pri_list) {
		my $tl = $top_lvl_list[$i];
		my $dd = $dx_day_list[$i];
		if (not exists $top_lvl_out->{$tl} or $top_lvl_out->{$tl} + 180 < $dd) {
			$top_lvl_out->{$tl} = $dd;
			my $site = "Other";
			$site = "Colon" if ($tl == 153);
			$site = "Rectum" if ($tl == 154);
			$site = "Esophagus" if ($tl == 150);
			$site = "Stomach" if ($tl == 151);
			$site = "Liver" if ($tl == 155);
			$site = "Lung" if ($tl == 162);
			print_reg_entry($nr, $dd, $nr2info->{$nr}{idy}, $site, $reg_fh);
		}
	}	
}
