#!/bin/bash

curr_date=`ssh node-01 date -u +"%s"`
echo "Setting time to $curr_date"

for i in {1..5}
do
   ssh -t node-0$i 'sudo date -s @'$curr_date &
done
wait