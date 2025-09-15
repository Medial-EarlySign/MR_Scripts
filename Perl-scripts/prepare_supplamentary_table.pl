#!/usr/bin/env perl 
use strict(vars) ;

die "Usage $0 OptDir InDir" if (@ARGV != 2) ;
my ($OptDir,$InDir) = @ARGV ;

my $validation_file = "$OptDir\\FullAnalysis.combined.Validation" ;
my $thin_file = "$OptDir\\FullAnalysis.combined.THIN" ;
my $cv_file = "$OptDir\\FullAnalysis.combined.FullCV" ;
my $men_cv_file = "$OptDir\\FullAnalysis.men.FullCV" ;
my $women_cv_file = "$OptDir\\FullAnalysis.women.FullCV" ;
my $early_stage_file = "$OptDir\\Analysis.combined.FullCV.EarlyStage" ;
my $no_history_file = "$InDir\\Analysis.NoHistory.combined.Ptrn1" ;
my $age_file = "$OptDir\\AgeAnalysis.combined.LearnPredict" ;
my $extra_file = "$OptDir\\ExtraAnalysis" ;

my @header = ("Data Set","Age Range","Time Window","Gender","Cancer Cases","History Used","Predictor") ;
my $npref = scalar @header ;
my @header2 = ("AUC", "10% Sensitivity: Odds Ratio","10% Sensitivity: Speicificity","10% Sensitivity: Negative Predictive Value","10% Sensitivity: Positive Predictive Value",
			   "90% Specificity: Sensitivity","60% Sensitivity: Odds Ratio","60% Sensitivity: Speicificity","60% Sensitivity: Negative Predictive Value",
			   "60% Sensitivity: Positive Predictive Value") ;
push @header, map {($_,"","")} @header2 ;
my $header = join "\t",@header ;
print "$header\n" ;

my @subheader = ("") x $npref ;
push @subheader, map {("Mean","Standard Deviation","95% Confidence Interval")} (1..scalar(@header)) ;
my $subheader = join "\t",@subheader ;
print "$subheader\n" ;

my $data = read_file($validation_file) ;
foreach my $tw (qw/0-30 90-180/) {
	my $res = get_res($data->{"50-75"}->{$tw}) ;
	print "External Validation (Israel)\t50-75\t$tw\tCombined\tAll\tFull\tOur Model\t$res\n" ;
}

my $data = read_file($thin_file) ;
foreach my $tw (qw/0-30 90-180/) {
	my $res = get_res($data->{"50-75"}->{$tw}) ;
	print "External Validation (UK)\t50-75\t$tw\tCombined\tAll\tFull\tOur Model\t$res\n" ;
}

my $data = read_file($cv_file) ;
foreach my $tw (qw/0-30 90-180 0-60 60-120 120-180 180-240 240-300 300-360 360-420 420-480 480-540 540-600 600-660 660-720/) {
	my $res = get_res($data->{"50-75"}->{$tw}) ;
	print "Cross Validation\t50-75\t$tw\tCombined\tAll\tFull\tOur Model\t$res\n" ;
}

foreach my $tw (qw/0-30 90-180/) {
	foreach my $ar (qw/40-50 40-100/) {
		my $res = get_res($data->{$ar}->{$tw}) ;
		print "Cross Validation\t$ar\t$tw\tCombined\tAll\tFull\tOur Model\t$res\n" ;
	}
}

my $data = read_file($men_cv_file) ;
foreach my $tw (qw/0-30 90-180/) {
	my $res = get_res($data->{"50-75"}->{$tw}) ;
	print "Cross Validation\t50-75\t$tw\tMen\tAll\tFull\tOur Model\t$res\n" ;
}

my $data = read_file($women_cv_file) ;
foreach my $tw (qw/0-30 90-180/) {
	my $res = get_res($data->{"50-75"}->{$tw}) ;
	print "Cross Validation\t50-75\t$tw\tWomen\tAll\tFull\tOur Model\t$res\n" ;
}

my $data = read_file($early_stage_file) ;
foreach my $tw (qw/0-30 90-180/) {
	my $res = get_res($data->{"50-75"}->{$tw}) ;
	print "Cross Validation\t50-75\t$tw\tCombined\tIn-situ/Localized\tFull\tOur Model\t$res\n" ;
}

my $data = read_file($no_history_file) ;
foreach my $tw (qw/0-30 90-180/) {
	my $res = get_res($data->{"50-75"}->{$tw}) ;
	print "Cross Validation\t50-75\t$tw\tCombined\tAll\tNone\tOur Model\t$res\n" ;
}

my $data = read_file($age_file) ;
my $res = get_res($data->{"50-75"}->{"90-180"}) ;
print "Cross Validation\t50-75\t90-180*\tCombined\tAll\t-\tAge\t$res\n" ;

my $data = read_file($extra_file) ;

foreach my $tw (qw/0-30 90-180/) {
	foreach my $ar (qw/40-85/) {
		my $res = get_res($data->{$ar}->{$tw}) ;
		print "Cross Validation\t$ar\t$tw\tCombined\tAll\tFull\tOur Model\t$res\n" ;
	}
}

####################################################
sub read_file {
	my ($file) = shift @_ ;
	
	print STDERR "Reading $file\n" ;
	
	my %data ;
	my $head = 1 ;
	my @names ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	
	while (<IN>) {
		chomp ;
		my @line = split ;
		if ($head) {
			$head = 0 ;
			@names = @line ;
			die "Something wrong in header of $file !" unless ($names[0] eq "Time-Window" and $names[1] eq "Age-Range") ;
		} else {
			map {$data{$line[1]}->{$line[0]}->{$names[$_]} = $line[$_]} (0..$#line) ;
		}
	}
	close IN ;
	
	return \%data ;
}

sub get_res {
	my $data = shift @_ ;
	
	my @res  ;
	
	push @res,sprintf("%.2f",$data->{"AUC-Mean"}) ;
	push @res,sprintf("%.2f",$data->{"AUC-Sdv"}) ;
	push @res,sprintf("[%.2f,%.2f]",$data->{"AUC-CI-Lower"},$data->{"AUC-CI-Upper"}) ;
	
	if ($data->{"OR\@10-Mean"} < 5) {
		push @res,sprintf("%.1f",$data->{"OR\@10-Mean"}) ;
		push @res,sprintf("%.1f",$data->{"OR\@10-Sdv"}) ;
		push @res,sprintf("[%.1f,%.1f]",$data->{"OR\@10-CI-Lower"},$data->{"OR\@10-CI-Upper"}) ;
	} else {
		push @res,sprintf("%.0f",$data->{"OR\@10-Mean"}) ;
		push @res,sprintf("%.0f",$data->{"OR\@10-Sdv"}) ;
		push @res,sprintf("[%.0f,%.0f]",$data->{"OR\@10-CI-Lower"},$data->{"OR\@10-CI-Upper"}) ;
	}
	
	push @res,sprintf("%.2f",$data->{"SPEC\@10-Mean"}) ;
	push @res,sprintf("%.2f",$data->{"SPEC\@10-Sdv"}) ;
	push @res,sprintf("[%.2f,%.2f]",$data->{"SPEC\@10-CI-Lower"},$data->{"SPEC\@10-CI-Upper"}) ;
	
	push @res,sprintf("%.2f",$data->{"NPV\@10-Mean"}) ;
	push @res,sprintf("%.2f",$data->{"NPV\@10-Sdv"}) ;
	push @res,sprintf("[%.2f,%.2f]",$data->{"NPV\@10-CI-Lower"},$data->{"NPV\@10-CI-Upper"}) ;
	
	push @res,sprintf("%.2f",$data->{"PPV\@10-Mean"}) ;
	push @res,sprintf("%.2f",$data->{"PPV\@10-Sdv"}) ;
	push @res,sprintf("[%.2f,%.2f]",$data->{"PPV\@10-CI-Lower"},$data->{"PPV\@10-CI-Upper"}) ;
	
	push @res,sprintf("%.1f",$data->{"SENS\@90-Mean"}) ;
	push @res,sprintf("%.1f",$data->{"SENS\@90-Sdv"}) ;
	push @res,sprintf("[%.1f,%.1f]",$data->{"SENS\@90-CI-Lower"},$data->{"SENS\@90-CI-Upper"}) ;

	push @res,sprintf("%.1f",$data->{"OR\@60-Mean"}) ;
	push @res,sprintf("%.1f",$data->{"OR\@60-Sdv"}) ;
	push @res,sprintf("[%.1f,%.1f]",$data->{"OR\@60-CI-Lower"},$data->{"OR\@60-CI-Upper"}) ;
	
	push @res,sprintf("%.2f",$data->{"SPEC\@60-Mean"}) ;
	push @res,sprintf("%.2f",$data->{"SPEC\@60-Sdv"}) ;
	push @res,sprintf("[%.2f,%.2f]",$data->{"SPEC\@60-CI-Lower"},$data->{"SPEC\@10-CI-Upper"}) ;
	
	push @res,sprintf("%.2f",$data->{"NPV\@60-Mean"}) ;
	push @res,sprintf("%.2f",$data->{"NPV\@60-Sdv"}) ;
	push @res,sprintf("[%.2f,%.2f]",$data->{"NPV\@10-CI-Lower"},$data->{"NPV\@10-CI-Upper"}) ;
	
	push @res,sprintf("%.2f",$data->{"PPV\@60-Mean"}) ;
	push @res,sprintf("%.2f",$data->{"PPV\@60-Sdv"}) ;
	push @res,sprintf("[%.2f,%.2f]",$data->{"PPV\@60-CI-Lower"},$data->{"PPV\@60-CI-Upper"}) ;
	
	my $out = join "\t",@res ;
	return $out ;
}