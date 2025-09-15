#!/bin/bash
for i in {1..5}
do
	echo "Node-0"$i":"
	ssh -x node-0$i "sudo lsblk -o NAME,FSTYPE,TYPE,MOUNTPOINT,LABEL,UUID,MODEL,SERIAL,SIZE"
done