#!/bin/bash

#sudo su earlysign
if [ $USER != "earlysign" ]; then
	echo "Please use earlysign account":
	echo -e "executing:\nsudo su - earlysign"
	echo -e "Please run those commands:n\n################################"
	echo "cd ~/scripts"
	echo "./update_os.sh"
	echo "##################################################"
	sudo su - earlysign
	exit -1
fi
for i in {1..4}
do
	echo $i
	ssh 192.168.2.10${i} 'sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y'
done

