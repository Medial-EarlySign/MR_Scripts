#!/bin/bash
if [ ${USER} != "root" ] && [ ${USER} != "local" ] && [ ${USER} != "earlysign" ] ; then
	source /server/UsersData/${USER%-*}/MR/Projects/Scripts/Bash-Scripts/startup.sh
fi
