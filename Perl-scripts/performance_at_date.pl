#!/usr/bin/env perl

use strict;
use Getopt::Long;
use FileHandle;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my (%registry,%crc,%demographics,%mescores,%censor,%gastro,%print,%fobt) ;

# Read parameters
my $p = {
	dates => "20071001:20071231:20080101:20080401:20090101",
	pr => "0.01,0.03,0.05,0.10",
	ages => "40:50,50:60,60:70,70:80,80:90,40:89,50:75,50:55,55:60,60:65,65:70,70:75,75:80,80:85,85:90",
	gender => "combined",
	reg => "//server/Work/CancerData/AncillaryFiles/Registry",
	dem => "//server/Work/CancerData/AncillaryFiles/Demographics",
	stt => "//server/Work/CancerData/AncillaryFiles/Censor",
	gastro => "//server/Work/Users/Yaron/CRC/Article/NewArticle/All_Gasto_Related_Dates",
	fobt => "//server/Data/Maccabi_JUL2014/RCVD_16JUL2014/Fical_test_2014.txt",
	crc_out => "Cancers",
};
 
GetOptions($p,
	"dates=s",			# Dates of measurment (Comma-separated 4-plets : StartOfScoreingPeriod:StartOfGapPeriod:StartOfTargetPeriod:StartOfFollowUpPeriod)",
	"pr=s",				# Targets positive-rate (Comma-separated)
	"gender=s",			# gender to consider (Comma-separated)
	"scores=s",			# Scores file
	"dem=s",			# Demographics file
	"reg=s",			# Registry file
	"stt=s",			# Censor file
	"gastro=s",			# Gastro-Related dates
	"fobt=s",			# FOBT file
	"ages=s",			# Ages  (Comma-separated Min:Max)
	"fps_out=s",		# Output file for false positives samples information,
	"crc_out=s",		# Output file for CRC cases information
	"all_scores=s",		# Optional output file for all scores
);
		
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";
map {die "Missing required argument $_" unless (defined $p->{$_})} qw/dates pr scores ages/ ;

# Parameters
my @dates = split ",",$p->{dates} ;
my @prs = split ",",$p->{pr} ;
my @genders = split ",",$p->{gender} ;
my @ages = sort {$a<=>$b} split ",",$p->{ages} ;

my $nruns = (scalar @dates) * (scalar @prs) * (scalar @genders) * (scalar @ages) ;
print STDERR "NRUNS = $nruns\n" ;

# Read 
read_fobt($p->{fobt}) ; print STDERR "Read FOBT\n" ;
read_demographics($p->{dem}) ; print STDERR "Read Demographics\n" ;
read_scores($p->{scores}) ; print STDERR "Read Scores\n" ;
read_registry($p->{reg}) ; print STDERR "Read Registry\n" ;
read_censor($p->{stt}) ; print STDERR "Read Censor\n" ;
read_gastro($p->{gastro}) ; print STDERR "Read Gastro\n" ;

my $idx = 0 ;
print "Gender\tMin Age\tMax Age\tScore_Start\tGap_Start\tTarget_start\tFollowup_start\tPR\t" ;
print "Gap_NP\tGap_CRC_TP\tGap_CRC_FN\tGap_CRC_Sens\tGap_CRC_Yield\t" ;
print "Gap_GI_TP\tGap_GI_FN\tGap_GI_Sens\tGap_GI_Yield\t" ;
print "Gap_Other_TP\tGap_Other_FN\tGap_Other_Sens\tGap_Other_Yield\t" ;
print "Period_NP\tPeriod_CRC_TP\tPeriod_CRC_FN\tPeriod_CRC_Sens\tPeriod_CRC_Yield\t" ;
print "Period_GI_TP\tPeriod_GI_FN\tPeriod_GI_Sens\tPeriod_GI_Yield\t" ;
print "Period_Other_TP\tPeriod_Other_FN\tPeriod_Other_Sens\tPeriod_Other_Yield\t" ;
print "Extra_NP\tExtra_CRC_TP\tExtra_CRC_FN\tExtra_CRC_Sens\tExtra_CRC_Yield\t" ;
print "Extra_GI_TP\tExtra_GI_FN\tExtra_GI_Sens\tExtra_GI_Yield\t" ;
print "Extra_Other_TP\tExtra_Other_FN\tExtra_Other_Sens\tExtra_Other_Yield\t" ;
print "Period_Age_NP\tPeriod_CRC_Age_TP\tPeriod_CRC_Age_FN\tPeriod_CRC_Age_Sens\tPeriod_CRC_Age_Yield\n" ;

my %fps ;
my $file_counter = 0 ;
foreach my $gender (@genders) {
	die "Illegal gender \'$gender\'" if ($gender ne "men" and $gender ne "women" and $gender ne "combined") ;

	my @gender_ids = grep {($gender eq "combined") or ($gender eq "men" and $demographics{$_}->{gender} eq "M") or ($gender eq "women" and $demographics{$_}->{gender} eq "F")} keys %mescores ;
	
	foreach my $age_range (@ages) {
		$age_range =~ /(\d+):(\d+)/ or die "Cannot parse age-range $age_range" ;
		my ($min_age,$max_age) = ($1,$2) ;
			
		foreach my $date (@dates) {
			my ($score_start,$score_end,$gap_start,$target_start,$followup_start) = split ":",$date ;

			my $target_year = int($gap_start/10000) ;			
		
			my @age_ids ;
			foreach my $id (@gender_ids) {
				# Age Filter
				my $age = $target_year - $demographics{$id}->{byear} ;
				push @age_ids,$id  if ($age >= $min_age and $age <= $max_age) ;
			}
			
			# Collect

			my (%dates,%scores) ;
			foreach my $id (@age_ids) {
				# Get Relevant scores
				foreach my $date (sort {$a<=>$b} keys %{$mescores{$id}}) {
					next if ($date > $score_end) ;
					if ($date >= $score_start)  {
						$scores{$id} = $mescores{$id}->{$date} ;
						$dates{$id} = $date ;
					}
				}
			}
			
			# Count ids with scores -
			my $nids = scalar keys %scores ;
			print STDERR "Found $nids ids to check\n" ;

			# Mean Age
			my $sum_age = 0 ;
			map {$sum_age += $target_year - $demographics{$_}->{byear}} keys %scores ;
			my $mean_age = $sum_age/$nids ;
			print STDERR "Mean age = $mean_age\n" ;
			
			# Gender
			my $nmale = scalar grep {$demographics{$_}->{gender} eq "M"} keys %scores ;
			my $pmale = 100*$nmale/$nids ;
			print STDERR "%% of males = $pmale ($nmale)\n" ;
			
			# Ages, for comparison
			my %day_ages = map {($_ => (get_days($gap_start) - get_days($demographics{$_}->{byear}*10000 + 101))/365)} keys %scores ;

			my @all_scores = sort {$b<=>$a} map {$scores{$_}} keys %scores ;
			
			# Print to file, if required
			if (exists $p->{all_scores} and $p->{all_scores} ne "") {
				my $file_name = $p->{all_scores} ;
				open (OUT,">$file_name") or die "Cannot open $file_name for writing\n" ;
				map {print OUT "$_ $dates{$_} $scores{$_}\n"} keys %scores ;
				close OUT ;
			}
				
				
#			my @all_scores = sort {$b<=>$a} map {$scores{$_}} grep {! exists $registry{$_}} keys %scores ;
			my $nscores = scalar @all_scores ;
			my @all_ages = sort {$b<=>$a} map {$day_ages{$_}} keys %scores ;
						
			# Loop on PR			
			
			my (@age_bounds,@bounds) ;
			foreach my $pr (@prs) {
				
				# Target score
				my $np = int($nscores*$pr) ;
				my $target_score = $all_scores[$np] ;
				print STDERR "Target scores for $age_range..$date..$pr($np) == $target_score\n" ;
				push @bounds,$target_score ;
				
				my $target_age = $all_ages[$np] ;
				print STDERR "Target age for $age_range..$date..$pr($np)  == $target_age\n" ;
				push @age_bounds,$target_age ;
			}
			
			# Open
			$file_counter ++ ;
			
			my $crc_fh = FileHandle->new($p->{crc_out}.".$file_counter","w") or die "Cannot open samples file $p->{crc_out}" ;				
			$crc_fh->print("Cancers for $gender $age_range $date. Bounds = @bounds\n") ;			
			
			# Loop again 
			%print = {} ;
			for my $idx (0..$#prs) {
			
				my $target_score = $bounds[$idx] ;
				my $target_age = $age_bounds[$idx] ;
				my $pr = $prs[$idx] ;
				
				# Count Positives
				my ($gap_np,$age_period_np,$period_np,$followup_np) ;
				foreach my $id (keys %scores) {
					if ($scores{$id}>= $target_score) {
						my $last_date = $followup_start + 1 ;
						$last_date = $registry{$id}->[0]->{date} if (exists $registry{$id} and $registry{$id}->[0]->{date} < $last_date) ;
						$last_date = $censor{$id} if (exists $censor{$id} and $censor{$id} < $last_date) ;
						$gap_np ++ if ($last_date >= $gap_start) ;
						$followup_np ++ if ($last_date >= $followup_start) ;
						if ($last_date >= $target_start) {
							$period_np ++ ;
#							print_fp_sample($fps_fh,$id,$scores{$id},$score_start,$gap_start,\@bounds) if (exists $p->{fps_out} and ! exists $crc{$id}) ;
							$fps{$id}->{$date} = {pr => $pr, score =>$scores{$id}} if (! exists $fps{$id}->{$date} or $pr < $fps{$id}->{$date}->{pr}) ;
						}	
					}
					
					if ($day_ages{$id} >= $target_age) {
						my $last_date = $followup_start + 1 ;
						$last_date = $registry{$id}->[0]->{date} if (exists $registry{$id} and $registry{$id}->[0]->{date} < $last_date) ;
						$last_date = $censor{$id} if (exists $censor{$id} and $censor{$id} < $last_date) ;
						$age_period_np ++ if ($last_date > $target_start) ;
					}
				}
				
				# Get Sensitivities
				my %case_counts ;
					
				$idx ++ ;
				print STDERR "$idx/$nruns\n" ;
					
				my (@age_period_crc,@gap_crc,@period_crc,@extra_crc,@gap_gi,@period_gi,@extra_gi,@gap_other,@period_other,@extra_other) ;
				
				foreach my $id (keys %registry) {
					next if (!exists $scores{$id}) ;
						
					foreach my $rec (@{$registry{$id}}) {
						my $cancer_date = $rec->{date} ;
						next if ($cancer_date < $gap_start) ; 
						
						my $cancer = $rec->{type} ;
						my $type = ($scores{$id} >= $target_score) ? 1:0 ;
						my $age_type = ($day_ages{$id} >= $target_age) ? 1:0 ;
										
						my $print_type = "NO" ;
						if ($cancer_date < $target_start) {
							if ($cancer eq "Digestive Organs,Digestive Organs,Colon" or $cancer eq "Digestive Organs,Digestive Organs,Rectum") {
								$gap_crc[$type] ++ ;
								$print_type = "gap" ;
							} elsif ($cancer eq "Digestive Organs,Digestive Organs,Stomach" or $cancer eq "Digestive Organs,Digestive Organs,Esophagus") {
								$gap_gi[$type] ++ ;
							} else {
								$gap_other[$type] ++ ;
							}
						} elsif ($cancer_date < $followup_start) {
							if ($cancer eq "Digestive Organs,Digestive Organs,Colon" or $cancer eq "Digestive Organs,Digestive Organs,Rectum") {
								$period_crc[$type] ++ ;
								$print_type = "period" ;
							} elsif ($cancer eq "Digestive Organs,Digestive Organs,Stomach" or $cancer eq "Digestive Organs,Digestive Organs,Esophagus") {
								$period_gi[$type] ++ ;
							} else {
								$period_other[$type] ++ ;
							}
						} else {
							if ($cancer eq "Digestive Organs,Digestive Organs,Colon" or $cancer eq "Digestive Organs,Digestive Organs,Rectum") {
								$extra_crc[$type] ++ ;
								$print_type = "extra" ;
							} elsif ($cancer eq "Digestive Organs,Digestive Organs,Stomach" or $cancer eq "Digestive Organs,Digestive Organs,Esophagus") {
								$extra_gi[$type] ++ ;
							} else {
								$extra_other[$type] ++ ;
							}
						}
						print_crc_sample($crc_fh,$id,$scores{$id},$print_type,$score_start,$gap_start,\@bounds) if ($print_type ne "NO"); 

						$age_period_crc[$age_type] ++ if ($cancer_date >= $target_start and $cancer_date < $followup_start
														  and ($cancer eq "Digestive Organs,Digestive Organs,Colon" or $cancer eq "Digestive Organs,Digestive Organs,Rectum")) ;
											
						last ;
					}
				}

				# Print					
				printf "$gender\t$min_age\t$max_age\t$score_start\t$gap_start\t$target_start\t$followup_start\t%.2f",100*$pr ;
				print "\t$gap_np" ;
				print4(\@gap_crc,$gap_np) ;
				print4(\@gap_gi,$gap_np) ;
				print4(\@gap_other,$gap_np) ;
				print "\t$period_np" ;
				print4(\@period_crc,$period_np) ;
				print4(\@period_gi,$period_np) ;
				print4(\@period_other,$period_np) ;
				print "\t$followup_np" ;
				print4(\@extra_crc,$followup_np) ;
				print4(\@extra_gi,$followup_np) ;
				print4(\@extra_other,$followup_np) ;
				print "\t$age_period_np" ;
				print4(\@age_period_crc,$age_period_np) ;
				print "\n" ;					
			}

			$crc_fh->close() ;
		}
	}
}

my $fps_fh ;
if (exists $p->{fps_out}) {
	$fps_fh = FileHandle->new($p->{fps_out},"w") or die "Cannot open false positives file $p->{fps_out}" ;

	foreach my $id (keys %fps) {
		foreach my $range (keys %{$fps{$id}}) {
			print_fp_sample($fps_fh,$id,$fps{$id}) ;
		}
	}
}

################################################################
# Functions

sub print_crc_sample {
	my ($fh,$id,$score,$cancer,$score_start,$gap_start,$bounds) = @_ ;

	return if (exists $print{$id}) ;
	$print{$id} = 1 ;

	my $flags = join "\t",map {$score > $_ ? "T":"F"} @$bounds ;
	
	# Check Gastro
	my $clean = 1 ;
	if (exists $gastro{$id}) {
		foreach my $rec (@{$gastro{$id}}) {
			if ($rec->{date} >= $gap_start) {
				last ;
			} elsif ($rec->{date} >= $score_start) {
				$clean = 0 ;
				last ;
			}
		}
	}
		
	my @info ;
	push @info, map {[$_,"CBC"]} grep {$_ >= $score_start and $_ < $gap_start}  keys %{$mescores{$id}} ;
	push @info, map {[$_->{date},"Gastro:".$_->{type}]} grep {$_->{date} >= $score_start and $_->{date} < $gap_start}  @{$gastro{$id}} if (exists $gastro{$id}) ;
	push @info, map {[$_->{date},"Registry:".$_->{type}]}  @{$registry{$id}} if (exists $registry{$id});
	my $data = join "+", map {$_->[0].":".$_->[1]} sort {$a->[0] <=> $b->[0]} @info ;
	$fh->print("$id\t$score\t$flags\t$cancer\t$clean\t$data\n") ;
}

sub print_fp_sample {
	my ($fh,$id,$info) = @_ ;

	my ($score_start,$gap_start) ;
	
	my @scores ;
	foreach my $date (keys %$info) {
		$date =~ /(\d+):(\d+):(\d+):(\d+)/ or die "Cannot parse range $date\n" ;
		my ($iscore_start,$iscore_end,$igap_start) = ($1,$2,$3) ;
		die "Cannot handle multiple gap-start at the moment" if (defined $gap_start and $igap_start != $gap_start) ;
		$score_start = $iscore_start if (! defined $score_start or $iscore_start <  $score_start) ;
		$gap_start = $igap_start ;
		push @scores,sprintf("%f(TOP %f at $iscore_start:$iscore_end)",$info->{$date}->{score},$info->{$date}->{pr}) ;
	}
	my $scores = join "+",@scores ;
	
	# Check Gastro
	my $clean = 1 ;
	if (exists $gastro{$id}) {
		foreach my $rec (@{$gastro{$id}}) {
			if ($rec->{date} >= $gap_start) {
				last ;
			} elsif ($rec->{date} >= $score_start) {
				$clean = 0 ;
				last ;
			}
		}
	}
		
	my @info ;
	push @info, map {[$_,"CBC"]} grep {$_ >= $score_start and $_ < $gap_start}  keys %{$mescores{$id}} ;
	push @info, map {[$_->{date},"Gastro:".$_->{type}]} grep {$_->{date} >= $score_start and $_->{date} < $gap_start}  @{$gastro{$id}} if (exists $gastro{$id}) ;
	push @info, map {[$_->{date},"Registry:".$_->{type}]}  @{$registry{$id}} if (exists $registry{$id});
	my $data = join "+", map {$_->[0].":".$_->[1]} sort {$a->[0] <=> $b->[0]} @info ;
	$fh->print("$id\t$scores\t$clean\t$data\n") ;
}
	
sub print4 {
	my ($cnts,$np) = @_ ;
	
	my $fn = $cnts->[0] + 0 ;
	my $tp = $cnts->[1] + 0 ;
	my $yield = $tp/$np ;
	
	if ($tp + $fn > 0) {
		my $sens = $tp/($tp+$fn) ;
		printf "\t$tp\t$fn\t%.2f\t%.2f",100*$sens,100*$yield ;
	} else {
		printf "\t$tp\t$fn\t--\t%.2f",100*$yield ;
	}
}
		
sub read_registry {
	
	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$date,$type) = split /\t/,$_ ;
		
		push @{$registry{$id}},{date => $date, day => get_days($date), type => $type} ;
		$crc{$id} = 1 if ($type eq "Digestive Organs,Digestive Organs,Colon" or $type eq "Digestive Organs,Digestive Organs,Rectum") ;
	}
	
	foreach my $id (keys %registry) {
		my @recs = sort {$a->{day} <=> $b->{day}} @{$registry{$id}} ;
		$registry{$id} = \@recs ;
	}
	
	close IN ;
}

sub read_gastro {
	
	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$date,$type) = split /\t/,$_ ;
		
		if ($type eq "FOBT" and exists $fobt{$id}->{$date}) {
			my $n = $fobt{$id}->{$date}->[0] + $fobt{$id}->{$date}->[1] ;
			my $np = $fobt{$id}->{$date}->[1] + 0 ;
			$type .= "($np/$n)" ;
			delete $fobt{$id}->{$date} ;
		}
		
		push @{$gastro{$id}},{date => $date, day => get_days($date), type => $type} ;
	}
	
	foreach my $id (keys %gastro) {
		if (exists $fobt{$id}) {
			foreach my $date (keys %{$fobt{$id}}) {
				my $n = $fobt{$id}->{$date}->[0] + $fobt{$id}->{$date}->[0]->[1] ;
				my $np = $fobt{$id}->{$date}->[0]->[1] + 0 ;
				push @{$gastro{$id}},{date => $date, day=> get_days($date), type => "FOBT($np/$n)"} ;
			}
		}
	
		my @recs = sort {$a->{day} <=> $b->{day}} @{$gastro{$id}} ;
		$gastro{$id} = \@recs ;
	}
	
	close IN ;
}

sub read_scores {

	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$date,$score) = split ;
		$mescores{$id}->{$date} = $score ;
	}
	close IN ;
}

sub read_demographics {

	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$byear,$gender) = split ;
		
		$demographics{$id} = {byear => $byear, gender => $gender} ;
	}
	close IN ;
}

sub read_censor {

	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$status,$reason,$date) = split ;
		
		$censor{$id} = $date if ($status == 2) ;
	}
	close IN ;
}

sub read_fobt {
	my ($file) = @_ ;
	
	my $shlili = chr(215).chr(153).chr(215).chr(156).chr(215).chr(153).chr(215).chr(156).chr(215).chr(169) ;
	my $hiuvi =  chr(215).chr(153).chr(215).chr(145).chr(215).chr(149).chr(215).chr(153).chr(215).chr(151) ;
	my $shlili2 = chr(215).chr(153).chr(215).chr(156).chr(215).chr(153).chr(215).chr(156).chr(215).chr(169).chr(215).chr(153).chr(215).chr(149).chr(215).chr(158).chr(215).chr(161).chr(215).chr(157).chr(215).chr(147) ;
	my $hiuvi2 =  chr(215).chr(153).chr(215).chr(145).chr(215).chr(149).chr(215).chr(153).chr(215).chr(151).chr(215).chr(153).chr(215).chr(149).chr(215).chr(158).chr(215).chr(161).chr(215).chr(157).chr(215).chr(147) ;
	my %fobt_value = ("NEGATIVE" => 0,
					  "POSITIVE" => 1,
					  $hiuvi => 1,
					  $shlili => 0,
					  $shlili2=> 0,
					  $hiuvi2 => 1,
					  ) ;

	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		s/\r// ;
		my ($id,$code,$name,$date,$value) = split /\t/ ;
		$value =~s/ //g ;
		if (exists $fobt_value{$value}) {
			$date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ or die "Cannot parse $date" ;
			$date = "$1$2$3" ;
			$fobt{$id}->{$date}->[$fobt_value{$value}] ++ ;
		} 
	}
	close IN ;
}

sub get_days {
	my $date = shift @_ ;

	my $year = int ($date/100/100) ;
	my $month = int (($date % (100*100))/100) ;
	my $day = ($date % 100) ;
	
	my $days = 365 * ($year-1900) ;
	$days += int(($year-1897)/4) ;
	$days -= int(($year-1801)/100);
	$days += int(($year-1601)/400) ;

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	return $days ;
}