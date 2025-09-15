#!/bin/bash

for i in {1..5}
do
	echo "Node-0"$i":"
ssh node-0${i} 'sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y'
done

ssh gitlab_server 'sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y'
