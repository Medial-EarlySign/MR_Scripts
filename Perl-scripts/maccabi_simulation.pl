#!/cygdrive/w/Applications/Perl64/bin/cygwin_perl

use strict ;
my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my ($min_age,$max_age) = (50,75) ;

# max_reg = 20131004
#max predict = 20140727

# colon appoint - the date the colonscopy appoint was given
# Gastro visits - the date of the patient visit in the Gastro

#my $simulation_start = 20080101;

my $simulation_start = 20090601;
my $simulation_end   = 20100101;

#my $simulation_start = 20120701;
#my $simulation_end = 20140701;

#not in use
my $traning_factor = 0.7;
my $period_factor = 30;
my $factor = $period_factor/$traning_factor;


my $colon_appoint;
open (COLON_APPOINT,"ColonApoint.csv") or die "Cannot open ColonApoint.csv files" ;
my $colon_appoint_count=0;
while (<COLON_APPOINT>) {
	chomp ;
	my @lines = split  "," ;
	my $id = $lines[0];
	my $date_tofes = $lines[1];
	my $date_tofes_n = get_days($lines[1]);
	
	if ($colon_appoint_count>0) {
		push @{$colon_appoint->{$id}} ,$date_tofes_n;
		#print join("\t", $id , $date_tofes , $date_tofes_n );
	}
	$colon_appoint_count++;
}
close (COLON_APPOINT) ;
print "read colon appoint visit $colon_appoint_count.....\n";



my $colons;
open (COLON,"T:/Maccabi_JUL2014/RCVD_07OCT2014/colonoscopys_maccabi_2014_CONVERTED.txt") or die "Cannot open colons files" ;
my $colon_count=0;
while (<COLON>) {
	chomp ;
	my @lines = split  "\t" ;
	$colon_count++;
	next if ($colon_count<=2);
	my $id = $lines[0];
	my $colon_date = $lines[4];
	my $colon_date_n = get_days($lines[4]);
	
	push @{$colons->{$id}} ,$colon_date_n;
	#print join ("\t", $id , $colon_date);
}
close (COLON) ;
print "read colons $colon_count.....\n";


my $fecal;
open (FECAL,"fecal.txt") or die "Cannot open fecal files" ;
my $fecal_count=0;
while (<FECAL>) {
	chomp ;
	my @lines = split  "\t" ;
	$fecal_count++;
	my $id = $lines[0];
	my $fecal_date = $lines[1];
	my $fecal_date_n = get_days($lines[1]);
	
	push @{$fecal->{$id}} ,$fecal_date_n;
	#print join ("\t", $id , $fecal_date);
}
close (FECAL) ;
print "read fecal $fecal_count.....\n";




my $gastro;
open (GASTRO,"Gastro_Visits.txt") or die "Cannot open Gastro_Visits.txt files" ;
my $gastro_count=0;
while (<GASTRO>) {
	chomp ;
	my @lines = split  "\t" ;
	$gastro_count++;
	my $id = $lines[0];
	my $gastro_date = $lines[1];
	my $gastro_date_n = get_days($lines[1]);
	
	push @{$gastro->{$id}} ,$gastro_date_n;
}
close (GASTRO) ;
print "read gastro visit $gastro_count.....\n";


# Read Birth-Years
my %byear ;
open (BY,"W:/CancerData/AncillaryFiles/Byears") or die "Cannot open Byears files" ;
my $byear_count=0;
while (<BY>) {
	chomp ;
	my ($id,$year) = split ;
	$byear{$id} = $year ;
	$byear_count++;
}
close (BY) ;
print "read Byears $byear_count \n";

# Read Birth-Years
my %demog_gender ;
open (DEMOG,"W:/CancerData/AncillaryFiles/Demographics") or die "Cannot open Byears files" ;
my $demog_count=0;
while (<DEMOG>) {
	chomp ;
	my ($id,$year,$gender) = split ;
	$demog_gender{$id} =$gender  ;
	$demog_count++;
	#print join("\t", $id,$year,$gender)."\n";
}
close (DEMOG) ;
print "read demog $demog_count \n";

my $reg;
my $reg_all_days;
my $reg_all_real_days;
my $reg_all_type;
my $reg_all_crc;
my $reg_all_stage;
my %reg_stage_lkp;
$reg_stage_lkp{0}=1;
$reg_stage_lkp{1}=1;
$reg_stage_lkp{2}=2;
$reg_stage_lkp{3}=2;
$reg_stage_lkp{4}=2;
$reg_stage_lkp{5}=2;
$reg_stage_lkp{7}=3;
$reg_stage_lkp{9}=9;

my @stage_groups = (1,2,3,9);



open (REG,"W:/CancerData/AncillaryFiles/Registry") or die "Cannot open Registry files" ;
my $first=0;
while (<REG>) {
	chomp ;
	my @lines = split "\t";
	my $id = $lines[0];
	my $reg_day = $lines[1];
	my $reg_type = $lines[2];
	my $reg_stage = $lines[3];
	
	#print join ("\t", $id , $reg_day , $reg_type  , $reg_stage)."\n";
	#<STDIN>;
	
	if ($first==0) {
		$first=1;
		next;
	}
	
	my $crc_flag=0;
	if (($reg_type eq "Digestive Organs,Digestive Organs,Colon") or ($reg_type eq "Digestive Organs,Digestive Organs,Rectum")) {
		$crc_flag =1;
	}
	
	#if (!exists $reg->{$id} or (exists $reg->{$id} and get_days($reg_day) < $reg->{$id}->{days}   )  ) {
		$reg->{$id} = 1;
		#$reg->{$id}->{days} = get_days($reg_day);
		#$reg->{$id}->{real_days} = $reg_day;
		#$reg->{$id}->{type} =  $reg_type;
		#$reg->{$id}->{crc} =  $crc_flag;
		
		push @{$reg_all_days->{$id}} , get_days($reg_day);
		push @{$reg_all_real_days->{$id}} , $reg_day;
		push @{$reg_all_type->{$id}} , $reg_type;
		push @{$reg_all_crc->{$id}} , $crc_flag;
		push @{$reg_all_stage->{$id}} ,$reg_stage_lkp{$reg_stage};
	#}
}
close (REG) ;
print "read reg \n";


#open (PRED,"W:/Users/Ami/CRC/DMRF_JAN_2015/Full_Cycle_09FEB2015/CheckMSCRC/LearnPredict_predictions.combined") or die "Cannot open learn-predict files" ;  
open (PRED,"W:/Users/Ami/CRC/Test_DMRF_on_MHS_OCT2014/LearnPredict_predictions.combined") or die "Cannot open learn-predict files" ;  
#open (PRED , "LearnPredict_predictions_short.combined");
# Read Predictions
my @orig_preds ;
my %all_ids;
print STDERR "Reading predictions..." ;



my $simulation_dates;
my $simulation_dates_n;
my $simulation_dates_x;
my $head = 1;
my $pred_counter=0;
my $pred_relevant=0;
my %day_count;
while (<PRED>) {
	if ($head == 1) {
		$head = 0 ;
		next ;
	}
	chomp ;
	my ($id,$date,$score) = split ;
	my $age = int($date/10000) - $byear{$id} ;
	
	
	if ($age >= $min_age and $age <= $max_age and $date>=$simulation_start   and $date<$simulation_end  )  {
		push @orig_preds,{id => $id, score=>$score,days=>get_days($date) , orig_day=>$date  }  ;
		$simulation_dates_n->{$date} = get_days($date);
		
		my $date_n = get_days($date);
		$simulation_dates_x->{$date_n} = $date;
		
		$all_ids{$id}=1;
		$pred_relevant++;
		$day_count{$date}++;
	}
	$pred_counter++;
}
close IN ;
print STDERR "read learn prdict Done  $pred_counter   $pred_relevant \n" ;

my $temp_sum_day=0;
my $temp_count_day=0;
for my $ii (keys %day_count) {
	$temp_count_day++;
	$temp_sum_day+=$day_count{$ii};
}
my $temp_avg_day=$temp_sum_day/$temp_count_day;
print "day avg = $temp_avg_day";
my $temp_avg_day_10p = $temp_avg_day/10;
print "day avg = $temp_avg_day  $temp_avg_day_10p \n";

my $n_all_ids = scalar (keys %all_ids);


my @preds = sort {$a->{days} <=> $b->{days}} @orig_preds ;
my $npreds = scalar(@preds) ;


my $compute_score=0;

#map between score and spec .....
my %map_score_spec;
if ($compute_score==1)     {
			my @scores;	
			push @scores, (map {65 + $_/100} (1..3500));
			#push @scores, (map {75 + $_/100} (1..2500)) ;
			
			open (SCORE_LKP,">score_pr_last.txt") or die "Cannot open Registry files" ;
			open (COLLECT_SCORE,">collect_score.txt") or die "Cannot open Registry files" ;

			my @bound_ratio;

			for my $temp_score (@scores) {

				my $count_ratio=0;
				my $count_ratio_n=0;
				my $prev_days  = $preds[0]->{days};
				my $prev_real_days = $preds[0]->{orig_day};
				my $count_id=0;
				my $count_bound=0;
				my $count_day=0;
				my %id_in;
				
				for my $ii (0..($npreds/4) ) {
				
				  my $temp_id = $preds[$ii]->{id};
				  my $temp_id_score = $preds[$ii]->{score};
				  my $temp_days = $preds[$ii]->{days};
				  my $real_days  = $preds[$ii]->{orig_day};	  
				  
				  
				  if ($prev_days ne $temp_days and $count_day>$temp_avg_day_10p)  {
					my $temp_ratio = $count_bound/$count_id;
					$count_ratio += $temp_ratio;
					$count_ratio_n++;
					#print COLLECT_SCORE join("\t" ,$temp_score ,  $prev_real_days  ,$count_bound ,$count_id ,   $temp_ratio)."\n";			
					$count_id=0;
					$count_bound=0;
					#foreach my $my_key (keys %id_in) {
						#delete $id_in{$my_key};
					#}		
				  }

				  if ($prev_days ne $temp_days) {
				     $count_day=0;
				  } else  {
				     $count_day++;
				  }

				  
				  if (!exists $id_in{$temp_id})  {
					if ($temp_id_score > $temp_score) {
					   $id_in{$temp_id}=1;
					   $count_bound++;
					   $count_id++;
					} else {
					   $count_id++;	
					}
				   }
				   
				   $prev_days  = $preds[$ii]->{days};
				   $prev_real_days = $preds[$ii]->{orig_day};
				}
				
				$count_ratio/=$count_ratio_n;
				print SCORE_LKP join("\t" , $temp_score , $count_ratio)."\n";
				$map_score_spec{$temp_score} = $count_ratio;
				print join("\t" , $temp_score , $count_ratio)."\n";
				
				#clean

				$count_id=0;
				$count_bound=0;
				#last;
			}
			close(COLLECT_SCORE);
			close(SCORE_LKP);
}  else {

			open (SCORE_LKP,"score_pr_09072015.txt") or die "Cannot open Registry files" ;
			while (<SCORE_LKP>) {
				chomp ;
				my @lines = split  "\t" ;
				my $temp_score = $lines[0];
				my $temp_spec = $lines[1];
				$map_score_spec{$temp_score} = $temp_spec;
			}
			close(SCORE_LKP);
}


#exit;


print "=========================\n";
my $find_Score;

#$find_Score = repalce_spec_with_score (90 , \%map_score_spec);
#$find_Score = repalce_spec_with_score (95 , \%map_score_spec);
#$find_Score = repalce_spec_with_score (97 , \%map_score_spec);
#$find_Score = repalce_spec_with_score (99 , \%map_score_spec);
#find_Score = repalce_spec_with_score (99.5 , \%map_score_spec);


#exit;


#my $end_days = get_days(20140101) ;



my $end_days = get_days($simulation_end) ;
my $start_days = get_days($simulation_start) ;
my $n_month = 36;

print "simulation from  $simulation_start  to $simulation_end \n";

my $simulation_gap = "daily";
print "simulation period gap : $simulation_gap \n";


my $start_year = 2009;
my $start_month = 1;

my @sim_months;
my @sim_months_n;

my $temp_month=$start_month;
my $temp_year=$start_year;


#exit;

if ($simulation_gap eq "monthly") {
	for my $i (0..$n_month) {
		my $mm;
		if ($temp_month<10) {
			$mm = "0".$temp_month;
		} else {
			$mm = $temp_month;
		}
		my $temp_date = $temp_year.$mm."01";
		push @sim_months , $temp_date;
		push @sim_months_n , get_days($temp_date);
		print $i." ".$temp_date."\n";

		if ($temp_month==12) {
			$temp_month=1;
			$temp_year++;
		} else {
			$temp_month++;
		}
	}
}




# Scores of interest
#my @scores = (30..90) ;
#push @scores, (map {90 + $_/2} (1..15)) ;
#push @scores, (map {97.5 + $_/10} (1..25)) ;

#@scores = (99.6);


my %hash_replace_score;
$hash_replace_score{ repalce_spec_with_score (99.5 , \%map_score_spec)  } = 99.5;
$hash_replace_score{ repalce_spec_with_score (99 , \%map_score_spec)  } = 99;
$hash_replace_score{ repalce_spec_with_score (97 , \%map_score_spec)  } = 97;
$hash_replace_score{ repalce_spec_with_score (95 , \%map_score_spec)  } = 95;
$hash_replace_score{ repalce_spec_with_score (90 , \%map_score_spec)  } = 90;

$hash_replace_score{65} = 90;

my @scores = ( 
		   #[repalce_spec_with_score (99.5 , \%map_score_spec) , 101] ,
	       #[repalce_spec_with_score (99,    \%map_score_spec) , 101],
	       #[repalce_spec_with_score (97 ,   \%map_score_spec) , 101] , 
	       [repalce_spec_with_score (95 ,   \%map_score_spec) , 101], 
	       #[repalce_spec_with_score (90 ,   \%map_score_spec) , 101]  
	       );

#, [99.2, 99.6]



open (SUMMARY , ">summary_simulation.txt");
open (SUMMARY_TYPE , ">summary_cancer_type.txt");
open (OUT , ">detailed_simulation.txt");
open (SUMMARY_STAGE , ">summary_cancer_stage.txt");

print OUT join("\t" , "gender", "score", "counter","qa" , "total","bound"  ,"colon_fecal_gastro" )."\t";
print OUT join("\t" , "colon", "fecal", "pos"  , "pos%", "in_reg")."\t";
print OUT join("\t" , "in_crc", "in_crc%", "in_crc_90", "in_crc_90_180", "in_crc_180_360", "in_crc_360_730","mean_age", "period")."\n";



print SUMMARY $simulation_start."\t".$simulation_end."\n";
print SUMMARY_TYPE $simulation_start."\t".$simulation_end."\n";



print SUMMARY join ("\t","score" , "score_from" , "score_to","gender","param_type",  "param", "avg", "sdv" , "CI(95%)-minus" , "CI(95%)-plus","month" )."\n";
print SUMMARY_TYPE join ("\t","spec", "score_from", "score_to", "gender", "cancer_type", "count" , "% from pos" , "win_0_90" ,"win_90_180", "win_180_360", "win_360_540", "win_540_720", "win_720_900", "win_900_1080" )."\n";

#my @genders = ("F", "M" ,"COMBINED");
my @genders = ("COMBINED");
for my $gender (@genders) {
					#print OUT "gender\n";
					print "******* gender : $gender ******* \n";
				foreach my $bound_lims (@scores) {
					my $bound = $bound_lims->[0];
					#print $bound_lims->[0]."\n";
					#rint $bound_lims->[1];
					
					print STDERR "Testing $bound" ;
					print "**** $bound ***** \n";
					
					my $pred_idx = 0 ;
					my %done_ids ;
					my $idx = 1 ;
					my %cancer_types;
					my %cancer_stages;
					my $cancer_stage_all=0;
					my @bounds;
					my @qas;
					my @totals;
					my @ratios ;
					my @poss;
					my @periods;
					my @in_reg;
					my @in_reg_crc;
					my @in_reg_crc_90_ratio;
					my @in_reg_crc_90_180_ratio;
					my @in_reg_crc_180_360_ratio;
					my @in_reg_crc_360_540_ratio;
					my @in_reg_crc_540_720_ratio;
					my @in_reg_crc_720_900_ratio;
					my @in_reg_crc_900_1080_ratio;
					my @in_reg_crc_ratio;
					my @bound_colon;
					my @bound_gastro;
					my @bound_reg_before;
					my @bound_fecal;
					my @bound_colon_fecal;
					my @bound_colon_appoint;
					my @mean_age;
					
					my $my_max_gap=-9;
					my $my_max_gap_id;
					my $first_sim_date=1;
					
					my %counts ;
					my %counts_stage;
					my %count_qa_hash;					
					
					# Loop on days
					my $count_sim_date=0;
					for my $sim_date (sort keys %{$simulation_dates_n} ) {
						
						my $day=$simulation_dates_n->{$sim_date};
						my $next_day = $simulation_dates_n->{$sim_date}+1;
						my $temp_day = $sim_date;
						my $temp_next_day = $simulation_dates_x->{$next_day};
					
						$pred_idx ++  while ($pred_idx < $npreds and $preds[$pred_idx]->{days} < $day) ;
						last if ($pred_idx == $npreds) ;
						
						#print join ("\t", $temp_day , $count_sim_date)."\n";
						#<STDIN>;
						
						if ($count_sim_date>$temp_avg_day_10p or $first_sim_date==1) {
							$first_sim_date=0;
							#print "i am here ..... \n";
							#<STDIN>;
							
							foreach my $my_key (keys %counts) {
								delete $counts{$my_key};
							}

							foreach my $my_key (keys %counts_stage) {
								delete $counts_stage{$my_key};
							}

							foreach my $my_key (keys %count_qa_hash) {
								delete $count_qa_hash{$my_key};
							}							
							
							$counts{gastro}=0;
							$counts{reg_before}=0;
							$counts{tot}=0;
							$counts{qa}=0;
							$counts{fecal}=0;
							$counts{colon_fecal}=0;
							$counts{colon} = 0;
							$counts{colon_appoint} = 0;
							$counts{pos} = 0;
							$counts{reg}=0;
							$counts{crc}=0;
							$counts{bound}=0;
							$counts{colon_fecal}=0;
							$counts{win_90}=0;
							$counts{win_90_180}=0;
							$counts{win_180_360}=0;
							$counts{win_360_540}=0;
							$counts{win_540_720}=0;
							$counts{win_720_900}=0;
							$counts{win_900_1080}=0;
						}
						$count_sim_date=0;
					
						my %curr_id;
						
						# Scores within day in question
						while ($pred_idx < $npreds and $preds[$pred_idx]->{days} < $next_day  ) {
							my $rec = $preds[$pred_idx]  ;
							my $id = $rec->{id};
							#print $id."\t".$rec->{score}."\t".$rec->{orig_day}."\n";
							#<STDIN>;
							
							
								$pred_idx ++ ;
								next if ($demog_gender{$id} ne $gender and $gender ne "COMBINED");
								
								my $find_reg_before_3y=0;
								my $next_reg=0;
								my $next_reg_type;
								my $next_reg_crc;
								my $next_reg_gap;
								my $next_reg_real;
								my $next_reg_stage;
								
								
								
								if (exists $reg->{$id})  {
										my @reg_id = @{$reg_all_days->{$id}};
										#in reg period
										for my $ii (0..$#reg_id) {
											#my $gap = $rec->{days} - $reg_id[$ii];
											my $gap = $next_day - $reg_id[$ii];
											if ($gap>0 and $gap<365*3) {
												$find_reg_before_3y=1;
												last;
											}
										}

										
										my $next_reg_i;
										for my $ii (0..$#reg_id) {
											my $gap = $reg_id[$ii] - $next_day;
											if ($gap>0 and $gap<1080) {
											#if ($gap>0 and $gap<365*1.5) {
											
												#if ($rec->{score}>99.6 and $gap>360 and $find_reg_before_3y=0) {
													#print $id."\t".$gap."\t".$rec->{score};
													#<STDIN>;
												#}
											
												if ($next_reg==0) {
													$next_reg=1;
													$next_reg_gap = $gap;
													$next_reg_i = $ii;
												} elsif ($gap<$next_reg_gap)  {
													$next_reg_gap = $gap;
													$next_reg_i = $ii;														
													#print $id."\t".$next_reg_gap."\t".$rec->{score};
													#<STDIN>;													
												}
											}
										}
										
										#if ($id==743540 or $id==216671) {
											#print $id."\t".$next_reg_gap."\n";
											#<STDIN>;
										#}
										
										
										if ($next_reg==1) {
											my @crc = @{$reg_all_crc->{$id}};
											my @type = @{$reg_all_type->{$id}};
											my @real_days = @{$reg_all_real_days->{$id}};
											my @stage = @{$reg_all_stage->{$id}};
											
											$next_reg_type = $type[$next_reg_i];
											$next_reg_crc = $crc[$next_reg_i];
											$next_reg_real = $real_days[$next_reg_i];
											$next_reg_stage = $stage[$next_reg_i];
											#print "my sage ".$next_reg_stage."\n";
											#<STDIN>;
											
											#print $id."\t".$next_reg_real."\t".$rec->{orig_day}."\n";
										}
										
								}
								$count_qa_hash{$id}=1;;
								
								# Id was not sent to colonoscopy already
								#if (! exists $done_ids{$id}  and  (!exists $reg->{$id}  or (exists $reg->{$id} and ($reg->{$id}->{days} > $rec->{days} ))   )) {
								#if (! exists $done_ids{$id}  and  (!exists $reg->{$id}  or (exists $reg->{$id} and $find_reg_before_3y==0 ))   ) {
								
								if (! exists $done_ids{$id}) {
								#if (1==1) {
								
								$curr_id{$id}=1;
								$counts{tot} ++ ;
								$count_sim_date++;
								$counts{age} +=  (( $next_day - get_days($byear{$id}."0101"))/365);
									
								if ($rec->{score} >= $bound_lims->[0] and $rec->{score} < $bound_lims->[1] ) {
											
											$counts{bound} ++ ;
											
											
											my $find_colon=0;
											for my $colon_date (@{$colons->{$id}}) {
												#my $diff = $rec->{days}- $colon_date;
												my $diff = $next_day- $colon_date;
												if ($diff>-1 and $diff<365*10)  {
													$find_colon=1;
													last;
												}
											}
											
											my $find_fecal=0;
											for my $fecal_date (@{$fecal->{$id}}) {
												my $diff = $next_day - $fecal_date;
												#my $diff = $rec->{days}- $fecal_date;
												if ($diff>0 and $diff<365*1.5)  {
													$find_fecal=1;
													last;
												}
											}		

											my $find_gastro=0;
											for my $gastro_date (@{$gastro->{$id}}) {
												my $diff = $next_day - $gastro_date;
												if ($diff>0 and $diff<92)  {
													$find_gastro=1;
													last;
												}
											}

											my $find_colon_appoint=0;
											for my $colon_appoint_date (@{$colon_appoint->{$id}}) {
												my $diff = $next_day - $colon_appoint_date;
												if ($diff>0 and $diff<92)  {
													$find_colon_appoint=1;
													last;
												}
											}
											
											
											
											$counts{reg_before}+=$find_reg_before_3y;
											$counts{gastro}+= $find_gastro;
											$counts{fecal} += $find_fecal ;
											$counts{colon} += $find_colon ;
											$counts{colon_appoint} += $find_colon_appoint;
											
											#if ($id==743540 or $id==216671) {
												#print join ("\t", $id , $find_fecal , $find_colon , $find_gastro , $find_colon_appoint , $find_reg_before_3y)."\n";
												#<STDIN>;
											#}
											
											
											if (($find_fecal+$find_colon+$find_gastro+$find_colon_appoint+$find_reg_before_3y)==0) {
												
												if ($next_reg_gap>$my_max_gap) {
													$my_max_gap = $next_reg_gap;
													$my_max_gap_id = $id;
												}
												
												
												$counts{pos} ++ ;
												$done_ids{$id} = 1 ;
												
												if ($next_reg==1) {  
													$counts{reg} ++;
													$counts{crc}+=$next_reg_crc;
													$cancer_types{$next_reg_type}{all}++;
													
													#if ($id==1906628) {
														#print $id."\t".$next_reg_gap."\t".$next_reg_crc."\n";
														#<STDIN>;
													#}													
													
													if ($next_reg_gap<=90) {
														$cancer_types{$next_reg_type}{90}++;
														$counts{win_90}+=$next_reg_crc
													} elsif ($next_reg_gap<=180) {
														$cancer_types{$next_reg_type}{180}++;
														$counts{win_90_180}+=$next_reg_crc
													} elsif ($next_reg_gap<=360) {
														$cancer_types{$next_reg_type}{360}++;
														$counts{win_180_360}+=$next_reg_crc
													}  elsif ($next_reg_gap<=(540)  ) {
														$cancer_types{$next_reg_type}{540}++;
														$counts{win_360_540}+=$next_reg_crc
													} elsif ($next_reg_gap<=(720)  ) {
														$cancer_types{$next_reg_type}{720}++;
														$counts{win_540_720}+=$next_reg_crc
													} elsif ($next_reg_gap<=(900)  ) {
														$cancer_types{$next_reg_type}{900}++;
														$counts{win_720_900}+=$next_reg_crc
													}elsif ($next_reg_gap<=(1080)  ) {
														$cancer_types{$next_reg_type}{1080}++;
														$counts{win_900_1080}+=$next_reg_crc;
													}
													
													if ($next_reg_crc==1) {
														$cancer_stage_all++;
														my $temp_gap = $next_reg_gap/90;
														my $temp_gap1 = int($temp_gap)+1;
														$temp_gap1 = $temp_gap1 * 90;
														
														$cancer_stages{$temp_gap1}{$next_reg_stage}++;
														$cancer_stages{$temp_gap1}{all}++;														
														

													}
													
													
												}
											} else {
												$counts{colon_fecal}++;
											}
									}
								}
						}

							if ($count_sim_date>$temp_avg_day_10p) {
						

								$counts{qa} = scalar (keys %count_qa_hash);
								foreach my $my_key (keys %count_qa_hash) {
									delete $count_qa_hash{$my_key};
								}
								
								if ($counts{crc}>0) {
									push @in_reg_crc_90_ratio,$counts{win_90}/$counts{crc};
									push @in_reg_crc_90_180_ratio,$counts{win_90_180}/$counts{crc};
									push @in_reg_crc_180_360_ratio,$counts{win_180_360}/$counts{crc};
									push @in_reg_crc_360_540_ratio,$counts{win_360_540}/$counts{crc};									
									push @in_reg_crc_540_720_ratio,$counts{win_540_720}/$counts{crc};									
									push @in_reg_crc_720_900_ratio,$counts{win_720_900}/$counts{crc};									
									push @in_reg_crc_900_1080_ratio,$counts{win_900_1080}/$counts{crc};	
								}
						
								push @qas ,  $counts{qa};
								push @bounds , $counts{bound};
								push @totals , $counts{tot};
								push @ratios,$counts{pos}/$counts{tot} ;
								push @poss , $counts{pos};
								push @periods , $temp_day;
								push @in_reg , $counts{reg};
								push @in_reg_crc , $counts{crc};
								if ($counts{pos}>0) {
									push @in_reg_crc_ratio , $counts{crc}/$counts{pos};
								}
								push @bound_colon , $counts{colon};
								push @bound_fecal , $counts{fecal};
								push @bound_colon_appoint , $counts{colon_appoint};
								push @bound_colon_fecal , $counts{colon_fecal};
								push @bound_gastro , $counts{gastro};
								push @bound_reg_before , $counts{reg_before};
								push @mean_age ,$counts{age} /$counts{tot};
								$idx ++ ;
							}
					}
					
					#print "===============".$my_max_gap."\t".$my_max_gap_id."\n";
					#<STDIN>;
					#rint $idx."\n";

					
					print STDERR "\r" ;
					
					my $smooth_totals = smooth(\@totals) ;
					my $smooth_ratio = smooth(\@ratios) ;
					my $smooth_pos = smooth(\@poss) ;
					my $smooth_reg = smooth(\@in_reg) ;
					my $smooth_reg_crc = smooth(\@in_reg_crc) ;
					my $smooth_reg_crc_ratio =  smooth(\@in_reg_crc_ratio) ;
					my $smooth_colon = smooth(\@bound_colon) ;
					my $smooth_fecal = smooth(\@bound_fecal) ;
					my $smooth_bound = smooth(\@bounds);
					my $smooth_colon_fecal = smooth(\@bound_colon_fecal);
					
					map {print "$bound\t$_\t$ratios[$_]\t".($smooth_ratio->[$_])."\t"."$poss[$_]\t".($smooth_pos->[$_])."\n"} (0..$#ratios) ;
					
					my $total_sum=0;
					my $pos_sum=0;
					my $in_reg_crc_sum=0;
					my $count=0;
					
					for my $i (0..$#ratios) {
						print OUT $gender."\t";
						print OUT $bound."\t";
						print OUT $hash_replace_score{$bound}."\t";
						print OUT $i."\t";
						print OUT $qas[$i]."\t";
						print OUT $totals[$i]."\t";
						print OUT $bounds[$i]."\t";
						print OUT $bound_colon_fecal[$i]."\t";
						print OUT $bound_colon[$i]."\t";
						print OUT $bound_fecal[$i]."\t";
						print OUT $bound_colon_appoint[$i]."\t";
						print OUT $poss[$i]."\t";
						print OUT $ratios[$i]."\t";
						print OUT $in_reg[$i]."\t";
						print OUT $in_reg_crc[$i]."\t";
						print OUT $in_reg_crc_ratio[$i]."\t";
						print OUT $in_reg_crc_90_ratio[$i]."\t";
						print OUT $in_reg_crc_90_180_ratio[$i]."\t";
						print OUT $in_reg_crc_180_360_ratio[$i]."\t";
						print OUT $in_reg_crc_360_540_ratio[$i]."\t";				
						print OUT $mean_age[$i]."\t";
						print OUT $periods[$i]."\n";
						
						$count++;
						$total_sum+=$totals[$i];
						$pos_sum+=$poss[$i];
						$in_reg_crc_sum+=$in_reg_crc[$i];
					}


					print SUMMARY_TYPE $hash_replace_score{$bound_lims->[0]}."\t".$bound_lims->[0]."\t".$bound_lims->[1]."\t".$gender."\t"."total_pos"."\t".$pos_sum."\n";
					for my $ii ( sort { $cancer_types{$b}{all} <=> $cancer_types{$a}{all} }  keys %cancer_types ) {
					
					
						print SUMMARY_TYPE $hash_replace_score{$bound_lims->[0]}."\t".$bound_lims->[0]."\t".$bound_lims->[1]."\t".$gender."\t".$ii."\t".$cancer_types{$ii}{all}."\t".$cancer_types{$ii}{all}/$pos_sum."\t";
						if ($cancer_types{$ii}{all}>0) {
							print SUMMARY_TYPE $cancer_types{$ii}{90}/$cancer_types{$ii}{all}."\t";
							print SUMMARY_TYPE $cancer_types{$ii}{180}/$cancer_types{$ii}{all}."\t";
							print SUMMARY_TYPE $cancer_types{$ii}{360}/$cancer_types{$ii}{all}."\t";
							print SUMMARY_TYPE $cancer_types{$ii}{540}/$cancer_types{$ii}{all}."\t";
							print SUMMARY_TYPE $cancer_types{$ii}{720}/$cancer_types{$ii}{all}."\t";
							print SUMMARY_TYPE $cancer_types{$ii}{900}/$cancer_types{$ii}{all}."\t";
							print SUMMARY_TYPE $cancer_types{$ii}{1080}/$cancer_types{$ii}{all};
						} 
						print SUMMARY_TYPE "\n";
					}	

					my $ppv = $cancer_stage_all/$pos_sum;
					print SUMMARY_STAGE "gender"."\t".$gender."\n";
					print SUMMARY_STAGE "pos"."\t".$pos_sum."\n";
					print SUMMARY_STAGE "crc"."\t".$cancer_stage_all."\n";
					print SUMMARY_STAGE "ppv"."\t".$ppv."\n";
					print SUMMARY_STAGE "spec"."\t".$hash_replace_score{$bound_lims->[0]}."\n";
					print SUMMARY_STAGE "score_from"."\t".$bound_lims->[0]."\n";
					print SUMMARY_STAGE "score_to"."\t".$bound_lims->[1]."\n";
					print SUMMARY_STAGE "win"."\t";
					for my $temp_stage (sort @stage_groups) {
						print SUMMARY_STAGE "stage_".$temp_stage."\t";
					}
					print SUMMARY_STAGE "all"."\t";
					#for my $temp_stage (sort @stage_groups) {
						#print SUMMARY_STAGE "stage_".$temp_stage."\t";
					#}
					print SUMMARY_STAGE "\n";
					
					my @stage_wins;
					push @stage_wins, (map {90*$_} (1..12));
					
					
					#for my $temp_win ( sort { $a <=> $b } keys %cancer_stages ) {
					for my $temp_win (@stage_wins) {
						print SUMMARY_STAGE $temp_win."\t";
						for my $temp_stage (sort @stage_groups) {
							my $temp_val = $cancer_stages{$temp_win}{$temp_stage}+0;
							print SUMMARY_STAGE $temp_val."\t";
						}
						print SUMMARY_STAGE ($cancer_stages{$temp_win}{all}+0)."\t";
						
						#for my $temp_stage (sort @stage_groups) {
							#next if ($temp_stage==9);
							#print SUMMARY_STAGE $cancer_stages{$temp_win}{$temp_stage}/$cancer_stages{$temp_win}{all}."\t";
						#}					
						print SUMMARY_STAGE "\n";
					}
					print SUMMARY_STAGE "\n";
					
					
					
					
					$total_sum/=$count;
					$pos_sum/=$count;
					$in_reg_crc_sum/=$count;
					
				
					my $stats;
					
					
					$stats = get_stats(\@qas,\@periods,1) ;   print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]} , $bound_lims->[0] , $bound_lims->[1], $gender ,"count", "blood - id with blood" , $stats->[0], $stats->[1], $stats->[2], $stats->[3] ,$stats->[4],$stats->[5] )."\n";				
					$stats = get_stats(\@totals,\@periods,1) ; 	print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1], $gender ,"count", "total - with blood (no pos before)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4] ,$stats->[5])."\n";
					$stats = get_stats(\@bounds,\@periods,1) ; 	print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender ,"count",  "bound - pass score $bound" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					$stats = get_stats(\@bound_colon_fecal,\@periods,1) ; print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender ,"count",  "filter by (colonscopy,fecal,gastro,colon appoint)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					$stats = get_stats(\@bound_colon,\@periods,1) ; print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender ,"count" , "filter by colon" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					$stats = get_stats(\@bound_fecal,\@periods,1) ; print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender ,"count", "filter by fecal" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					$stats = get_stats(\@bound_gastro,\@periods,1) ; print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender,"count" , "filter by gastro" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					$stats = get_stats(\@bound_colon_appoint,\@periods,1) ; print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender,"count" , "filter by colon appoint" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					$stats = get_stats(\@bound_reg_before,\@periods,1) ; print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender,"count" , "filter by reg before 3y" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					
					$stats = get_stats(\@poss,\@periods,1) ;  print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender,"count" , "pos - pass score and all filters" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5] )."\n";
					$stats = get_stats(\@ratios,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%pos (pos/total)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					$stats = get_stats(\@in_reg,\@periods,1) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "count", "reg - in_reg" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5])."\n";
					$stats = get_stats(\@in_reg_crc,\@periods,1) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "count",  "crc - in_reg_crc" , $stats->[0], $stats->[1], $stats->[2], $stats->[3],$stats->[4],$stats->[5] )."\n";
					$stats = get_stats(\@in_reg_crc_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender,  "%", "%crc -  (crc/pos)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					
					$stats = get_stats(\@in_reg_crc_90_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%crc_win_1_90 -  (crc_1_90/crc)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					$stats = get_stats(\@in_reg_crc_90_180_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%crc win 90d-180d -  (crc_90_180/crc)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					$stats = get_stats(\@in_reg_crc_180_360_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%crc win 0.5y-1y -  (crc_0.5y-1y/crc)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					$stats = get_stats(\@in_reg_crc_360_540_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%crc win 1y-1.5y -  (crc_1y-1.5y/crc)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					$stats = get_stats(\@in_reg_crc_540_720_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%crc win 1.5y-2y -  (crc_1.5y-2y/crc)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					$stats = get_stats(\@in_reg_crc_720_900_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%crc win 2y-2.5y -  (crc_2y-2.5y/crc)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";
					$stats = get_stats(\@in_reg_crc_900_1080_ratio,0,0) ;print SUMMARY join ("\t",$hash_replace_score{$bound_lims->[0]},$bound_lims->[0] , $bound_lims->[1],$gender , "%", "%crc win 2.5y-3y -  (crc_2.5y-3y/crc)" , $stats->[0], $stats->[1], $stats->[2], $stats->[3])."\n";

					# Max of 2nd divergance
					my @smooth = @$smooth_ratio ;
					my @div1 = map {$smooth[$_] - $smooth[$_-1]} (1..$#smooth) ;
					my @div2 = map {$div1[$_] - $div1[$_-1]} (1..$#div1) ;
					
					my $maxi = 0 ;
					map {$maxi = $_ if ($div2[$_] > $div2[$maxi])} (1..$#div2) ;
					
					my $nnext = 5 ;
					my $pr ;
					map {$pr += $smooth[$_]} ($maxi..$maxi+$nnext-1) ;
					$pr /= $nnext ;
					
					print "$bound $pr\n" ;
				}
}
close(SUMMARY);
close(SUMMARY_TYPE);
close(OUT);
close(SUMMARY_STAGE);
print STDERR "\n" ;


sub get_stats {
	my ($temp_vec , $period_vec , $period_flag) = @_;
	
	my $n = scalar @$temp_vec ;
	my ($avg,$sdv,$sdv_avg,$ci_minus,$ci_plus);
	

	if ($n==0) {
	   $avg=-1;
	   $sdv=-1;
	   $ci_minus=-1;
	   $ci_plus=-1;
	   goto out;
	}
			
	
	my @stats;
	my $avg_period_sum1=0;	
	my $avg_period_sum2=0;	
	if ($period_flag==1) {
		my $avg_period_count=0;
		my $avg_period_temp=0;
		my $prev_month=substr $period_vec->[0] ,4,2;
		my $curr_month;
		for my $i (0..$n-1) {
			my $curr_month = substr $period_vec->[$i] ,4,2;
			if ($curr_month ne $prev_month)  {
				#print join("\t", $period_vec->[$i], $avg_period_temp , $curr_month);
				$avg_period_sum1+=$avg_period_temp;
				$avg_period_count++;
				$avg_period_temp=0;
			}
			$avg_period_temp+=$temp_vec->[$i];
			$prev_month =  $curr_month;
		}
		$avg_period_sum1+=$avg_period_temp;
		$avg_period_count++;		
		
		$avg_period_sum2 = $avg_period_sum1/$avg_period_count;
	}

	$avg=0;
	for my $i (0..$n-1) {
		$avg+= $temp_vec->[$i];
	}
	$avg/=$n;

	
	$sdv=0;
	for my $i (0..$n-1) {
		$sdv+= ($temp_vec->[$i]-$avg)*($temp_vec->[$i]-$avg);
	}	
	$sdv = sqrt($sdv/$n);
	$sdv_avg = $sdv/sqrt($n);
	$ci_minus = $avg - (1.96*$sdv_avg);
	$ci_plus = $avg + (1.96*$sdv_avg);
	
	out:
	
	push @stats , $avg;
	push @stats , $sdv;
	push @stats , $ci_minus;
	push @stats , $ci_plus;
	push @stats , $avg_period_sum2;
	push @stats , $avg_period_sum1;
	
	return \@stats;
	
	
}

##########################################################################################
# Smoothing by linear regression
sub smooth {
	my ($in) = @_ ;
	
	my @out ;
	my $n = scalar @$in ;
	
	my $flank = 10 ;
	my $size = 2*$flank+1 ;
	exit (-1) if ($n<$size) ;
	
	for my $i (0..$n-1) {
		my $start = ($i-$flank < 0) ? 0 : $i-$flank ;
		$start = $n-$size if ($start+$size-1 > $n-1) ;
		
		my $meany = 0 ;
		map {$meany += $in->[$_]} ($start..$start+$size-1) ;
		$meany /= $size ;
		
		my ($sxx,$sxy) = (0,0,0) ;
		for my $j (0..$size-1) {
			$sxx += ($j-$flank)*($j-$flank) ;
			$sxy += ($j-$flank)*($in->[$start+$j] - $meany) ;
		}
	
		my $a = $sxy/$sxx ;
		push @out, ($i-($start+$flank))*$a + $meany ;
	}
	
	return \@out ;
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


sub repalce_spec_with_score {
	my ($spec, $score_to_spec_hash) = @_;
	
	#print "============ $spec \n";
	
	my $spec_p = 1 - ($spec/100);
	my $my_score;
	my $my_spec;
	
	for my $temp_score (sort {$a<=>$b} keys %{$score_to_spec_hash}) {
		my $temp_spec = $score_to_spec_hash->{$temp_score};
	
		#print join ("\t" ,$temp_score ,  $temp_spec , $spec_p);

		if ($score_to_spec_hash->{$temp_score} < $spec_p) {
			$my_score = $temp_score;
			$my_spec = $score_to_spec_hash->{$temp_score};
			last;
		}
	}
	print "$spec  score : $my_score , $my_spec   \n";
	return $my_score;
}



