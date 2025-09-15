#!/bin/bash
MAT=$1

if [ -z ${MAT} ]; then
	echo "Please provide matrix path"
	exit -1
fi

cat ${MAT} | awk -F, '{ if (NR==1) { for (i=7;i<=NF; i++) {h[i]=$i; msn[i]=0; c[i]=0;} } else { for (i=7;i<=NF;i++) { if ($i<=-65330) {msn[i]+=1;} else {c[i]+=1; s[i]+=$i; if (c[i]==1 || min[i]>$i) {min[i]=$i} if (c[i]==1 || max[i]<$i) {max[i]=$i}}  } } } END { for (i in h) { if (c[i] ==0) { print h[i] "\t" "ALL_MISSSINGS" } else { print h[i] "\t" s[i]/c[i] "\t" c[i] "\t" msn[i] "\t[" min[i] " - " max[i] "]" } }}' | sort -S80% -k1