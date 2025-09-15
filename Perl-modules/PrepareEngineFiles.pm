# Read Analysis (base + raw) files and prepare for input to Study-Performance-System.

package PrepareEngineFiles ;
use Exporter qw(import) ;

our @EXPORT_OK = qw(rfgbm_prepare_engine_files) ;

sub rfgbm_prepare_engine_files {

	my $setup_file = shift @_ ;
	my $dir = shift @_ ;
	my $MAX_SDVS = (@_) ? (shift @_) : 7 ;
	
	my @test_names = ("RBC","WBC","MPV","Hemoglobin","Hematocrit","MCV","MCH","MCHC-M","RDW","Platelets","Eosinophils #","Neutrophils %",
					  "Monocytes %","Eosinophils %","Basophils %","Neutrophils #","Monocytes #","Basophils #","Lymphocytes %","Lymphocytes #") ;
	my %test_cols = map {($test_names[$_] => $_ + 1)} (0..$#test_names) ;
				
	# Copy instructions file
	my @entries = qw/Features Extra menParams menLM menRF menGBM menComb womenParams womenLM womenRF womenGBM womenComb/ ;
	my %entries = map {($_ => 1)} @entries ;

	open (IN,$setup_file) or die "Cannot open $setup_file for reading" ;

	my %files ;
	while (<IN>) {
		chomp ;
		my ($type,$name) = split ;
		die "Unknown entry $type" unless (exists $entries{$type}) ;
		$files{$type} = $name ;
	}
	close IN ;

	map {die "File for $_ is missing" if (!exists $files{$_})} @entries ;
			
	# Copy ...
	system("cp $files{Extra} $dir/extra_params.txt")==0 or die "Cannot copy $files{Extra}" ;
	system("cp $files{menLM} $dir/men_lm_params.bin")==0 or die "Cannot copy $files{MenLM}" ;
	system("cp $files{menRF} $dir/men_rf_model")==0 or die "Cannot copy $files{MenRF}" ;
	system("cp $files{menGBM} $dir/men_gbm_model")==0 or die "Cannot copy $files{MenGBM}" ;
	system("cp $files{menComb} $dir/men_comb_params")==0 or die "Cannot copy $files{MenComb}" ;
	system("cp $files{womenLM} $dir/women_lm_params.bin")==0 or die "Cannot copy $files{WomenLM}" ;
	system("cp $files{womenRF} $dir/women_rf_model")==0 or die "Cannot copy $files{WomenRF}" ;
	system("cp $files{womenGBM} $dir/women_gbm_model")==0 or die "Cannot copy $files{WomenGBM}" ;
	system("cp $files{womenComb} $dir/women_comb_params")==0 or die "Cannot copy $files{WomenComb}" ;

	# Read Features
	my $file = $files{Features} ;
	open (FTR,$file) or die "Cannot open $file for reading" ;

	my @features ;
	while (<FTR>) {
		chomp ;
		my ($var,$name) = split ;
		$name = $1 if ($name =~/(\S+)_Current/) ;
		$name =~  s/_/ /g ;
		push @features, $name ;
	}
	close FTR ;

	# Read Param
	$file = $files{menParams} ;
	my $men_data = read_file($file) ;

	$file = $files{womenParams} ;
	my $women_data = read_file($file) ;

	open (OUT,">$dir/codes.txt") or die "Cannot open codes.txt" ;

	for my $i (0..$#features) {
		my $id = (exists $test_cols{$features[$i]}) ? $test_cols{$features[$i]} : -1 ;
		my @out = ($id,$features[$i]) ;
		push @out, map {$men_data->[$i]->{$_}} qw/common min max/ ;
		push @out, map {$women_data->[$i]->{$_}} qw/common min max/ ;
		my $out = join "\t",@out ;
		print OUT "$out\n" ;
	}
}

###############################################################

sub read_file {
	my $name = shift @_ ;
	open (IN,$name) or die "Cannot open $name for reading" ;
	
	my @data ;
	while (<IN>) {
		chomp ;
		if (/Common (\d+) (\S+)/) {
			$data[$1]->{common} = $2 ;
		} elsif (/Moments (\d+) (\S+) (\S+)/) {
			my ($i,$mean,$sdv) = ($1,$2,$3) ;
			$data[$i]->{min} = $mean - $MAX_SDVS * $sdv ;
			$data[$i]->{min} = 0 if ($data[$i]->{min} < 0 and $i < 60 and $i%3 == 0) ;
			$data[$i]->{max} = $mean + $MAX_SDVS * $sdv ;
		}
	}
	close IN ;
	
	return \@data ;
}