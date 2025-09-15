#!/cygdrive/w/Applications/Perl64/bin/cygwin_perl
#!/cygdrive/w/Applications/Perl64/bin/cygwin_perl
use strict ;
use Spreadsheet::writeExcel;
use FileHandle ;



my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;


#=================  run params ===================


my $over_limit_script=1;
my $cmd;

#my $run_date = "2008-JAN-01";my $prefix = "create_ref_train";

my $prev_runs;
$prev_runs->{'2015-Oct-08'} = "091135";
$prev_runs->{'2015-Oct-11'} = "103007";
$prev_runs->{'2015-Oct-12'} = "094348";
$prev_runs->{'2015-Oct-13'} = "100442";
$prev_runs->{'2015-Oct-14'} = "092435";
$prev_runs->{'2015-Oct-15'} = "102425";
$prev_runs->{'2015-Oct-18'} = "092831";
$prev_runs->{'2015-Oct-19'} = "094704";
$prev_runs->{'2015-Oct-20'} = "085349";
$prev_runs->{'2015-Oct-21'} = "092835";
$prev_runs->{'2015-Oct-22'} = "095109";
$prev_runs->{'2015-Oct-25'} = "093025";
$prev_runs->{'2015-Oct-26'} = "093255";
$prev_runs->{'2015-Oct-27'} = "085143";
$prev_runs->{'2015-Oct-28'} = "084543";
$prev_runs->{'2015-Oct-29'} = "093144";


#2015-Oct-22.095109


#my $run_date = "2015-Oct-20";my $prefix = "085349";




die "Usage : must enter 'run_date' , 'option_code' which part to run (1-before product / 2-after produxt) " if (@ARGV != 2) ;
my ($run_date ,  $part) = @ARGV ;

if ($part ne "1" and  $part ne "2") {
	print "action should be 1-before running product or 2-after running product ... \n";
	exit;
}



my $in_dir = "P:/Maccabi_Production/";
my $prefix;
opendir (D, $in_dir.$run_date) or die ("cant open directory $in_dir.$run_date  \n");
while (my $f=readdir(D)) {
	
	my $temp_l = length($f);
	next if($temp_l<3);
	my $pre = substr($f , 0,3);
	next if ($pre ne 'MHS');
	$prefix = substr($f , 16,6);
	last;
	
}
closedir(D);

print "prefix : $prefix  \n";



#system (" ls $maccabi_qa_dir   | grep png > ".$maccabi_qa_dir."my_pics.txt ");


#=================  program ===================


my $data_file_name = "MHS.".$run_date.".".$prefix.".Data.txt";
my $scores_file_name = "MHS.".$run_date.".".$prefix.".Scores.txt";
my $demog_file_name = "MHS.".$run_date.".".$prefix.".Demographics.txt";
my $code_file_name = "MHS.".$run_date.".".$prefix.".Codes.txt";

 

my $new_prefix = $prefix."_new";	
my $new_data_file_name = "MHS.".$run_date.".".$new_prefix.".Data.txt";	
my $new_demog_file_name = "MHS.".$run_date.".".$new_prefix.".Demographics.txt";
my $new_code_file_name = "MHS.".$run_date.".".$new_prefix.".Codes.txt";
my $new_scores_file_name = "MHS.".$run_date.".".$new_prefix.".Scores.txt";
 
 

print $data_file_name."\n";
print $scores_file_name."\n";
print $demog_file_name."\n";



my $score_limit = 99;
my $score_limit2 = 99.6;
my $ref_dir = "W:/Users/Barak/maccabi_product_qa/";
my $maccabi_qa_dir = $ref_dir.$run_date."/";
my $maccabi_dir = "D:/maccabi_product_qa/files/";
my $medial_dir = "D:/maccabi_product_qa/files/scores/";




my $orig_prefix = $prefix."_orig";	
my $orig_data_file_name = "MHS.".$run_date.".".$orig_prefix.".Data.txt";	
my $orig_demog_file_name = "MHS.".$run_date.".".$orig_prefix.".Demographics.txt";




 my $param_ref;
$param_ref->{'RBC'} = 5041;
$param_ref->{'WBC'} = 5048;
$param_ref->{'MPV'} = 50221;
$param_ref->{'Hemoglobin'} = 50223;
$param_ref->{'Hematocrit'} = 50224;
$param_ref->{'MCV'} = 50225;
$param_ref->{'MCH'} = 50226;
$param_ref->{'MCHC-M'} = 50227;
$param_ref->{'RDW'} = 50228;
$param_ref->{'Platelets'} = 50229;
$param_ref->{'Neutrophils%'} = 50232;
$param_ref->{'Lymphocytes%'} = 50233;
$param_ref->{'Monocytes%'} = 50234;
$param_ref->{'Eosinophils%'} = 50235;
$param_ref->{'Basophils%'} = 50236;
$param_ref->{'Neutrophils#'} = 50237;
$param_ref->{'Lymphocytes#'} = 50238;
$param_ref->{'Monocytes#'} = 50239;
$param_ref->{'Eosinophils#'} = 50230;
$param_ref->{'Basophils#'} = 50241;


#read demog
my $id_byear;
my $id_gender;




#=================================================================================================================



if ($part==1) {

			$cmd = "cp ".$in_dir.$run_date."/* ".$maccabi_dir;
			run_cmd($cmd);

			$cmd = "mv ".$maccabi_dir.$data_file_name." ".$maccabi_dir.$orig_data_file_name;;
			run_cmd($cmd);
			$cmd = "mv ".$maccabi_dir.$demog_file_name." ".$maccabi_dir.$orig_demog_file_name;
			run_cmd ($cmd);
			$cmd = "sed 's/ //g' ".$maccabi_dir.$orig_data_file_name." > ".$maccabi_dir.$data_file_name;
			run_cmd ($cmd);
			$cmd = "sed 's/ //g' ".$maccabi_dir.$orig_demog_file_name." > ".$maccabi_dir.$demog_file_name;
			run_cmd ($cmd);			
		


			open (DEMOG_MACCABI, $maccabi_dir.$demog_file_name) or die "Cannot open $maccabi_dir.$demog_file_name" ;
			while (<DEMOG_MACCABI>) { 
				chomp;
				my @arr1 = split "\t";
				my $id = $arr1[1];
				my $year = $arr1[2];
				my $gender = $arr1[3];
				$id_byear->{$id} = $year;
				$id_gender->{$id} = $gender;
			}



			my $hash_data;
			open (DATA, $maccabi_dir.$data_file_name);
			while (<DATA>) {
				chomp;
				my @temp_arr = split "\t";
				my $general_code = $temp_arr[0];
				my $id = $temp_arr[1];
				my $blood_code = $temp_arr[2];
				my $param_val = $temp_arr[4];
				my ($year,$month, $day) = split "-", $temp_arr[3];
				my $blood_date = convert_date($temp_arr[3]);
				my $blood_date_n = get_days($blood_date);
				$hash_data->{$id}->{$blood_date}->{$blood_code} = $temp_arr[4];	
			}	

				
			open (OUT_DATA, ">".$maccabi_dir.$new_data_file_name);
			open (OUT_DEMOG, ">".$maccabi_dir.$new_demog_file_name);
				
			for my $temp_id  (keys %{$hash_data} ) {
				my $counter=1;
				for my $temp_date (sort {$b<=>$a} keys %{$hash_data->{$temp_id}}  )   {
					print OUT_DEMOG join ("\t","2", $temp_id."_".$counter,$id_byear->{$temp_id} , $id_gender->{$temp_id} )."\n";
					for my $temp_code (keys %{$hash_data->{$temp_id}->{$temp_date}  }  )   {
						for my $i (1..$counter) {
							my $id_new = $temp_id."_".$i;
							print OUT_DATA join("\t", "2", $id_new ,$temp_code , convert_date_to_words($temp_date) , $hash_data->{$temp_id}->{$temp_date}->{$temp_code} )."\n";
						}
					}
					$counter++;
				}
			}
			close(OUT_DATA);	
			close(OUT_DEMOG);


			my $cmd ="cp ".$maccabi_dir.$code_file_name." ".$maccabi_dir.$new_code_file_name;
			print $cmd."\n";
			system ($cmd);
			exit;
}



if (! -d $ref_dir.$run_date) {
	my $cmd = "mkdir ".$ref_dir.$run_date;
	run_cmd($cmd);
}


open (DEMOG_MACCABI, $maccabi_dir.$demog_file_name) or die "Cannot open $maccabi_dir.$demog_file_name" ;
while (<DEMOG_MACCABI>) { 
	chomp;
	my @arr1 = split "\t";
	my $id = $arr1[1];
	my $year = $arr1[2];
	my $gender = $arr1[3];
	$id_byear->{$id} = $year;
	$id_gender->{$id} = $gender;
}


my $hash_new_score;
if ($over_limit_script==1) {
	open (NEW_SCORE , $medial_dir.$new_scores_file_name) or die "cant open $medial_dir.$new_scores_file_name  \n";
	while (<NEW_SCORE>) {
		chomp ;
		my @arr1 = split "\t";
		if (substr($arr1[0],0,1) ne "*") {
			my $new_id = $arr1[1];
			my $res = index($new_id,"_");
			my $id = substr($new_id, 0, $res);
			my $blood_date = $arr1[2];
			my $temp_blood_date = convert_date($arr1[2]);
			my $score = $arr1[3];
			$hash_new_score->{$id}->{$temp_blood_date}=$score;
		}
	}

}

#goto newmark_analysis;
#goto load_ref;
#goto data_analysis;
#goto compare_to_ref;
#goto data_analysis;
#goto my_find_id;

#============================================   compare scores  SCORE_FILE =======================================

print "step 0\n";

my $outfile = "output1_compare_2_score_files.txt";
my $outfile_summary = "output2_score_file_warnings_errors.txt";

open (OUT, ">".$maccabi_qa_dir.$outfile) or die "cannt open $maccabi_qa_dir.$outfile_summary";
print OUT "maccabi_file"."\t".$maccabi_dir.$scores_file_name."\n";
print OUT "medial_file"."\t".$medial_dir.$scores_file_name."\n";
close(OUT);

open (OUT_SUMMARY, ">".$maccabi_qa_dir.$outfile_summary) or die "cannt open $maccabi_qa_dir.$outfile_summary";

open (IN_MACCABI, $maccabi_dir.$scores_file_name) or die "Cannot open $maccabi_dir.$scores_file_name" ;
open (IN_MEDIAL, $medial_dir.$scores_file_name) or die "Cannot open $medial_dir.$scores_file_name" ;


my $maccabi_fix_name = $maccabi_qa_dir.$scores_file_name.".maccabi.fix1";
my $medial_fix_name = $maccabi_qa_dir.$scores_file_name.".medial.fix1";

open (OUT_MACCABI, ">".$maccabi_fix_name) or die "Cannot open $maccabi_fix_name";
open (OUT_MEDIAL, ">".$medial_fix_name) or die "Cannot open $medial_fix_name";
open (OUT_ERROR, ">".$maccabi_qa_dir."output6_error_file.txt") or die "Cannot open error_file.txt";


my $medial_count=0;
my $maccabi_count=0;
my $error_hash;


#compare 2 score files: the file from maccabi and product run in medial
print "step 1\n";
while (<IN_MACCABI>) { 
	chomp ;
	my @arr1 = split "\t";
	if (substr($arr1[0],0,1) ne "*") {
		print OUT_MACCABI join ("\t" , $arr1[0] , $arr1[1] , $arr1[2] , $arr1[3] , $arr1[5] , $arr1[6])."\n";
		$error_hash->{$arr1[6]}->{$arr1[7]}++;
		$maccabi_count++;
	}
}
close(OUT_MACCABI);

my $ref_hash;
open (REF_FILE, $ref_dir."eldan_ref_file.txt");
while (<REF_FILE>) {
	chomp;
	my @arr = split "\t";
	$ref_hash->{$arr[0]}->{$arr[1]}->{'percent_avg'} = $arr[2];
	$ref_hash->{$arr[0]}->{$arr[1]}->{'percent_sdv'} = $arr[3];
	$ref_hash->{$arr[0]}->{$arr[1]}->{'code'} = $arr[4];
}



while (<IN_MEDIAL>) { 
	chomp ;
	my @arr1 = split "\t";
	$medial_count++;
	if (substr($arr1[0],0,1) ne "*") {
		print OUT_MEDIAL join ("\t" , $arr1[0] , $arr1[1] , $arr1[2] , $arr1[3] , $arr1[5] , $arr1[6])."\n";
	}
}
close(OUT_MEDIAL);

system ("diff \"$maccabi_fix_name\" \"$medial_fix_name\" >> $outfile  ") ;

print "step 2\n";

#warnings and errors of score files
print OUT_SUMMARY "score_file: ".$maccabi_dir.$scores_file_name."\n\n";
print OUT_SUMMARY join ("\t", "type_group", "type", "code", "count", "dist", "ref_dist_avg","ref_dist_sdv" )."\n";
for my $key1 (reverse keys %{$ref_hash}) {
	for my $key2 (keys %{$ref_hash->{$key1}}) {
		
		print OUT_SUMMARY join ("\t", $key1 , $key2 ,  $ref_hash->{$key1}->{$key2}->{'code'})."\t"; 
		
		if (exists ($error_hash->{$key1}->{$key2})) {
			my $temp_count = $error_hash->{$key1}->{$key2};
			my $temp_dist = (int(1000*($temp_count/$maccabi_count)))/10;
			print OUT_SUMMARY join ("\t", $temp_count , $temp_dist)."%\t";			
		} else {
			print OUT_SUMMARY join ("\t", "0" , "0.0%")."\t";			
		}

		print OUT_SUMMARY $ref_hash->{$key1}->{$key2}->{'percent_avg'}."\t";
		print OUT_SUMMARY $ref_hash->{$key1}->{$key2}->{'percent_sdv'}."\n";
	}
}
close(OUT_SUMMARY);


#==================================  compare history  DATA_FILE ===============================


my $outlier_file = "product_outlier.txt";
my $hash_outliers;
open (OUTLIER , $ref_dir.$outlier_file)  or die "cant open file $ref_dir.$outlier_file   \n";
while (<OUTLIER>) {
	chomp;
	my @temp_arr = split;
	my $param_name = $temp_arr[0];
	my $out_min = $temp_arr[1];
	my $out_max = $temp_arr[2];
	$hash_outliers->{$param_name}->{'min'} = $out_min;
	$hash_outliers->{$param_name}->{'max'} = $out_max;
}
close(OUTLIER);
print "step 3\n";



my $prev_ids;
for my $temp_date (keys  %{$prev_runs}) {
	next if ($run_date eq $temp_date);

	my $fname = "MHS.".$temp_date.".".$prev_runs->{$temp_date}.".Scores.txt";
	my $fname1 = $maccabi_dir."/".$fname;
	print $fname1."\n";
	my $counter=0;
	open (IN, $fname1) or die "cant open $fname1 \n";
	while (<IN>) {
		chomp;
		my @arr1 = split "\t";
		next if (substr($arr1[0],0,1) eq "*");
		next if ($arr1[2] eq "");	
		my $temp_id = $arr1[1];		
		$prev_ids->{$temp_id} = $temp_date;
	}
}	



data_analysis:
#read score date for ID
my $id_sore_date;
my $hash_gender;
my $hash_age_bin;
my $hash_gender_age_bin_scores;
my $hash_diff_blood_system;
my $count_scores=0;
my $hash_scores_lim;
my $ids_over_limit;
my $found_id_prev;
open (IN_MACCABI, $maccabi_dir.$scores_file_name) or die "Cannot open $maccabi_dir.$scores_file_name" ;
open (SCORE_OUT , ">".$maccabi_qa_dir."gender_age_score_files.txt") or die "cannot gender_age_score_files.txt";
print OUT_ERROR join ("\t", "error_type" , "id", "previous_date")."\n";
while (<IN_MACCABI>) { 
	chomp ;
	my @arr1 = split "\t";
	
		next if (substr($arr1[0],0,1) eq "*");
		next if ($arr1[2] eq "");
	
		
	
		my $temp_id = $arr1[1];
		
		if (exists ($prev_ids->{$temp_id})) {
			print OUT_ERROR join ("\t", "previous_runs_id" , $temp_id , $prev_ids->{$temp_id})."\n";
			print join ("\t", "id_was_in_previous_runs" , $temp_id,$prev_ids->{$temp_id} )."\n";
		}		
		
		
		my $temp_score = $arr1[3];
		my $temp_system_date = convert_date(substr ($arr1[4], 0 ,11 ));
		my $temp_blood_date = convert_date($arr1[2]);
		my $blood_system_diff = get_days($temp_system_date) - get_days($temp_blood_date);
		$hash_diff_blood_system->{$blood_system_diff}++;
		
		my $score_bin = get_score_bin ($temp_score);
		$hash_scores_lim->{$score_bin}++;
		
		$id_sore_date->{$temp_id}->{'blood_date'} = $temp_blood_date;
		$id_sore_date->{$temp_id}->{'blood_date_n'} = get_days($temp_blood_date);
		$id_sore_date->{$temp_id}->{'id_score_count'}++;
		$id_sore_date->{$temp_id}->{'score'} = $temp_score;
		
		if ($temp_score>=$score_limit) {
			$ids_over_limit->{$temp_id}=$temp_score;
		}
		
		my $temp_gender;
		if (exists $id_gender->{$temp_id} ) {
			$temp_gender = $id_gender->{$temp_id};
			$hash_gender->{$temp_gender}++;
		} else {
			print OUT_ERROR "not in demog file id:".$temp_id."\n";
			print "not in demog file id:".$temp_id."\n";
			#<STDIN>;
		}
		
		my $temp_age;
		my $temp_age_bin;
		if (exists $id_byear->{$temp_id}) {
			$temp_age = substr($temp_blood_date ,0,4) - $id_byear->{$temp_id};
			$temp_age_bin = get_age_bin($temp_age);
			if ( substr($temp_age_bin,0,5) ne "error") {
				push @{$hash_gender_age_bin_scores->{$temp_gender}->{$temp_age_bin}} , $temp_score;
				print SCORE_OUT $temp_gender."\t".$temp_age_bin."\t".$temp_score."\t"."current"."\n";
				$hash_age_bin->{$temp_age_bin}++;	
			} else {
				print OUT_ERROR "wrong age bin id:$temp_id  age:$temp_age  \n";
				print "wrong age bin id:$temp_id  age:$temp_age  \n";
				#<STDIN>;
			}
			
		} else {
			print OUT_ERROR "not in demog  id:$temp_id \n";
			print "not in demog  id:$temp_id \n";
			#<STDIN>;
		}
		$count_scores++;
}
close(SCORE_OUT);
print OUT_ERROR "\n";


#$ids_over_limit->{'27177148'}=85.92;

print "step 4\n";

#history analysis
my $code_hash;
my $year_hash;
my $id_counts;
my $id_gaps;
my $id_ok;
my $count_total=0;
my $id_limit_data;
my $multiple_data;
my $code_hash_limits;
open (DATA, $maccabi_dir.$data_file_name);
print OUT_ERROR join ("\t", "error_type", "id" , "blood_date" , "score" , "param_name", "param_val" , "outlier_val")."\n";
while (<DATA>) {
	chomp;
	my @temp_arr = split "\t";
	my $general_code = $temp_arr[0];
	my $id = $temp_arr[1];
	my $blood_code = $temp_arr[2]." (".convert_code_to_name($temp_arr[2]).")";
	my ($year,$month, $day) = split "-", $temp_arr[3];
	my $blood_date = convert_date($temp_arr[3]);
	my $blood_date_n = get_days($blood_date);

	#next if ($id ne "1443383" and $id ne "219547" and $id ne "2424355" and $id ne "2527654" and $id ne "2631807" and $id ne "2687895" and $id ne "2908669");

	$multiple_data->{$id}->{$blood_date}->{$blood_code}++;
	
	
	$id_counts->{$id}->{$blood_date}=1;
	my $gap = $id_sore_date->{$id}->{'blood_date_n'} - get_days(convert_date($temp_arr[3]));
	my $gap_group = gap_group($gap);
	$id_gaps->{$id}->{$gap_group}=1;
	
	$code_hash->{$blood_code}++;
	
	my $param_name = convert_code_to_name($temp_arr[2]);
	my $param_val = $temp_arr[4];
	
	if ($param_val>$hash_outliers->{$param_name}->{'max'}) {
		$code_hash_limits->{$blood_code}->{'max'}++;
		#print OUT_ERROR "id:$id  date:$blood_date score:".$id_sore_date->{$id}->{'score'}." param:$param_name  val:$param_val  outlier:".$hash_outliers->{$param_name}->{'max'}."\n";
		print OUT_ERROR join ("\t", "outlier", $id , $blood_date , $id_sore_date->{$id}->{'score'} , $param_name , $param_val , $hash_outliers->{$param_name}->{'max'})."\n";
	}
	
	if ($param_val<$hash_outliers->{$param_name}->{'min'}) {
		$code_hash_limits->{$blood_code}->{'min'}++;
		#print OUT_ERROR "id:$id date:$blood_date score:".$id_sore_date->{$id}->{'score'}." param:$param_name  val:$param_val  outlier:".$hash_outliers->{$param_name}->{'min'}."\n";
		print OUT_ERROR join ("\t", "outlier", $id , $blood_date , $id_sore_date->{$id}->{'score'} , $param_name , $param_val , $hash_outliers->{$param_name}->{'min'})."\n";
	}	
	
	
	
	
	if (exists $ids_over_limit->{$id}) {
		$id_limit_data->{$id}->{$blood_date}->{convert_code_to_name($temp_arr[2])} = $temp_arr[4];
	}
	
	$count_total++;
	print $count_total."\n" if ($count_total%1000000==0);	
	
	
}
print OUT_ERROR "\n";

print "count_total : $count_total  \n";
print "step 5\n";


if ($over_limit_script==1) {
			open (MACCABI_MEDIAL , ">".$maccabi_qa_dir."output9_maccabi_to_medial") or die "cant open output9_maccabi_to_medial \n";
			my $hash_maccabi_to_medial;
			for my $temp_id (keys %{$id_limit_data}) {
				for my $temp_date (sort {$b<=>$a} keys %{$id_limit_data->{$temp_id} }) {
					if ($temp_date<20140101) {
						print "look for : ".$temp_id."\t".$temp_date."\n";
						my $hgb_hash;
						my $plat_hash;
						my $wbc_hash;
						my $mpv_hash;
						
						my $hgb_flag=0;
						my $plat_flag=0;
						my $wbc_flag=0;
						my $mpv_flag=0;
						
						
						if (exists $id_limit_data->{$temp_id}->{$temp_date}->{'Hemoglobin'}) {
							my $temp_hgb = $id_limit_data->{$temp_id}->{$temp_date}->{'Hemoglobin'};
							$hgb_hash = find_hgb($temp_date, $temp_hgb);
						} else {
							$hgb_flag=1;
							print "no hgb val \n";
						}
							
						if (exists $id_limit_data->{$temp_id}->{$temp_date}->{'Platelets'}) {
							my $temp_plat = $id_limit_data->{$temp_id}->{$temp_date}->{'Platelets'};
							$plat_hash = find_plat($temp_date, $temp_plat);
						} else {
							$plat_flag=1;
							print "no plat val \n";
						}

						if (exists $id_limit_data->{$temp_id}->{$temp_date}->{'WBC'}) {
							my $temp_wbc = $id_limit_data->{$temp_id}->{$temp_date}->{'WBC'};
							$wbc_hash = find_wbc($temp_date, $temp_wbc);
						} else {
							$wbc_flag=1;
							print "no wbc val \n";
						}
						
						if (exists $id_limit_data->{$temp_id}->{$temp_date}->{'MPV'}) {
							my $temp_mpv = $id_limit_data->{$temp_id}->{$temp_date}->{'MPV'};
							$mpv_hash = find_mpv($temp_date, $temp_mpv);
						} else {
							$mpv_flag=1;
							print "no mpv val \n";
						}
						
						my $find_counter=0;
						my $find_id;
						for my $ids1 (keys %{$hgb_hash}) {
							if ( (exists $plat_hash->{$ids1} or $plat_flag==1) and (exists $wbc_hash->{$ids1} or $wbc_flag==1)  and (exists $mpv_hash->{$ids1} or $mpv_flag==1)  ) {
								print "find id : ".$ids1."\n";
								$find_id = $ids1;
								$find_counter++;
							}
						}
						if ($find_counter==1) {
							$hash_maccabi_to_medial->{$temp_id} = $find_id;
							print MACCABI_MEDIAL $temp_id."\t".$find_id."\n";
						} else {
							print MACCABI_MEDIAL $temp_id."\t"."not found"."\n";
							print "not found id : ".$temp_id." ".$find_counter."\n";
						}
						last;
					}
				}
			}
			close(MACCABI_MEDIAL);


			
			my $limit1 = FileHandle->new($maccabi_qa_dir."output7_over_limit_data1","w") or die "Cannot open output7_over_limit_data1 for writing" ;
			my $limit2 = FileHandle->new($maccabi_qa_dir."output7_over_limit_data2","w") or die "Cannot open output7_over_limit_data1 for writing" ;

			#open (LIMIT , ">output7_over_limit_data1") or die "cant open output7_over_limit_data1 \n";
			#open (LIMIT2 , ">output7_over_limit_data2") or die "cant open output7_over_limit_data2 \n";
			$limit1->print (join ("\t", "id", "blood_date","DateScore",  "gender", "age")."\t");
			$limit2->print (join ("\t", "id", "blood_date","DateScore",  "gender", "age")."\t");
			#print LIMIT join ("\t", "id", "blood_date","DateScore",  "gender", "age")."\t";
			#print LIMIT2 join ("\t", "id", "blood_date","DateScore",  "gender", "age")."\t";
			for my $temp_param (keys %{$param_ref}) {
				$limit1->print($temp_param."\t");
				$limit2->print($temp_param."\t");
				#print LIMIT $temp_param."\t";
				#print LIMIT2 $temp_param."\t";
				#print $temp_param."\n";
			}


			$limit1->print ( join ("\t", "DateScore","over_limit","Date", "CurrScore", "MedialId")."\n");
			$limit2->print ( join ("\t", "DateScore","over_limit","Date", "CurrScore", "MedialId")."\n");
			#print LIMIT join ("\t", "DateScore","over_limit","Date", "CurrScore", "MedialId")."\n";
			#print LIMIT2 join ("\t", "DateScore","over_limit","Date", "CurrScore", "MedialId")."\n";
			my $x_99_6_flag=0;
			my $x_99_flag=0;
			my $temp_handle;
			for my $temp_id (sort { $ids_over_limit->{$b}<=>$ids_over_limit->{$a}  } keys  %{$ids_over_limit}) {
				if ($ids_over_limit->{$temp_id}>=$score_limit2) {
					#$x_99_6_flag=1;
					#print LIMIT "**** print score with cutoff $score_limit2 \n";
					$temp_handle = $limit2;
				}
				
				if ($ids_over_limit->{$temp_id}>$score_limit and $ids_over_limit->{$temp_id}<$score_limit2) {
					#$x_99_flag=1;
					#print LIMIT "**** print score with cutoff $score_limit \n";
					$temp_handle = $limit1;
				}				
				
				
				for my $temp_date (sort {$a<=>$b} keys %{$id_limit_data->{$temp_id} }) {
				
					my $temp_age = substr($temp_date ,0,4) - $id_byear->{$temp_id};
					my $temp_gender = $id_gender->{$temp_id};
					
					#print LIMIT join ("\t", $temp_id ,  $temp_date, $hash_new_score->{$temp_id}->{$temp_date} ,  $temp_gender,$temp_age  )."\t";		
					$temp_handle->print (join ("\t", $temp_id ,  $temp_date, $hash_new_score->{$temp_id}->{$temp_date} ,  $temp_gender,$temp_age  )."\t");

					for my $temp_param (keys %{$param_ref}) {
						if (exists $id_limit_data->{$temp_id}->{$temp_date}->{$temp_param}) {
							#print LIMIT $id_limit_data->{$temp_id}->{$temp_date}->{$temp_param}."\t";
							$temp_handle->print ($id_limit_data->{$temp_id}->{$temp_date}->{$temp_param}."\t");
						} else {
							#print LIMIT "\t";
							$temp_handle->print("\t");
						}
					}
					
					my $mark="";
					if ($hash_new_score->{$temp_id}->{$temp_date}>$score_limit2) {
						$mark="(*)";
					}
					
					$temp_handle->print($hash_new_score->{$temp_id}->{$temp_date}."\t".$mark."\t".$temp_date."\t");
					$temp_handle->print($ids_over_limit->{$temp_id}."\t");
					#print LIMIT $hash_new_score->{$temp_id}->{$temp_date}."\t".$mark."\t".$temp_date."\t";
					#print LIMIT $ids_over_limit->{$temp_id}."\t";		
					
					if (exists $hash_maccabi_to_medial->{$temp_id}) {
						#print LIMIT $hash_maccabi_to_medial->{$temp_id};
						$temp_handle->print($hash_maccabi_to_medial->{$temp_id});
					} else {
						#print LIMIT "\t";
						$temp_handle->print("\t");
					}
					#print LIMIT "\n";
					$temp_handle->print("\n");
				}
				#print LIMIT "\n";
				$temp_handle->print("\n");
			}
			#close(LIMIT);
			$limit1->close();
			$limit2->close();


			print "\nfind medial ids dates .... \n";
			my $index ;
			open (IN, "W:/Users/Barak/maccabi_product_qa/find_id/index_file.idx") or die "cant open index_file.idx for reading \n";
			my $counter=0;
			while (<IN>) {
				chomp;
				my @arr = split "\t";
				$index->[$counter] = $arr[0];
				$counter++;
			}
			close(IN);

			my $name = "W:/Users/Barak/maccabi_product_qa/find_id/all_cbc_2_find_id_sort.txt";
			my $my_fh = FileHandle->new($name,"r") or die "Cannot open \'$name\' for reading" ;


			open (LIMIT_MEDIAL , ">".$maccabi_qa_dir."output8_over_limit_medial") or die "cant open output8_over_limit_medial \n";
			for my $temp_id (keys %{$id_limit_data}) {
				print "find dates for id  maccabi : $temp_id  medial : $hash_maccabi_to_medial->{$temp_id}  \n";
				if (exists $hash_maccabi_to_medial->{$temp_id}) {
					my $medial_id = $hash_maccabi_to_medial->{$temp_id};
					my $temp_hash = find_hgb_dates_new($medial_id ,$my_fh , $index );
					for my $temp_date ( sort {$a<=>$b} keys %{$temp_hash}) {
						print  join ("\t", $temp_id , $medial_id , $temp_date , $temp_hash->{$temp_date})."\n";
						print LIMIT_MEDIAL join ("\t", $temp_id , $medial_id , $temp_date , $temp_hash->{$temp_date})."\n";
					}
				}
			}
			close(LIMIT_MEDIAL);
}





my $all_counts;
my $all_gaps;
my $all_ids = 0;
my $all_dates=0;
my $score_hash;
for my $temp_id (keys %{$id_counts}) {
	
	my $temp_count = scalar(keys $id_counts->{$temp_id});
	$temp_count='>5' if ($temp_count>5);
	$all_counts->{$temp_count}++;
	
	for my $blood_date (keys $id_counts->{$temp_id}) {
		my $year=substr ($blood_date ,0,4);
		$year_hash->{$year}++;	
		$all_dates++;
	}
	
	for my $temp_gap (keys $id_gaps->{$temp_id}) {
		$all_gaps->{$temp_gap}++;
	}
	$all_ids++;

	my $score_count=0;
	if (exists $id_sore_date->{$temp_id}->{'id_score_count'})  {
		$score_count = $id_sore_date->{$temp_id}->{'id_score_count'};
	}
	$score_hash->{$score_count}++;
}


print "step 6\n";


open (OUT, ">".$maccabi_qa_dir."output3_data_analysis.txt") or die "cant open history_analysis.txt";
print OUT join ("\t","source", "param_name", "param_val", "count", "dist")."\n";


print_hash($year_hash , $all_dates , "data_file" , "history_by_year");
print_hash($all_counts, $all_ids , "data_file" , "num_of_blood_tests_for_id");
print_hash($all_gaps , $all_ids , "data_file" , "num_of_ids_with_blood_dates_in_gap");
#print_hash($code_hash , $all_dates , "data_file" , "num_of_blood_date_with_cbc_code");
print_hash($score_hash, $all_ids , "score_and_data_files" , "num_of_score_per_id");
print_hash ($hash_gender, $all_ids, "score_file", "gender");
print_hash ($hash_age_bin, $all_ids, "score_file", "age_bin");
print_hash ($hash_diff_blood_system, $count_scores , "score_file" , "gap_blood_and_system_date" );
print_hash($hash_scores_lim , $count_scores , "score_file", "num_of_score_per_group");


for my $temp_gender (sort {$a <=> $b} keys $hash_gender_age_bin_scores) {
	for my $temp_age_bin (sort {$a <=> $b} keys $hash_gender_age_bin_scores->{$temp_gender} ) {
		my @temp_arr = @{$hash_gender_age_bin_scores->{$temp_gender}->{$temp_age_bin} };
		my ($temp_avg, $temp_sdv, $n) = get_stats(@temp_arr);
		print OUT "score_files"."\t"."gender_age_bin_score_avg_sdv_n"."\t".$temp_gender."_".$temp_age_bin."\t".$temp_avg."\t".$temp_sdv."\t".$n."\n";
	}
}


for my $blood_code ( sort {$a<=>$b} keys %{$code_hash} ) {
	
	my $count_min=0;
	my $count_max=0;
	
	if (exists $code_hash_limits->{$blood_code}->{'min'}) {
		$count_min = $code_hash_limits->{$blood_code}->{'min'};
	}
	
	if (exists $code_hash_limits->{$blood_code}->{'max'}) {
		$count_max = $code_hash_limits->{$blood_code}->{'max'};
	}	
	my $total_outlier = $count_min + $count_max ;

	#print OUT join ("\t", "data_file", "param_outliers count, outlier(min,max,total) %",	$blood_code,	$code_hash->{$blood_code} , "(".$count_min.",".$count_max.",".$total_outlier.")",	$total_outlier/$code_hash->{$blood_code} )."\n";
	
	my $temp_ratio = (int(10000*($total_outlier/$code_hash->{$blood_code})))/100;
	print OUT join ("\t", "data_file", "param_outliers count, outlier(min,max,total) %",	$blood_code,	$code_hash->{$blood_code} , $temp_ratio."%" )."\n";
	print join ("\t", "data_file", "param_outliers (count , outlier_min , outlier_max, total  %",	$blood_code,	$code_hash->{$blood_code} , $count_min,	$count_max,	$total_outlier,	$total_outlier/$code_hash->{$blood_code} )."\n";
	#<STDIN>;
}



my $count_multi;
my $code_hash_new;
print OUT_ERROR join ("\t", "error_type", "id" , "blood_date" , "blood_code" , "val")."\n";
for my $id (keys %{$multiple_data}) {
	for my $blood_date (keys %{$multiple_data->{$id}}) {
		for my $blood_code (keys %{$multiple_data->{$id}->{$blood_date}}) {
			$code_hash_new->{$blood_code}++;
			my $val = $multiple_data->{$id}->{$blood_date}->{$blood_code};
			if ($val>1) {
				print OUT_ERROR join ("\t", "double values (id_date,code)", $id ,$blood_date ,$blood_code ,$val)."\n";
				$count_multi++;
			}
		}		
	}
}
print OUT "score_files"."\t"."multiple_values (id,date,param)"."\t"."\t".$count_multi."\n";
print_hash($code_hash_new , $all_dates , "data_file" , "num_of_blood_date_with_cbc_code");





close(OUT_ERROR);
close(OUT);


#exit;


print "step 7\n";

#my $r_script_dir = "U://Barak//r_scripts";
#system("w://Applications/R/R-latest/bin/x64/R CMD BATCH --silent --no-timing  $r_script_dir//maccabi_product_qa.r  R_StdErr ");


open (OUT_INFO , ">".$maccabi_qa_dir."output5_info_file.txt") or die "cant open output5_data_analysis.txt";
#print OUT_INFO join ("\t", "colon_score", "limit_99.6", "limit_99.6\%","limit_99.6_hgb", "limit_99", "limit_99\%","limit_99_hgb")."\n";


my $count_99_6=0;
my $count_99_6_hgb=0;
my $count_99=0;
my $count_99_hgb=0;

for my $temp_id (keys %{$id_limit_data}) {
	
	my $score_date = $id_sore_date->{$temp_id}->{'blood_date'};
	my $score_hgb = $id_limit_data->{$temp_id}->{$score_date}->{'Hemoglobin'};
	my $gender = $id_gender->{$temp_id};
	my $hgb_ind=0;
	if (($score_hgb<11 and $gender eq "F") or ($score_hgb<12 and $gender eq "M")) {
		$hgb_ind=1;
	}
	

	if ($ids_over_limit->{$temp_id}>=$score_limit2) {
		$count_99_6++;
		$count_99_6_hgb+=$hgb_ind;
	} else {
		$count_99++;
		$count_99_hgb+=$hgb_ind;		
	}
}
my $count_99_6_ratio = (int(10000*($count_99_6/$count_scores)))/100;
my $count_99_ratio = (int(10000*($count_99/$count_scores)))/100;

#print OUT_INFO join ("\n", $count_scores, $count_99_6, $count_99_6_ratio."%",$count_99_6_hgb, $count_99, $count_99_ratio."%" ,$count_99_hgb)."\n";
#print OUT_INFO "\n";
#print OUT_INFO "score_file: ".$maccabi_dir.$scores_file_name."\n";
#print OUT_INFO "score_file: ".$maccabi_dir.$data_file_name."\n";
#print OUT_INFO "score_file: ".$maccabi_dir.$demog_file_name."\n";


print OUT_INFO join ("\t", "colon_score", $count_scores)."\n";
print OUT_INFO join ("\t","limit_99.6", $count_99_6)."\n";
print OUT_INFO join ("\t","limit_99.6_of_colon_score",$count_99_6_ratio."%")."\n";
print OUT_INFO join ("\t","limit_99.6_hgb", $count_99_6_hgb)."\n";
print OUT_INFO join ("\t","limit_99", $count_99)."\n";
print OUT_INFO join ("\t","limit_99_of_colon_score",$count_99_ratio."%")."\n";
print OUT_INFO join ("\t","limit_99_hgb",$count_99_hgb)."\n";




close(OUT_INFO);


print "step 8\n";


#==================================  compare to reffernence ===================================

compare_to_ref:

print "compare_to_ref\n";

my $ref_dir1 = $ref_dir."2008-JAN-01";
my $orig_file = "output3_data_analysis.txt";
my $ref_file = $ref_dir1."/".$orig_file;
my $out_file = ">".$maccabi_qa_dir."output3_data_analysis_with_ref.txt";

print  "ref : $ref_file  \n";

open (IN ,  $maccabi_qa_dir.$orig_file) or die "cant open file :$orig_file ";
open (OUT , $out_file) or die "cant open file :$out_file ";
while (<IN>) {
	chomp;
	my @arr = split "\t";
	print OUT join ("\t", @arr)."\t"."n_row"."\t";
	print OUT join("\t", $arr[3], $arr[4],"n_row")."\n";
	last;
}
close(IN);


print "($ref_file); \n";
my $ref_hash = get_analysis_ref($ref_file);
print "get_analysis_ref($orig_file); \n";
my $orig_hash = get_analysis_ref($maccabi_qa_dir.$orig_file);


for my $temp_source (sort {$a<=>$b} keys %{$orig_hash} ) {
	for my $param_name (sort {$a<=>$b} keys %{$orig_hash->{$temp_source} } ) {
		for my $key1 (sort {$a<=>$b}  keys %{$orig_hash->{$temp_source}->{$param_name} } ) {
		
			print OUT join ("\t",$temp_source,  $param_name, $key1)."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val1'}."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val2'}."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val3'}."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val4'}."\t";
			#print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val5'}."\t";
			
			if (exists $ref_hash->{$temp_source}->{$param_name}->{$key1}) {
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val1'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val2'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val3'}."\t";
				#print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val4'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val4'};	
			}
			print OUT "\n";
		}
		
		for my $key1 (keys %{$ref_hash->{$temp_source}->{$param_name} } ) {
			if (!exists $orig_hash->{$temp_source}->{$param_name}->{$key1}) {
				print OUT join ("\t",$temp_source,  $param_name, $key1)."\t";
				print OUT "\t\t\t\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val1'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val2'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val3'}."\t";
				#print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val4'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val4'};						
				print OUT "\n";
			}
		}
	}
}
close(OUT);
print "step 9\n";


open (OUT, ">".$maccabi_qa_dir."gender_age_score_files_ref.txt") or die "cant open gender_age_score_files_ref.txt";
open (IN_ORIG, $maccabi_qa_dir."gender_age_score_files.txt") or die "cant open gender_age_score_files.txt";
while (<IN_ORIG>) {
	chomp;
	my @temp_arr = split "\t";
	print OUT join ("\t" , @temp_arr)."\n";
}


my $ref_name = $ref_dir."/"."gender_age_score_files.txt";
print $ref_name."\n";
open (IN_REF, $ref_dir."/"."gender_age_score_files.txt") or die "cant open gender_age_score_files.txt";
while (<IN_REF>) {
	chomp;
	my @temp_arr = split "\t";
	print OUT join ("\t" , $temp_arr[0],$temp_arr[1],$temp_arr[2],"ref")."\n";
}

close(OUT);

my $r_script_dir = "U://Barak//r_scripts";

print_r ("gender_age_score_files_ref.txt", "maccabi_product_qa.r" , $maccabi_qa_dir);

system("w://Applications/R/R-latest/bin/x64/R CMD BATCH --silent --no-timing  $maccabi_qa_dir//maccabi_product_qa.r  ".$maccabi_qa_dir."R_StdErr ");


print "step 10\n";




#============================================ create file for newmark ====================================

#newmark_analysis:

my $dir_name = $maccabi_qa_dir.$run_date."_newmark_files";

my $cmd = "mkdir -p $dir_name";
print $cmd."\n";
#<STDIN>;
run_cmd ("mkdir -p $dir_name");

my $source = $run_date."_newmark_files";



#create cbc file
print "create cbc.txt file \n";
open (DATA, $maccabi_dir.$data_file_name) or die "cant open $maccabi_dir.$data_file_name";
open (NEW_CBC , ">".$dir_name."/"."cbc.txt") or die "cant open cbc_for_newmark.txt";
while (<DATA>) {
	chomp;
	my @temp_arr = split "\t";
	print NEW_CBC join("\t", $temp_arr[1] , $temp_arr[2] , convert_date($temp_arr[3]) , $temp_arr[4])."\n";
}
close(DATA);
close(NEW_CBC);


print "create demog,censor files \n";
open (DEMOG, $maccabi_dir.$demog_file_name) or die "cant open $maccabi_dir.$demog_file_name";
open (NEW_DEMOG , ">".$dir_name."/"."demographics.txt") or die "cant open demographics.txt";
open (NEW_CENSOR , ">".$dir_name."/"."censor.status") or die "cant open censor.status";
while (<DEMOG>) {
	chomp;
	my @temp_arr = split "\t";
	print NEW_DEMOG join (" ", $temp_arr[1], $temp_arr[2], $temp_arr[3])."\n";
	print NEW_CENSOR join (" ", $temp_arr[1], "1", "1", "19000101")."\n";
}
close(DEMOG);
close(NEW_DEMOG);
close(NEW_CENSOR);


print "create params.csv \n";
open (PARAMS , ">".$dir_name."/"."params.csv") or die "cant open params.csv";
	print PARAMS "CRC_DISCOVERY_WINDOWS_MINIMAL_DAYS,30"."\n";
	print PARAMS "CRC_DISCOVERY_WINDOWS_MAXIMAL_DAYS,180"."\n";
	print PARAMS "CENSOR_INSCULSION_START_DATE,20021231"."\n";
	print PARAMS "CENSOR_INSCULSION_END_DATE,20110701"."\n";
	print PARAMS "MIN_AGE_FOR_DISTRIBUTION,50"."\n";
	print PARAMS "MAX_AGE_FOR_DISTRIBUTION,75"."\n";
	print PARAMS "REGISTRY_FIRST_YEAR,2003"."\n";
	print PARAMS "REGISTRY_LAST_YEAR,2011"."\n";
	print PARAMS "CBC_FIRST_YEAR,2003"."\n";
	print PARAMS "CBC_LAST_YEAR,2015"."\n";
	print PARAMS "REF_YEAR_FOR_AGE_CALCULATION,2010"."\n";
	print PARAMS "MIN_AGE_FOR_RELATIVE_RISK_PIVOT,60"."\n";
	print PARAMS "MAX_AGE_FOR_RELATIVE_RISK_PIVOT,65"."\n";
	print PARAMS "EXTERNAL_FACTOR,80"."\n";
	print PARAMS "CBC_FIRST_DATE,20021231"."\n";
	print PARAMS "CBC_LAST_DATE,20150701"."\n";
close(PARAMS);


print "create test_codes.csv \n";
open (TEST_CODES , ">".$dir_name."/"."test_codes.csv") or die "cant open test_codes.csv";
	print TEST_CODES "5041,RBC,1,1.39411,8.297552,1.60604,7.24258,100"."\n";
	print TEST_CODES "5048,WBC,1,0,21.643444,0,20.641869,100"."\n";
	print TEST_CODES "50221,MPV,1,4.238767,17.711051,4.117681,17.892743,100"."\n";
	print TEST_CODES "50223,HGB,1,2.065128,26.099908,2.872031,22.297255,100"."\n";
	print TEST_CODES "50224,HCT,1,12.169881,72.406869,13.17865,63.929308,100"."\n";
	print TEST_CODES "50225,MCV,1,48.102673,126.788525,46.435053,128.208871,100"."\n";
	print TEST_CODES "50226,MCH,2,12.156558,46.010742,11.365072,45.619138,100"."\n";
	print TEST_CODES "50227,MCHC_M,1,23.990878,42.481392,24.284748,40.914536,100"."\n";
	print TEST_CODES "50228,RDW,1,4.746657,22.771279,4.244076,23.602618,100"."\n";
	print TEST_CODES "50229,PLT,1,0,699.642189,0,766.838653,100"."\n";
	print TEST_CODES "50230,Eos#,1,0,1.279387,0,1.10501,100"."\n";
	print TEST_CODES "50232,Neu%,1,0,117.893542,0,119.997951,100"."\n";
	print TEST_CODES "50234,Mon%,1,0,24.05196,0,22.290069,100"."\n";
	print TEST_CODES "50235,Eos%,1,0,16.721315,0,15.74616,100"."\n";
	print TEST_CODES "50236,Bas%,1,0,2.333111,0,2.399567,100"."\n";
	print TEST_CODES "50237,Neu#,1,0,15.160095,0,14.489751,100"."\n";
	print TEST_CODES "50239,Mon#,1,0,2.141995,0,1.828974,100"."\n";
	print TEST_CODES "50241,Bas#,1,0,0.213782,0,0.202111,100"."\n";
	print TEST_CODES "50233,Lym%,1,0,87.192003,0,91.025892,100"."\n";
	print TEST_CODES "50238,Lym#,1,0,7.241201,0,7.013622,100"."\n";
close(TEST_CODES);


print "create registry.csv \n";
open (REGISTRY , ">".$dir_name."/"."registry.csv") or die "cant open registry.csv";
close(REGISTRY);

print "create cbc.bin \n";
my $cmd = "u:///Barak/Medial/Projects/ColonCancer/prepare_cancer_matrix/x64/Release/write_cbc_as_bin.exe ".$dir_name."/";
run_cmd ($cmd);


my $cmd = "cp -r ".$dir_name." w://Users/barak/maccabi_product_qa/summary_stats/input/";
print $cmd."\n";
system ($cmd);




#my $dir_name = $run_date."_newmark_files";
my $cmd = "u:///Barak/Medial/Projects/ColonCancer/prepare_cancer_matrix/x64/Release/summary_stats.exe --path w://Users/barak/maccabi_product_qa/summary_stats/ --source $source --in-ref MHS --run-7 ";
print $cmd."\n";
system ($cmd);


newmark_analysis:

my $cmd ="cp w://Users/barak/maccabi_product_qa/summary_stats/output/summary_stats.xls $maccabi_qa_dir ";
system ($cmd);

#=====================================  copy to excel =================================


my $excel_name = $maccabi_qa_dir."summary_".$run_date.".xls";
my $workbook_handle = Spreadsheet::WriteExcel->new($excel_name);
my $format = $workbook_handle->add_format();
$format->set_size(11);
$format->set_font('Arial');
$format->set_num_format('General');

my $format1 = $workbook_handle->add_format();
$format1->set_size(11);
$format1->set_font('Arial');
$format1->set_num_format('0.0%');


copy_file_to_xl ($workbook_handle, "info_file" , $maccabi_qa_dir."output5_info_file.txt",$format,$format1);
copy_file_to_xl ($workbook_handle, "compare_2_score_files" , $maccabi_qa_dir."output1_compare_2_score_files.txt",$format,$format1);
copy_file_to_xl ($workbook_handle, "score_file_warnings_errors" , $maccabi_qa_dir."output2_score_file_warnings_errors.txt",$format,$format1);
copy_file_to_xl ($workbook_handle, "data_score_analysis_with_ref" , $maccabi_qa_dir."output3_data_analysis_with_ref.txt",$format,$format1);
copy_file_to_xl ($workbook_handle, "error_file" , $maccabi_qa_dir."output6_error_file.txt",$format,$format1);
copy_file_to_xl ($workbook_handle, "over_limit_data_99_6" , $maccabi_qa_dir."output7_over_limit_data2",$format,$format1);
copy_file_to_xl ($workbook_handle, "over_limit_data_99" , $maccabi_qa_dir."output7_over_limit_data1",$format,$format1);

my $my_worksheet = $workbook_handle->add_worksheet('score_distributions');
system (" ls $maccabi_qa_dir   | grep png > ".$maccabi_qa_dir."my_pics.txt ");
open (PICS , $maccabi_qa_dir."my_pics.txt") or die "cant open my_pics.txt ";
my $count_row=3;
while (<PICS>) {
	chomp;
	my @arr = split "\t";
	my $pic_name = $arr[0];
	$my_worksheet->insert_image($count_row, 3 , $pic_name , 0, 0, 0.2,0.2);
	$count_row+=35;
}

copy_file_to_xl ($workbook_handle, "over_limit_medial" , $maccabi_qa_dir."output8_over_limit_medial",$format,$format1);
copy_file_to_xl ($workbook_handle, "maccabi_to_medial" , $maccabi_qa_dir."output9_maccabi_to_medial",$format,$format1);


$workbook_handle->close() or die "cant close file $! \n";

exit;



#========================================   END OF QA PROGRAM ======================================


exit;



#==================================  load data for reffernence ===================================

load_ref:



my $ids_file = "W:/Users/Barak/maccabi_product_qa/maccabi_simulation/collect_scores_for_qa_ids.txt";
my $id_rand_hash;
open (IDS, $ids_file) or die "cant open $ids_file \n";
while (<IDS>) {
	chomp;
	my @ids = split "\t";
	my $temp_rand = int(rand(2));
	$id_rand_hash->{$ids[0]} =  $temp_rand;
}
close(IDS);


my $ids_date_file = "W:/Users/Barak/maccabi_product_qa/maccabi_simulation/collect_scores_for_qa.txt";
my $id_date_hash;
open (IDS_DATES, $ids_date_file) or die "cant open $ids_file \n";
while (<IDS_DATES>) {
	chomp;
	my @ids = split "\t";
	$id_date_hash->{$ids[0]} =  $ids[1];
}
close(IDS_DATES);


my $rep_file = "W:/Users/Barak/maccabi_product_qa/maccabi_simulation/cbc_maccabi_simulation.txt";
open (REP, $rep_file) or die "cant open $rep_file \n";
open (NEWMARK_0, ">W:/Users/Barak/maccabi_product_qa/maccabi_simulation/cbc_0.txt");
open (NEWMARK_1, ">W:/Users/Barak/maccabi_product_qa/maccabi_simulation/cbc_1.txt");
while (<REP>) {
	chomp;
	my @temp_arr = split " ";
	my $temp_id = $temp_arr[1];
	my $blood_date = $temp_arr[2];

	next if (get_days($blood_date) > get_days ($id_date_hash->{$temp_id}));
	
	if ($id_rand_hash->{$temp_id}==0) {
		print NEWMARK_0 join ("\t", $temp_id, $param_ref->{$temp_arr[0]},$temp_arr[2], $temp_arr[3])."\n";
	} else {
		print NEWMARK_1 join ("\t", $temp_id, $param_ref->{$temp_arr[0]},$temp_arr[2], $temp_arr[3])."\n";
	}
}
close(NEWMARK_0);
close(NEWMARK_1);


exit;


goto xxxx;
my $rep_file = "W:/Users/Barak/maccabi_product_qa/maccabi_simulation/cbc_maccabi_simulation.txt";
open (REP, $rep_file) or die "cant open $rep_file \n";
open (OUT0, ">W:/Users/Barak/maccabi_product_qa/maccabi_simulation/cbc_for_product_0.txt");
open (OUT1, ">W:/Users/Barak/maccabi_product_qa/maccabi_simulation/cbc_for_product_1.txt");
while (<REP>) {
	chomp;
	my @temp_arr = split " ";
	my $temp_id = $temp_arr[1];
	my $blood_date = $temp_arr[2];

	next if (get_days($blood_date) > get_days ($id_date_hash->{$temp_id}));
	
	if ($id_rand_hash->{$temp_id}==0) {
		print OUT0 join ("\t", "2", $temp_id, $param_ref->{$temp_arr[0]},convert_date_to_words($temp_arr[2]), $temp_arr[3])."\n";
	} else {
		print OUT1 join ("\t", "2", $temp_id, $param_ref->{$temp_arr[0]},convert_date_to_words($temp_arr[2]), $temp_arr[3])."\n";
	}
}
close(OUT0);
close(OUT1);
xxxx:


my $demog_gender;
my $demog_byear;
open (DEMOG,"W:/CancerData/AncillaryFiles/Demographics") or die "Cannot open Byears files" ;
while (<DEMOG>) {
	chomp ;
	my ($id,$year,$gender) = split ;
	$demog_gender->{$id} = $gender;
	$demog_byear->{$id} = $year;
}
close (DEMOG) ;



open (DEMOG_FOR_PRODUCT, ">W:/Users/Barak/maccabi_product_qa/maccabi_simulation/demog_for_prduct.txt");
for my $temp_id (keys %{$id_rand_hash}) {
	print DEMOG_FOR_PRODUCT join ("\t", "2", $temp_id, $demog_byear->{$temp_id} , $demog_gender->{$temp_id} )."\n";
}
close(DEMOG_FOR_PRODUCT);


#==================================  create data for find ===================================

my_find_id:

#my $file = "cbc_2_find_id_hgb.txt";
#my $file = "cbc_2_find_id_wbc.txt";
#my $file = "cbc_2_find_id_plat.txt";
#my $file = "cbc_2_find_id_mpv.txt";

my $file = "";


open (FIND, "W:/Users/Barak/maccabi_product_qa/find_id/".$file);
open (FIND_2000, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2000");
open (FIND_2001, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2001");
open (FIND_2002, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2002");
open (FIND_2003, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2003");
open (FIND_2004, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2004");
open (FIND_2005, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2005");
open (FIND_2006, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2006");
open (FIND_2007, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2007");
open (FIND_2008, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2008");
open (FIND_2009, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2009");
open (FIND_2010, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2010");
open (FIND_2011, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2011");
open (FIND_2012, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2012");
open (FIND_2013, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2013");
open (FIND_2014, ">W:/Users/Barak/maccabi_product_qa/find_id/".$file.".2014");
while (<FIND>) {
	chomp;
	my @temp_arr = split " ";
	#print join ("\t", @temp_arr);
	if (substr ( $temp_arr[2],0,4) == 2000) {
		print FIND_2000 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2001) {
		print FIND_2001 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2002) {
		print FIND_2002 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2003) {
		print FIND_2003 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2004) {
		print FIND_2004 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2005) {
		print FIND_2005 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2006) {
		print FIND_2006 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2007) {
		print FIND_2007 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2008) {
		print FIND_2008 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2009) {
		print FIND_2009 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2010) {
		print FIND_2010 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2011) {
		print FIND_2011 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2012) {
		print FIND_2012 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2013) {
		print FIND_2013 join ("\t", @temp_arr)."\n";
	} elsif (substr ( $temp_arr[2],0,4) == 2014) {
		print FIND_2014 join ("\t", @temp_arr)."\n";
	}
}

close(FIND_2000);
close(FIND_2001);
close(FIND_2002);
close(FIND_2003);
close(FIND_2004);
close(FIND_2005);
close(FIND_2006);
close(FIND_2007);
close(FIND_2008);
close(FIND_2009);
close(FIND_2010);
close(FIND_2011);
close(FIND_2012);
close(FIND_2013);
close(FIND_2014);


exit;



#############################################  procs #############################################



sub get_analysis_ref {
	my ($file_name) = @_;

	print "in ref : $file_name \n";
	
	open (REF , $file_name) or die "cant open file :$file_name ";
	my $count_file=0;
	my $hash_ref;
	while (<REF>)  {
		chomp;
		my @temp_arr = split "\t";
		if ($count_file>0) {
			my $source = $temp_arr[0];
			my $key1 = $temp_arr[1];
			my $key2 = $temp_arr[2];
			$hash_ref->{$source}->{$key1}->{$key2}->{'val1'} = $temp_arr[3];
			$hash_ref->{$source}->{$key1}->{$key2}->{'val2'} = $temp_arr[4];
			
			$hash_ref->{$source}->{$key1}->{$key2}->{'val3'} = "";
			$hash_ref->{$source}->{$key1}->{$key2}->{'val4'} = "";
			$hash_ref->{$source}->{$key1}->{$key2}->{'val5'} = "";
			
			if ($#temp_arr==5) {
				$hash_ref->{$source}->{$key1}->{$key2}->{'val3'} = $temp_arr[5];
			} elsif ($#temp_arr==6) {
				$hash_ref->{$source}->{$key1}->{$key2}->{'val3'} = $temp_arr[5];
				$hash_ref->{$source}->{$key1}->{$key2}->{'val4'} = $temp_arr[6];
			} elsif ($#temp_arr==7) {
				$hash_ref->{$source}->{$key1}->{$key2}->{'val3'} = $temp_arr[5];
				$hash_ref->{$source}->{$key1}->{$key2}->{'val4'} = $temp_arr[6];
				$hash_ref->{$source}->{$key1}->{$key2}->{'val5'} = $temp_arr[7];
			}
		}
		$count_file++;
	}
	return $hash_ref;
}



sub convert_code_to_name {
	my $code = shift @_;
	my $param_ref;
$param_ref->{5041} = 'RBC';
$param_ref->{5048} = 'WBC';
$param_ref->{50221} = 'MPV';
$param_ref->{50223} = 'Hemoglobin';
$param_ref->{50224} = 'Hematocrit';
$param_ref->{50225} = 'MCV';
$param_ref->{50226} = 'MCH';
$param_ref->{50227} = 'MCHC-M';
$param_ref->{50228} = 'RDW';
$param_ref->{50229} = 'Platelets';
$param_ref->{50232} = 'Neutrophils%';
$param_ref->{50233} = 'Lymphocytes%';
$param_ref->{50234} = 'Monocytes%';
$param_ref->{50235} = 'Eosinophils%';
$param_ref->{50236} = 'Basophils%';
$param_ref->{50237} = 'Neutrophils#';
$param_ref->{50238} = 'Lymphocytes#';
$param_ref->{50239} = 'Monocytes#';
$param_ref->{50230} = 'Eosinophils#';
$param_ref->{50241} = 'Basophils#';

return $param_ref->{$code};

}



sub get_score_bin {
	my $score = shift @_;
	my $score_group;

	#my @qa_scores (99.6,99,97,95,90);
	
	#print $score."\n";
	#<STDIN>;
	
	
	if ($score>=99.6) {
		$score_group = '>=99.6';
	} elsif ($score>=99) {
		$score_group = '99-99.6';
	} elsif ($score>=97) {
		$score_group = '97-99';
	} elsif ($score>=95) {
		$score_group = '95-97';
	} elsif ($score>=90) {
		$score_group = '90-95';
	} else {
		$score_group = '<90';
	}
	
	return $score_group;
}



sub get_stats {
	my @temp_arr = @_;
	
	my $n = scalar(@temp_arr);
	my $avg=0;
	for my $i (0..$#temp_arr) {
		$avg+=$temp_arr[$i];
	}
	$avg/=$n;
	
	my $sdv=0;
	for my $i (0..$#temp_arr) {
		$sdv+=($temp_arr[$i]-$avg)*($temp_arr[$i]-$avg);
	}
	
	$sdv= sqrt($sdv/$n);
	
	return ($avg, $sdv, $n);
}



sub print_hash {
	my ($temp_hash, $count_all, $source , $param_name) = @_;

	for my $temp_key (sort {$a<=>$b} keys $temp_hash) {
		my $temp_count = $temp_hash->{$temp_key};
		my $temp_dist = (int(10000*($temp_count/$count_all)))/100;
		print OUT $source."\t".$param_name."\t".$temp_key."\t".$temp_count."\t".$temp_dist ."%\n";
	}	
	
}



sub gap_group  {
	my $gap = shift @_ ;
	my $gap_group;
	if ($gap==0) {
		$gap_group='0';
	} elsif ($gap<180) {
		$gap_group='1-180';
	}  elsif ($gap<360) {
		$gap_group='181-360';
	}  elsif ($gap<730) {
		$gap_group='361-730';
	} elsif  ($gap>=730) {
		$gap_group='>730';
	} else {
		$gap_group='error';
	}

	return $gap_group;
	
}


sub convert_date_to_words {
	my $orig_date = shift @_ ;
	my $year = substr($orig_date,0,4);
	my $month = substr($orig_date,4,2);
	my $day = substr($orig_date,6,2);
	
my %year_hash;
$year_hash{'01'} = 'JAN';
$year_hash{'02'} = 'FEB';
$year_hash{'03'} = 'MAR';
$year_hash{'04'} = 'APR';
$year_hash{'05'} = 'MAY';
$year_hash{'06'} = 'JUN';
$year_hash{'07'} = 'JUL';
$year_hash{'08'} = 'AUG';
$year_hash{'09'} = 'SEP';
$year_hash{'10'} = 'OCT';
$year_hash{'11'} = 'NOV';
$year_hash{'12'} = 'DEC';	


my $blood_date = $year."-".$year_hash{$month}."-".$day;
return $blood_date;
	
}




sub convert_date {
	my $orig_date = shift @_ ;
	my ($year,$month, $day) = split "-", $orig_date;
	
my %year_hash;
$year_hash{'JAN'} = '01';
$year_hash{'FEB'} = '02';
$year_hash{'MAR'} = '03';
$year_hash{'APR'} = '04';
$year_hash{'MAY'} = '05';
$year_hash{'JUN'} = '06';
$year_hash{'JUL'} = '07';
$year_hash{'AUG'} = '08';
$year_hash{'SEP'} = '09';
$year_hash{'OCT'} = '10';
$year_hash{'NOV'} = '11';
$year_hash{'DEC'} = '12';	

$year_hash{'Jan'} = '01';
$year_hash{'Feb'} = '02';
$year_hash{'Mar'} = '03';
$year_hash{'Apr'} = '04';
$year_hash{'May'} = '05';
$year_hash{'Jun'} = '06';
$year_hash{'Jul'} = '07';
$year_hash{'Aug'} = '08';
$year_hash{'Sep'} = '09';
$year_hash{'Oct'} = '10';
$year_hash{'Nov'} = '11';
$year_hash{'Dec'} = '12';

	
my $blood_date = $year.$year_hash{$month}.$day;
return $blood_date;
	
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


sub get_age_bin {
	my $age = shift @_;
	my $age_bin;
	
	if ($age>=40 and $age<50) {
		$age_bin='40_49';
	} elsif ($age>=50 and $age<60) {
		$age_bin='50_59';
	} elsif ($age>=60 and $age<70) {
		$age_bin='60_69';
	} elsif ($age>=70 and $age<80) {
		$age_bin='70_79';
	} else {
		$age_bin="error age:".$age;
	}
	
	return $age_bin;
}



sub run_cmd {
	my ($command) = @_ ;
	
	#print STDERR "Running \'$command\'\n" ;
	(system($command) == 0 or die "\'$command\' Failed" ) ;
	
	return ;
}	



sub find_hgb_dates_new   {	
	my ($id ,$my_fh , $index ) = @_;
	my %hash_dates;
	
	#print "@@@@@@@@@@@@@@@@@@@ in find_hgb_dates_new  @@@@@@@@@@@@@@@@@@@ \n";
	my $from = $index->[$id];
	return \%hash_dates if ($from == -1) ;

	my $to = -1 ;
	my $nids = 4000000 + 1 ;
	if ($id != $nids) {
		my $next = $id+1 ;
		$next++ while ($next <= $nids and $index->[$next] == -1) ;
		$to = $index->[$next] if ($next <= $nids) ;
	}

	#print "get id data from: $from   \n";
	#print "get id data from: $to   \n";
	
	$my_fh->seek($from,0) ;
	my $finish = 0 ;
	while (my $line = $my_fh->getline()) {
		chomp $line ;
		my @fields = split " " , $line ;
		#print join ("\t", @fields)."\n";
		
		if ($fields[0] eq "Hemoglobin") {
			$hash_dates{$fields[2]} = $fields[3];
		}
		
		my $curr_pos = $my_fh->tell();
		if ($curr_pos == $to) {
			$finish = 1 ;
			last ;
		}
	}	
	
	return \%hash_dates;
}


sub find_hgb_dates   {
	my ($temp_id) = @_;
	my $hash_dates;
	open (HGB, "W:/Users/Barak/maccabi_product_qa/find_id/cbc_2_find_id_hgb.txt");
	while (<HGB>) {
		chomp;
		my @temp_arr = split " ";
		if ($temp_arr[1]==$temp_id) {
			$hash_dates->{$temp_arr[2]}=$temp_arr[3];
		}
	}
	return $hash_dates;
}



sub find_hgb   {
	#print "in find hgb \n";
	my ($temp_date, $temp_hgb) = @_;
	my $id_ref;
	my $year = substr ($temp_date,0,4);
	open (HGB, "W:/Users/Barak/maccabi_product_qa/find_id/cbc_2_find_id_hgb.txt".".".$year);
	while (<HGB>) {
		chomp;
		my @temp_arr = split " ";
		if ($temp_arr[2]==$temp_date and $temp_arr[3]==$temp_hgb) {
			$id_ref->{$temp_arr[1]}=1;
		}
	}
	
	my $n_ids = scalar (keys %{$id_ref});
	print "hgb found $n_ids ids \n";
	return $id_ref;
}


sub find_mpv   {
	#print "in find hgb \n";
	my ($temp_date, $temp_hgb) = @_;
	my $id_ref;
	my $year = substr ($temp_date,0,4);
	open (HGB, "W:/Users/Barak/maccabi_product_qa/find_id/cbc_2_find_id_mpv.txt".".".$year);
	while (<HGB>) {
		chomp;
		my @temp_arr = split " ";
		if ($temp_arr[2]==$temp_date and $temp_arr[3]==$temp_hgb) {
			$id_ref->{$temp_arr[1]}=1;
		}
	}
	
	my $n_ids = scalar (keys %{$id_ref});
	print "mpv found $n_ids ids \n";
	return $id_ref;
}



sub find_plat   {

	#print "in find plat \n";
	my ($temp_date, $temp_hgb) = @_;
	my $id_ref;
	my $year = substr ($temp_date,0,4);
	open (PLAT, "W:/Users/Barak/maccabi_product_qa/find_id/cbc_2_find_id_plat.txt".".".$year);
	while (<PLAT>) {
		chomp;
		my @temp_arr = split " ";
		if ($temp_arr[2]==$temp_date and $temp_arr[3]==$temp_hgb) {
			$id_ref->{$temp_arr[1]}=1;
		}
	}
	
	my $n_ids = scalar (keys %{$id_ref});
	print "plat found $n_ids ids \n";
	return $id_ref;
}



sub find_wbc   {

	#print "in find wbc \n";
	my ($temp_date, $temp_hgb) = @_;
	my $id_ref;
	my $year = substr ($temp_date,0,4);
	open (WBC, "W:/Users/Barak/maccabi_product_qa/find_id/cbc_2_find_id_wbc.txt".".".$year);
	while (<WBC>) {
		chomp;
		my @temp_arr = split " ";
		if ($temp_arr[2]==$temp_date and $temp_arr[3]==$temp_hgb) {
			$id_ref->{$temp_arr[1]}=1;
		}
	}
	
	my $n_ids = scalar (keys %{$id_ref});
	print "wbc found $n_ids ids \n";
	return $id_ref;
}





sub copy_file_to_xl {
	my ($workbook_handle, $worksheet_name , $file_name, $format,$format1 ) = @_ ;
	
	my $my_worksheet = $workbook_handle->add_worksheet($worksheet_name);
	open (IN, $file_name) or die "cant ope n $file_name .... \n";
	my $row=0;
	while (<IN>) {
		chomp;
		my @temp_arr = split "\t";
		for my $col (0..$#temp_arr) {
			my $res = index ($temp_arr[$col] , "%");
			my $res1 = index ($temp_arr[$col] , "(");
			my $res2 = index ($temp_arr[$col] , "s%");
			if ($res==-1 or $res1!=-1 or $res2!=-1) {
				$my_worksheet->write($row, $col , $temp_arr[$col] , $format);
			} else {
				$my_worksheet->write_number($row, $col , $temp_arr[$col]/100 , $format1);
			}
		}
		$row++;
	}
	
	print "finish copy file:$file_name into worksheet $worksheet_name \n";
}



sub run_cmd {
	my ($command) = @_ ;
	
	#print STDERR "Running \'$command\'\n" ;
	(system($command) == 0 or die "\'$command\' Failed" ) ;
	
	return ;
}	



sub print_r  {
	my ($score_fname, $rfname , $my_dir) = @_;

	open (OUT, ">".$my_dir.$rfname);
	
	
print OUT "library(gplots)"."\n";
print OUT "library(ggplot2)"."\n";
print OUT "library(gridExtra)"."\n";
print OUT "\n";

print OUT "score_file <- read.delim(\"".$my_dir.$score_fname."\",header = FALSE);"."\n";
print OUT "gender_list<- unique(score_file\$V1)"."\n";
print OUT "age_bin_list<- unique(score_file\$V2)"."\n";
print OUT "\n";
print OUT "for (temp_gender in gender_list)  {"."\n";
print OUT "      for (temp_age_bin in age_bin_list)  {"."\n";
print OUT "        x1 <- score_file[ score_file\$V1==temp_gender & score_file\$V2 == temp_age_bin, ]  "."\n";
print OUT "\n";        
print OUT "        count_scores <- nrow(x1);"."\n";
print OUT "        min_min = 0"."\n";
print OUT "        max_max = 100"."\n";
print OUT "\n";        
print OUT "        if (count_scores>3)  {"."\n";
print OUT "\n";          
print OUT "          print(temp_gender);"."\n";
print OUT "          print(temp_age_bin);"."\n";
print OUT "\n";          
          #------------------------------------------
print OUT "          chart_name <- sprintf(\"%s_%s\",temp_gender,temp_age_bin);"."\n";
print OUT "          print (chart_name);"."\n";
print OUT "          g <- ggplot(x1, aes(V3, fill=V4))+geom_density(alpha=0.2)+ggtitle(chart_name)+theme(plot.title=element_text(size=25) , legend.text=element_text(size=25))+"."\n";
print OUT "            scale_x_continuous(limits=c(min_min,max_max) , breaks=seq(round(min_min,2), round(max_max,2) , by = round(((max_max-min_min)/5),2)     ))  "."\n";
print OUT "\n";          
          #------------------------------------------
          #file_name <- sprintf("W:/Users/Barak/maccabi_product_qa/%s_%s.png",temp_gender,temp_age_bin);
print OUT "          file_name <- sprintf(\"".$my_dir."output4_%s_%s.png\",temp_gender,temp_age_bin);"."\n";
print OUT "          print (file_name);"."\n";
print OUT "          ggsave(g , file=file_name, width=15,height=9 )"."\n";
print OUT "\n";          
print OUT "        }"."\n";
print OUT "      }"."\n";
print OUT "}	"."\n";

close(OUT);	
	
	
	
	

}











