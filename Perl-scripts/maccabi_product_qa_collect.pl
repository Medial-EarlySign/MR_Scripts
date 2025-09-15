#!/cygdrive/w/Applications/Perl64/bin/cygwin_perl
use strict ;
use Spreadsheet::writeExcel;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;


my $run_dates;
#$run_dates->{'2015-OCT-11'}=1;
#$run_dates->{'2015-OCT-12'}=2;
#$run_dates->{'2015-OCT-13'}=3;
#$run_dates->{'2015-OCT-14'}=4;
#$run_dates->{'2015-OCT-15'}=5;
#$run_dates->{'2015-Oct-18'}=6;
#$run_dates->{'2015-Oct-19'}=7;
#$run_dates->{'2015-Oct-20'}=8;
#$run_dates->{'2015-Oct-21'}=9;
#$run_dates->{'2015-Oct-25'}=10;
#$run_dates->{'2015-Oct-26'}=11;
#$run_dates->{'2015-Oct-27'}=12;
#$run_dates->{'2015-Oct-28'}=13;
#$run_dates->{'2015-Oct-29'}=14;
#$run_dates->{'2015-Nov-01'}=15;
#$run_dates->{'2015-Nov-02'}=16;
#$run_dates->{'2015-Nov-03'}=17;
#$run_dates->{'2015-Nov-04'}=18;
#$run_dates->{'2015-Nov-05'}=19;



my $in_dir = "P:/Maccabi_Production/";
my $prefix;
opendir (D, $in_dir) or die ("cant open directory $in_dir  \n");
while (my $f=readdir(D)) {
	my $pre = substr($f , 0,4);
	next if ($pre ne '2015');
	print $f."\t".convert_date($f)."\n";
	$run_dates->{$f}=convert_date($f);
}
closedir(D);



my $main_dir = "W:/Users/Barak/maccabi_product_qa/";
my $fname = "output3_data_analysis.txt";
my $hash_data;
my $hash_sumaary;
my $date_params;
for my $temp_date (keys  %{$run_dates}) {
	my $fname1 = $main_dir.$temp_date."/".$fname;
	print $fname1."\n";
	my $counter=0;
	open (IN, $fname1) or die "cant open $fname1 \n";
	while (<IN>) {
		chomp;
		my @temp_arr = split "\t";
		
		if ($counter==0) {
			$counter++;
			next;
		}
		my $source = $temp_arr[0];
		my $param_name = $temp_arr[1];
		my $param_val = $temp_arr[2];
		my $val1 = $temp_arr[3];
		my $val2 = $temp_arr[4];
		
		if ($param_name eq "param_outliers count, outlier(min,max,total) %") {
			push @{$hash_data->{$source}->{$param_name}->{$param_val}->{'val1'}} , $val1;
			push @{$hash_data->{$source}->{$param_name}->{$param_val}->{'val2'}} , $val2*$val1/100;
		} elsif ($param_name eq "num_of_blood_date_with_cbc_code" or $param_name eq "num_of_ids_with_blood_dates_in_gap") {
			push @{$hash_data->{$source}->{$param_name}->{$param_val}->{'val1'}} , $val1;
			push @{$hash_data->{$source}->{$param_name}->{$param_val}->{'val2'}} , $val1/($val2/100);		
		}
		else {
			push @{$hash_data->{$source}->{$param_name}->{$param_val}->{'val1'}} , $val1;
			push @{$hash_data->{$source}->{$param_name}->{$param_val}->{'val2'}} , $val2;		
		}
			
			
		$hash_sumaary->{$source}->{$param_name}+=$val1;
		$counter++;
	}
	close(IN);
}

my $fname_out = ">collect_data.txt";
open (OUT ,$fname_out) or die "cant open $fname_out \n";
for my $source (sort {$a<=>$b} keys %{$hash_data})  {
	for my $param_name (sort {$a<=>$b} keys %{$hash_data->{$source} })  {
		next if ($param_name eq "gender_age_bin_score_avg_sdv_n");
		next if ($param_name eq "multiple_values (id,date,param)");
		
		my $param_name_total =0;
		for my $param_val (sort {$a<=>$b} keys %{$hash_data->{$source}->{$param_name} })  {

			my $val1 = \@{$hash_data->{$source}->{$param_name}->{$param_val}->{'val1'}};
			my $val2 = \@{$hash_data->{$source}->{$param_name}->{$param_val}->{'val2'}};
			my ($avg, $sdv, $n , $sum) = get_stats($val1);
			my ($avg2, $sdv2, $n2 , $sum2) = get_stats($val2);
			
			print OUT  join ("\t", $source , $param_name , $param_val)."\t";
			my $ratio;
			
			if ($param_name eq "param_outliers count, outlier(min,max,total) %") {
				$ratio = (int(10000*($sum2/$sum)))/100;
			#} elsif ($param_name eq "num_of_blood_date_with_cbc_code") {
			} elsif  ($param_name eq "num_of_blood_date_with_cbc_code" or $param_name eq "num_of_ids_with_blood_dates_in_gap") {			
				$ratio = (int(10000*($sum/$sum2)))/100;
			} else {
				$ratio = (int(10000*($sum/$hash_sumaary->{$source}->{$param_name})))/100;
			}
			print OUT  join ("\t", $sum,  $ratio."%" )."\n";			
		}
		print OUT  join ("\t", $source , $param_name , "total",$hash_sumaary->{$source}->{$param_name} )."\n";
	}
}




$fname = "gender_age_score_files.txt";
my $fname_out = ">collect_gender_age_score_files.txt";
open (OUT_SCORES ,$fname_out) or die "cant open $fname_out \n";
my $hash_gender_age_score;
for my $temp_date (keys  %{$run_dates}) {
	my $fname1 = $main_dir.$temp_date."/".$fname;
	print $fname1."\n";
	my $counter=0;
	open (IN, $fname1) or die "cant open $fname1 \n";
	while (<IN>) {
		chomp;
		my @temp_arr = split "\t";
		print OUT_SCORES join ("\t", @temp_arr)."\n";
		
		my $gender = $temp_arr[0];
		my $age = $temp_arr[1];
		my $val = $temp_arr[2];
		push @{$hash_gender_age_score->{$gender}->{$age}} , $val;
	}
}

for my $gender (sort {$a<=>$b} keys %{$hash_gender_age_score})   {
	for my $age (sort {$a<=>$b} keys %{$hash_gender_age_score->{$gender} })   {
		my @temp_arr = @{$hash_gender_age_score->{$gender}->{$age}};
		my ($avg, $sdv, $n , $sum) = get_stats(\@temp_arr);
		print OUT join ("\t", "score_files", "gender_age_bin_score_avg_sdv_n", $gender."_".$age , $avg , $sdv , $n )."\n";
	}
}


close(OUT);
close(OUT_SCORES);


$fname = "output5_info_file.txt";
my $fname_out = ">collect_output5_info_file.txt";
my $info_hash;
open (OUT_INFO ,$fname_out) or die "cant open $fname_out \n";
print OUT_INFO join ("\t", "Date", "Count_Colon_Scores", "Count_99_6", "Count_99_6_ratio", "Count_99_6_hgb", "Count_99","Count_99_ratio" ,"Count_99_hgb")."\n";



for my $temp_date ( sort { $run_dates->{$a}<=>$run_dates->{$b} } keys  %{$run_dates}) {
	my $fname1 = $main_dir.$temp_date."/".$fname;
	print $fname1."\n";
	my $counter=0;
	open (IN, $fname1) or die "cant open $fname1 \n";
	print OUT_INFO $temp_date."\t";
	while (<IN>) {
		chomp;
		my @temp_arr = split "\t";
		my $param_name = $temp_arr[0];
		print OUT_INFO $temp_arr[1]."\t";
		$info_hash->{$param_name}+=$temp_arr[1];
	}
	print OUT_INFO "\n";
}
print OUT_INFO "\n";

my $count_99_6_ratio = (int(10000*($info_hash->{'limit_99.6'}/$info_hash->{'colon_score'})))/100;
my $count_99_ratio = (int(10000*($info_hash->{'limit_99'}/$info_hash->{'colon_score'})))/100;
print OUT_INFO join ("\t", "Total",$info_hash->{'colon_score'}, $info_hash->{'limit_99.6'}, $count_99_6_ratio."%",$info_hash->{'limit_99.6_hgb'}, $info_hash->{'limit_99'},$count_99_ratio."%" ,$info_hash->{'limit_99_hgb'})."\n";
close(OUT_INFO);








#====================================  compare to ref ======================================


compare_to_ref:

print "compare_to_ref\n";


my $orig_file = "collect_data.txt";
my $ref_dir = "W:/Users/Barak/maccabi_product_qa/2008-JAN-01";
my $ref_file = $ref_dir."/"."output3_data_analysis.txt";
my $out_file = ">collect_data_with_ref.txt";

print  "ref : $ref_file  \n";

open (IN , $orig_file) or die "cant open file :$orig_file ";
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
my $orig_hash = get_analysis_ref($orig_file);


for my $temp_source (sort {$a<=>$b} keys %{$orig_hash} ) {
	for my $param_name (sort {$a<=>$b} keys %{$orig_hash->{$temp_source} } ) {
		for my $key1 (sort {$a<=>$b}  keys %{$orig_hash->{$temp_source}->{$param_name} } ) {
		
			print OUT join ("\t",$temp_source,  $param_name, $key1)."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val1'}."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val2'}."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val3'}."\t";
			print OUT $orig_hash->{$temp_source}->{$param_name}->{$key1}->{'val4'}."\t";
			
			if (exists $ref_hash->{$temp_source}->{$param_name}->{$key1}) {
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val1'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val2'}."\t";
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val3'}."\t";
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
				print OUT $ref_hash->{$temp_source}->{$param_name}->{$key1}->{'val4'};						
				print OUT "\n";
			}
		}
	}
}
close(OUT);
print "step 9\n";


open (OUT, ">collect_gender_age_score_files_ref.txt") or die "cant open collect_gender_age_score_files_ref.txt";
open (IN_ORIG, "collect_gender_age_score_files.txt") or die "cant open collect_gender_age_score_files.txt";
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

print_r ("collect_gender_age_score_files_ref.txt", "age_gender_scores.r");

#my $r_script_dir = "U://Barak//r_scripts";
system("w://Applications/R/R-latest/bin/x64/R CMD BATCH --silent --no-timing  age_gender_scores.r R_StdErr ");

print "step 10\n";

#=============================================================================================


collect_files("output3_data_analysis_with_ref.txt","collect_output3_data_analysis_with_ref.txt") ;
collect_files("output7_over_limit_data1","collect_output7_over_limit_data1") ;
collect_files("output7_over_limit_data2","collect_output7_over_limit_data2") ;


print "step 11\n";

#==========================================  write XL ========================================

my $max_date;
for my $temp_run (sort {$run_dates->{$b}<=>$run_dates->{$a}} keys %{$run_dates})  {
	$max_date = $temp_run;
	last;
}

print $max_date."\n";


my $excel_name = "all_days_summary_".$max_date.".xls";
my $workbook_handle = Spreadsheet::WriteExcel->new($excel_name);
my $format = $workbook_handle->add_format();
$format->set_size(11);
$format->set_font('Arial');
$format->set_num_format('General');

my $format1 = $workbook_handle->add_format();
$format1->set_size(11);
$format1->set_font('Arial');
$format1->set_num_format('0.0%');


my $format2 = $workbook_handle->add_format();
$format2->set_bold();
$format2->set_size(11);
$format2->set_font('Arial');
$format2->set_num_format('General');


#my $info_worksheet = $workbook_handle->add_worksheet('info');
#my $row_counter=1;
#$info_worksheet->write(0, 0 , "run_dates" , $format1);
#for my $temp_run (sort {$run_dates->{$b}<=>$run_dates->{$a}} keys %{$run_dates})  {
	#$info_worksheet->write($row_counter, $0 , $temp_run , $format1);
	#$row_counter++;
#}



copy_file_to_xl ($workbook_handle, "info" , "collect_output5_info_file.txt",$format,$format1,$format2);
copy_file_to_xl ($workbook_handle, "stats_summary" , "collect_data_with_ref.txt",$format,$format1,$format2);
copy_file_to_xl ($workbook_handle, "stats_data" , "collect_output3_data_analysis_with_ref.txt",$format,$format1,$format2);
copy_file_to_xl ($workbook_handle, "positive_99_6" , "collect_output7_over_limit_data2",$format,$format1,$format2);
copy_file_to_xl ($workbook_handle, "positive_99" , "collect_output7_over_limit_data1",$format,$format1,$format2);


my $my_worksheet = $workbook_handle->add_worksheet('score_distributions');
system (" ls  | grep png > my_pics.txt ");
open (PICS , "my_pics.txt") or die "cant open my_pics.txt ";
my $count_row=3;
while (<PICS>) {
	chomp;
	my @arr = split "\t";
	my $pic_name = $arr[0];
	$my_worksheet->insert_image($count_row, 3 , $pic_name , 0, 0, 0.2,0.2);
	$count_row+=35;
}


$workbook_handle->close() or die "cant close file $! \n";


#=================================================================================================



exit;



sub get_stats {
	my ($arr_hash) = @_;
	
	my @temp_arr = @{$arr_hash};

	
	#for my $i (0..$#temp_arr) {
		#print $temp_arr[$i]."\n";
		#<STDIN>;
	#}
	
	my $n = scalar(@temp_arr);
	my $avg=0;
	my $sum=0;
	for my $i (0..$#temp_arr) {
		$sum+=$temp_arr[$i];
	}
	my $avg = $sum/$n;
	
	my $sdv=0;
	for my $i (0..$#temp_arr) {
		$sdv+=($temp_arr[$i]-$avg)*($temp_arr[$i]-$avg);
	}
	$sdv= sqrt($sdv/($n));
	
	return ($avg, $sdv, $n ,$sum);
}



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


sub print_r  {
	my ($score_fname, $rfname) = @_;

	open (OUT, ">".$rfname);
	
	
print OUT "library(gplots)"."\n";
print OUT "library(ggplot2)"."\n";
print OUT "library(gridExtra)"."\n";
print OUT "\n";

print OUT "score_file <- read.delim(\"".$score_fname."\",header = FALSE);"."\n";
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
print OUT "          file_name <- sprintf(\"output4_%s_%s.png\",temp_gender,temp_age_bin);"."\n";
print OUT "          print (file_name);"."\n";
print OUT "          ggsave(g , file=file_name, width=15,height=9 )"."\n";
print OUT "\n";          
print OUT "        }"."\n";
print OUT "      }"."\n";
print OUT "}	"."\n";

close(OUT);	
	
	
	
	

}


#collect_all_stats

sub collect_files {
	my ($fname_from , $fname_out) = @_;

	#$fname = "output3_data_analysis_with_ref.txt";
	#my $fname_out = ">collect_output3_data_analysis_with_ref.txt";
	open (OUT_STATS ,">".$fname_out) or die "cant open $fname_out \n";
	my $hash_gender_age_score;
	my $run_date=0;
	for my $temp_date (sort { $run_dates->{$a}<=>$run_dates->{$b} } keys  %{$run_dates}) {
		my $fname1 = $main_dir.$temp_date."/".$fname_from;
		print $fname1."\n";
		my $counter=0;
		open (IN, $fname1) or die "cant open $fname1 \n";
		while (<IN>) {
			chomp;
			my @temp_arr = split "\t";
			
			if ($run_date==0 and $counter==0) {
				print OUT_STATS join ("\t","run_date",  @temp_arr)."\n";
				$counter++;
				next;
			} elsif ($counter==0) {
				$counter++;
				next;
			}
			
			if ($#temp_arr>0) {
				print OUT_STATS join ("\t",$temp_date,  @temp_arr)."\n";
			} else {
				print OUT_STATS "\n";
			}
			$counter++;
		}
		print OUT_STATS "\n";
		print OUT_STATS "----------------------------------"."\n";
		print OUT_STATS "\n";
		$run_date++;
	}
	close(OUT_STATS);
}



sub copy_file_to_xl {
	my ($workbook_handle, $worksheet_name , $file_name, $format,$format1,$format2  ) = @_ ;
	
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


