#!/usr/bin/env perl 
use strict(vars) ;

die "Usage: get_brouchure_info.pl ScoreLabelFile\n" if (@ARGV != 1) ;

my $file = shift @ARGV ;
open (IN,$file) or die "Cannot read $file" ;

my @data ;
while (<IN>) {
	chomp ;
	my ($score,$label) = split ;
	push @data,[$score,$label] ;
}

# Get ROC
my @sorted = sort {$b->[0] <=> $a->[0]} @data ;
my @num ;
map {$num[$_->[1]]++} @sorted ;
my ($nneg,$npos)=  @num ;

my ($fp,$tp) = (0,0) ;
my @fpr = (0) ;
my @tpr = (0) ;
my @score = (0) ;
foreach my $rec(@sorted) {
	if ($rec->[1] == 1) {
		$tp ++ ;
	} else {
		$fp ++ ;
		push @fpr,$fp/$nneg ;
		push @tpr,$tp/$npos ;
		push @score,$rec->[0] ;
	}
}

my $nroc = scalar @fpr ;
my @roc = map {[$fpr[$_],$tpr[$_]]} (0..$#fpr) ;
my %spec2score = map {(100*(1-$fpr[$_]) => $score[$_])} (0..$#fpr) ;

my @ppos ;
foreach my $i (1..$nroc-1) {
	if ($roc[$i]->[1] != $roc[$i-1]->[1]) {
		my $diff = int($npos * ($roc[$i]->[1] - $roc[$i-1]->[1]) + 0.5) ;
		push @ppos,(($i-1)x$diff) ;
	}
}

die "Mismatch ! ($npos vs ".(scalar @ppos).")" if ($npos != scalar @ppos) ;

my $bin = 15 ;
print "Lift\tMean Spec/Sens/OR/Score\tUpper Spec/Sens/OR/Score\tLower Spec/Sens/OR/Score\n" ;
for my $lift (1,2,5,10,30) {
	my ($diff,$opt);
	
	for my $i (0..$npos-$bin-1) {		
		my @roc1 = @{$roc[$ppos[$i]]} ;
		my @roc2 = @{$roc[$ppos[$i+$bin]]} ;
	
		my $nposi = ($roc2[1] - $roc1[1]) * $npos ;
		my $nnegi = ($roc2[0] - $roc1[0]) * $nneg ;
		my $lifti = ($nposi/($nposi+$nnegi)) / ($npos/($npos+$nneg)) ;
		
		if ((! defined $diff) or (abs($lifti - $lift) < abs($diff))) {
			$diff = ($lifti - $lift) ;
			$opt = $i ;
		}
	}
	
	my $lifti = $lift + $diff ;
	printf "%.2f",$lifti ;
	
	my @roci = @{$roc[$ppos[int($opt+$bin/2)]]} ;
	my $sens = 100*$roci[1] ;
	my $spec = 100*(1-$roci[0]) ;
	my $nposp = $roci[1] * $npos ;
	my $nnegp = $roci[0] * $nneg ; 
	my $or = ($nposp/$nnegp)/(($npos-$nposp)/($nneg-$nnegp)) ; 
	
	my $score = get_score($spec,\%spec2score) ;
	printf "\t%.2f/%.2f/%.2f/%.2f",$spec,$sens,$or,$score ; 

	@roci = @{$roc[$ppos[$opt]]} ;
	$sens = 100*$roci[1] ;
	$spec = 100*(1-$roci[0]) ;
	$nposp = $roci[1] * $npos ;
	$nnegp = $roci[0] * $nneg ;  
	$or = ($nposp/$nnegp)/(($npos-$nposp)/($nneg-$nnegp)) ;
	
	$score = get_score($spec,\%spec2score) ;
	printf "\t%.2f/%.2f/%.2f/%.2f",$spec,$sens,$or,$score ; 
	
	@roci = @{$roc[$ppos[$opt+$bin]]} ;
	$sens = 100*$roci[1] ;
	$spec = 100*(1-$roci[0]) ;
	$nposp = $roci[1] * $npos ;
	$nnegp = $roci[0] * $nneg ; 
	$or = ($nposp/$nnegp)/(($npos-$nposp)/($nneg-$nnegp)) ;
	
	$score = get_score($spec,\%spec2score) ;
	printf "\t%.2f/%.2f/%.2f/%.2f\n",$spec,$sens,$or,$score ; 
}
		
		
sub get_score {
	my ($spec,$spec2score) = @_ ;
	
	return $spec2score->{$spec} if (exists $spec2score->{spec}) ;
	
	my @specs = sort {$a<=>$b} keys %$spec2score ;
	for my $i (1..$#specs) {
		if ($specs[$i] > $spec) {
			die "Cannot handle $spec" if ($specs[$i-1] > $spec) ;
		
			my ($x0,$x1) = $specs[$i-1],$specs[$i] ;
			my ($y0,$y1) = ($spec2score->{$x0},$spec2score->{$x1}) ;
		
			my $a = ($y1-$y0)/($x1-$x0) ;
			return $y0 + ($spec - $x0)*$a ;
		}
	}
	
	die "Cannot handle $spec" ;
}
