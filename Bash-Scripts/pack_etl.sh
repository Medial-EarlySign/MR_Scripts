#!/bin/bash

tar -cjSvf /server/Linux/${USER%-*}/ETL.tar.bz2 -C $MR_ROOT/Tools --exclude "*.pyc" RepoLoadUtils/common

echo "The files are in: /server/Linux/${USER%-*}/ETL.tar.bz2"