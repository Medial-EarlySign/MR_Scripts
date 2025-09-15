#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

### functions

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

sub safe_exec {
	my ($cmd, $warn) = ("", 0);

	($cmd, $warn) = @_ if (@_ == 2);
	($cmd) = @_ if (@_ == 1);
	die "Wrong number of arguments fo safe_exec()" if (@_ > 2);
	
	print STDERR "\"$cmd\" starting on " . `date` ;
	my $rc = system($cmd);
	print STDERR "\"$cmd\" finished execution on " . `date`;
	die "Bad exit code $rc" if ($rc != 0 and $warn == 0);
	warn "Bad exit code $rc" if ($rc != 0);
}

sub intersect_lists {
	my ($list1, $list2) = @_;
	
	my $res = {};
	map {$res->{$_} = 1 if (exists $list2->{$_})} keys %$list1;
	
	printf STDERR "%d common ids in lists of sizes %d, %d\n", scalar(keys %$res), scalar(keys %$list1), scalar(keys %$list2);
	return $res;
}

sub union_lists {
	my ($list1, $list2) = @_;
	
	my $res = {};
	map {$res->{$_} = 1} keys %$list1;
	map {$res->{$_} = 1} keys %$list2;
	
	printf STDERR "%d ids in union of lists of sizes %d, %d\n", scalar(keys %$res), scalar(keys %$list1), scalar(keys %$list2);
	return $res;
}

sub subtract_lists {
	my ($list1, $list2) = @_;
	
	my $res = {};
	map {$res->{$_} = 1 unless (exists $list2->{$_})} keys %$list1;
	
	printf STDERR "%d ids in subtraction of lists of sizes %d, %d\n", scalar(keys %$res), scalar(keys %$list1), scalar(keys %$list2);
	return $res;
}
	
sub copy_list {
	my ($list) = @_;
	
	my $res = {};
	map {$res->{$_} = 1} keys %$list;
	
	return $res;
}	

sub read_gender_from_demog_file {
	my ($fn) = @_;
	
	my $fh = open_file($fn, "r");
	my $res = {};
	
	my $num = {};
	while (<$fh>) {
		chomp; s/\r//;
		next if (/numerator/i or /random_id/i);	
		my @F = split(/\t/);
		die "Wrong line format in $fn: $_" unless ($F[0] =~ /^\d+$/ and ($F[3] eq "F" or $F[3] eq "M"));
		$res->{$F[0]} = $F[3];
		$num->{$F[3]} ++;
	}
	print STDERR "Read $num->{F} females and $num->{M} males\n";
	
	$fh->close;
	return $res;
}

sub read_master_list {
	my ($fn, $id2gender) = @_;
	
	my $fh = open_file($fn, "r");
	my $res = {
		inhouse => {},
		extrnlv => {},
	};			
	
	my ($num_ih, $num_ex) = (0, 0);
	while (<$fh>) {
		chomp; s/\r//;
		next if (/numerator/i or /random_id/i);
		my ($id, $cls) = split(/\s+/);
		die "Wrong line format in $fn: $_" unless ($id =~ /^\d+$/ and ($cls == 0 or $cls == 1));
		if ($cls == 0) { 
			$res->{extrnlv}{$id} = 1; 
			$num_ex++;
		}
		else { # $cls == 1
			$res->{inhouse}{$id} = 1; 
			$num_ih++;
		}
	}
	print STDERR "Read $num_ex ExtrnlV ids, $num_ih Train + IntrnlV ids\n";
	$res->{extrnlv} = intersect_lists($res->{extrnlv},  $id2gender);
	$res->{inhouse} = intersect_lists($res->{inhouse},  $id2gender);
	
	$fh->close;
	return $res;
}

# read list in format 'id@date' and extract (unique) ids
sub read_id_date_list {
	my ($fn) = @_;
	
	my $fh = open_file($fn, "r");
	my $res = {};
	
	my $num_id = 0;
	while (<$fh>) {
		chomp; s/\r//;
		my ($id, $date) = split(/@/);
		die "Wrong line format in $fn: $_" unless ($id =~ /^\d+$/ and $date=~ /^\d+$/);
		$res->{$id} = 1;
		$num_id++;
	}
	print STDERR "Read $num_id ids\n";
	
	$fh->close;
	return $res;
}

sub complete_train_lists {
	my ($info) = @_;
	
	print STDERR "Entries for completing train lists:\n";
	map {print STDERR "$_\n"} keys %$info;
	
	for my $g (qw(women men)) {
		$info->{"Train/$g\_crc_and_stomach.bin"} = {};
		for my $i (1.. 8) {
			print STDERR "Union of Train/$g\_crc_and_stomach.bin with Train/SplitData/$g\_crc_and_stomach.test$i.bin:\n";
			$info->{"Train/$g\_crc_and_stomach.bin"} = union_lists($info->{"Train/$g\_crc_and_stomach.bin"},
																   $info->{"Train/SplitData/$g\_crc_and_stomach.test$i.bin"});
		}
		
		for my $j (1.. 8) {
			print STDERR "Subtracting Train/SplitData/$g\_crc_and_stomach.test$j.bin from Train/$g\_crc_and_stomach.bin:\n";
			$info->{"Train/SplitData/$g\_crc_and_stomach.train$j.bin"} = subtract_lists($info->{"Train/$g\_crc_and_stomach.bin"},
																			   $info->{"Train/SplitData/$g\_crc_and_stomach.test$j.bin"});
		}
	}
	
	print STDERR "Union of Train/women_crc_and_stomach.bin with Train/men_crc_and_stomach.bin:\n";
	$info->{"Train/combined_crc_and_stomach.bin"} = union_lists($info->{"Train/women_crc_and_stomach.bin"},
																$info->{"Train/men_crc_and_stomach.bin"});
	for my $k (1..8) {
		print STDERR "Union of Train/men_crc_and_stomach.bin with Train/SplitData/women_crc_and_stomach.train$k.bin:\n";
		$info->{"Train/SplitData/combined_crc_and_stomach.train$k.bin"} = union_lists($info->{"Train/SplitData/women_crc_and_stomach.train$k.bin"},
																					  $info->{"Train/SplitData/men_crc_and_stomach.train$k.bin"});
	}
}

sub extend_inhouse_lists {
	my ($info, $inhouse_list, $id2gender) = @_;
	
	for my $ih (keys %$inhouse_list) {
		my $g = ($id2gender->{$ih} eq "F") ? "women" : "men";
		next if (exists $info->{"Train/$g\_crc_and_stomach.bin"}{$ih} or
				 exists $info->{"IntrnlV/$g\_validation.bin"}{$ih});
		
		my $r = rand();
		if ($r < 0.125) { # IntrnlV
			$info->{"IntrnlV/$g\_validation.bin"}{$ih} = 1;
		}
		else { # Train
			my $i = int(8 * rand()) + 1; 
			$info->{"Train/SplitData/$g\_crc_and_stomach.test$i.bin"}{$ih} = 1;
		}
	}

	complete_train_lists($info);
}

#handle differently cases when an id_date file is available
sub write_vbf_files {
	my ($info, $id_date_info, $opath, $rep) = @_;
	
	safe_exec("mkdir -p $opath/ExtrnlV $opath/IntrnlV $opath/Train/SplitData");
	
	for my $f (keys %$info) {
		my $out_vfn = "$opath/$f";
		
		# copy id_date file (if available)
		if (defined $id_date_info) { # 'id@date' list
			safe_exec("\\cp $id_date_info->{$f} $out_vfn.id_date");
		}
		
		# write id_list file
		my $ifh = open_file("$out_vfn.id_list", "w");
		map {$ifh->print("$_\n")} sort {$a <=> $b} keys %{$info->{$f}};
		$ifh->close;
		
		# use in VBF id_date if available and id_list otherwise
		my $ofh = open_file($out_vfn,"w");
		my $sfx = (defined $id_date_info) ? "id_date" : "id_list";
		$ofh->print("#VBF\n");
		$ofh->print("#rep\t$rep\n");
		$ofh->print("#id_list\t$out_vfn.$sfx\n");
		$ofh->print("#groups\tCRC_and_Stomach_Cancer\n");
		$ofh->close;
	}
}

### main ###
my $p = {
	jun2013_id_date_lists_from_bin_root => "//server/Work/Users/Ami/CRC/RepBasedDataSets/Maccabi_JUN2013",
	oct2014_rep_path => "//server/Work/Users/Ami/CRC/RepBasedDataSets/Repositories/Maccabi/ver_OCT2014/maccabi.repository",
	oct2014_demog_file => "//server/Work/CRC/Maccabi_JUL2014/RcvdDataUnzipped/StatusCustomer_ASCII.txt",
	out_dir => "//server/Work/Users/Ami/CRC/RepBasedDataSets/MHS_ALL",
	mhs_2011_master_list => "//server/Data/Maccabi_JUL2014/medial_training_and_validation_2011.txt",  
	mhs_2011_subdir => "Maccabi_JUN2013",
	mhs_2014_master_list => "//server/Data/Maccabi_JUL2014/medial_training_and_validation_2014.txt",  
	mhs_2014_subdir => "Maccabi_OCT2014",
	mhs_2014_new_master_list => "//server/Data/Maccabi_JUL2014/medial_training_and_validation_2014_NEW.txt", 
	mhs_2014_new_subdir => "Maccabi_AUG2015",
};
	
GetOptions($p,
	"jun2013_id_date_lists_from_bin_root=s",	# location of id_date files that were derived directly from the Maccabi_JUN2013 bin files
	"oct2014_rep_path=s", 				# the path to the referen	ce repository containg the data for (almost) all of the numerators
	"out_dir=s",						# output dir for the VBF files
	"mhs_2011_master_list=s", 			# list with training/validation classification for the 2011 data set
	"mhs_2011_subdir=s",
	"mhs_2014_master_list=s",			# original list for the 2014 data set 
	"mhs_2014_subdir=s",
	"mhs_2014_new_master_list=s",		# fixed list for 2014, containing over 200K additional numerators
	"mhs_2014_new_subdir=s",
);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

srand(20150830);

my $id2gender = read_gender_from_demog_file($p->{oct2014_demog_file});

safe_exec("find $p->{jun2013_id_date_lists_from_bin_root} -name \"*.id_date\" > /tmp/id_date_files");
my $idh = open_file("/tmp/id_date_files", "r");
my $id_date_info = {}; # used only for the 2011 data set
my $id_list_info = {};
while (<$idh>) {
	chomp;
	my $full_path = $_;
	my $base_name = $full_path;
	$base_name =~ s/\.id_date//;
	$base_name =~ s/$p->{jun2013_id_date_lists_from_bin_root}//;
	$base_name =~ s/^\///;
	print STDERR "$base_name => $full_path\n";
	$id_date_info->{$base_name} = $full_path;
	$id_list_info->{mhs_2011}{$base_name} = intersect_lists(read_id_date_list($full_path), $id2gender);
}	
$idh->close;

my $mhs_2011_list = read_master_list($p->{mhs_2011_master_list}, $id2gender);
my $mhs_2014_list = read_master_list($p->{mhs_2014_master_list}, $id2gender);
my $mhs_2014_new_list = read_master_list($p->{mhs_2014_new_master_list}, $id2gender);

# adding ids not in bin files to the mhs_2011 lists
if ("mhs_2011" eq "mhs_2011") {
	for my $ix (keys %{$mhs_2011_list->{extrnlv}}) {
		my $g = ($id2gender->{$ix} eq "F") ? "women" : "men";
		$id_list_info->{mhs_2011}{"ExtrnlV/$g\_validation.bin"}{$ix} = 1;
	}

	extend_inhouse_lists($id_list_info->{mhs_2011}, $mhs_2011_list->{inhouse}, $id2gender);
	write_vbf_files($id_list_info->{mhs_2011}, $id_date_info, "$p->{out_dir}/$p->{mhs_2011_subdir}", $p->{oct2014_rep_path});
}

# extending 2011 lists to 2014 lists
if ("mhs_2014" eq "mhs_2014") {
	for my $ix (keys %{$mhs_2014_list->{extrnlv}}) {
		my $g = ($id2gender->{$ix} eq "F") ? "women" : "men";
		$id_list_info->{mhs_2014}{"ExtrnlV/$g\_validation.bin"}{$ix} = 1;
	}

	for my $gen (qw(women men)) {
		$id_list_info->{mhs_2014}{"IntrnlV/$gen\_validation.bin"} = copy_list($id_list_info->{mhs_2011}{"IntrnlV/$gen\_validation.bin"}); 
		$id_list_info->{mhs_2014}{"Train/$gen\_crc_and_stomach.bin"} = copy_list($id_list_info->{mhs_2011}{"Train/$gen\_crc_and_stomach.bin"});
		for my $i (1..8) {
			$id_list_info->{mhs_2014}{"Train/SplitData/$gen\_crc_and_stomach.test$i.bin"} = copy_list($id_list_info->{mhs_2011}{"Train/SplitData/$gen\_crc_and_stomach.test$i.bin"});
		}
	}
	
	extend_inhouse_lists($id_list_info->{mhs_2014}, $mhs_2014_list->{inhouse}, $id2gender); 
	write_vbf_files($id_list_info->{mhs_2014}, undef, "$p->{out_dir}/$p->{mhs_2014_subdir}", $p->{oct2014_rep_path});
}

# further extending 2014 lists to 2014_new lists
if ("mhs_2014_new" eq "mhs_2014_new") {
	for my $ix (keys %{$mhs_2014_new_list->{extrnlv}}) {
		my $g = ($id2gender->{$ix} eq "F") ? "women" : "men";
		$id_list_info->{mhs_2014_new}{"ExtrnlV/$g\_validation.bin"}{$ix} = 1;
	}

	for my $gen (qw(women men)) {
		$id_list_info->{mhs_2014_new}{"IntrnlV/$gen\_validation.bin"} = copy_list($id_list_info->{mhs_2014}{"IntrnlV/$gen\_validation.bin"}); 
		$id_list_info->{mhs_2014_new}{"Train/$gen\_crc_and_stomach.bin"} = copy_list($id_list_info->{mhs_2014}{"Train/$gen\_crc_and_stomach.bin"});
		for my $i (1..8) {
			$id_list_info->{mhs_2014_new}{"Train/SplitData/$gen\_crc_and_stomach.test$i.bin"} = copy_list($id_list_info->{mhs_2014}{"Train/SplitData/$gen\_crc_and_stomach.test$i.bin"});
		}
	}
	
	extend_inhouse_lists($id_list_info->{mhs_2014_new}, $mhs_2014_new_list->{inhouse}, $id2gender); 
	write_vbf_files($id_list_info->{mhs_2014_new}, undef, "$p->{out_dir}/$p->{mhs_2014_new_subdir}", $p->{oct2014_rep_path});
}





