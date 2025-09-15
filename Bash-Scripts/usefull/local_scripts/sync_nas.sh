#!/bin/bash
#rsync --exclude-from=/home/alon-internal/scripts/exclude.no_git.list -rlt --progress /nas1/UsersData/alon/MR/ /home/alon-internal/MR_ROOT

rsync -rlth --progress --delete --exclude-from=${0%/*}/exclude.list /home/alon-internal/MR_ROOT/ /nas1/UsersData/alon/MR/
