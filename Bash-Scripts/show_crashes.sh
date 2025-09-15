#!/bin/bash
set -e
#declare -a StringArray=("/var/spool/abrt/" "/home/tmp/abrt/" "/var/tmp/abrt/" )
#for val in ${StringArray[@]}; do
#	if [ -d $val ]; then
#		sudo find $val -name cmdline -or -name pwd | egrep "ccpp" |  xargs -L1 sudo awk '{print FILENAME "\t" $0}' | awk -F"\t" '{ FN=$1; gsub(/\/cmdline|\/pwd/,"",FN); if (index($1, "/cmdline")>0) { split($2,a," "); ;d[FN]=$2; prog[FN]=a[1]; } else { p[FN]=$2; } if (NR==1) {print "########################################"} } END {num=0; for (i in d) { num=num+1; print "CRASH " num ": " i " Run From " p[i]; print "DEBUG COMMAND: sudo cgdb " prog[i] " " i "/coredump\nFULL RUN COMMAND: " d[i] ; print "########################################" } }'
#	fi
#done

sudo mkdir -p /var/crash_open
echo "To debug please select file:"
echo "######################"
ls -t -1 /var/crash | awk 'NR<=5 {print NR " <=> " $0; print "######################" }'
read -p "select number: " num

set -x
fname=$(ls -t -1 /var/crash | awk -v sel=$num 'NR==sel')
echo "selected: $num <=> $fname"
if [ ! -d /var/crash_open/$fname ]; then
	sudo apport-unpack /var/crash/$fname /var/crash_open/$fname
fi

echo "sudo cgdb $(cat /var/crash_open/${fname}/ExecutablePath) /var/crash_open/${fname}/CoreDump"
sudo cgdb $(cat /var/crash_open/${fname}/ExecutablePath) /var/crash_open/${fname}/CoreDump
