#!/bin/bash

#curr_date=`ssh node-01 date -u +"%s"`
echo "Setting time to $curr_date"

for i in {1..5}
do
   ssh -x node-0$i 'sudo /usr/sbin/ntpdate 192.168.1.2' &
done
wait