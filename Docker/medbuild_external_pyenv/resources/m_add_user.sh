#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 [user] [pass]"
  exit 0
fi

useradd $1 -m
echo "$2" | passwd $1 --stdin

JUP_DIR="`source /opt/medial/dist/enable && echo $JUPYTER_RUNTIME_DIR`"
NB_DIR="/nas1/Work/Shared/notebooks"

mkdir -p $NB_DIR/$1
chown -R $1.$1 $NB_DIR/$1
mkdir -p $JUP_DIR
chmod -R 777 $JUP_DIR
echo "source /opt/medial/python36/enable" >> /home/$1/.bashrc
echo "source /opt/medial/python36/enable" >> /home/$1/.bash_profile
#/opt/medial/python36/usr/bin/jupyterhub_init_d_script start
