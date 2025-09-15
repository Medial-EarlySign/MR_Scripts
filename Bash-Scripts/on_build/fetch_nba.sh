#!/bin/bash

echo "Upload to Maccabi"

ssh node-04 /nas1/UsersData/ron/MR/Projects/Scripts/Bash-Scripts/on_build/build.nba.sh

#copy to host folder
cp /drives/u/ron-internal/MR_git/Projects/Shared/nba/Linux/Release/nba_bin_apps.tar.gzip /drives/z/mhs_send

#mark the file ready to be send
touch /drives/z/prepare_send.txt

echo "Done"
