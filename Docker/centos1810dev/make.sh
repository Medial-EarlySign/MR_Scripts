#!/bin/bash

DATE_TAG="`date '+%Y%m%d'`"

#CONTAINER_NAME=centos1810dev
CONTAINER_NAME=${PWD##*/}

if [[ "$(docker images -q ${CONTAINER_NAME}:latest 2> /dev/null)" != "" ]]; then
  docker rmi ${CONTAINER_NAME}:latest
fi

docker build -t ${CONTAINER_NAME}:latest -t ${CONTAINER_NAME}:${DATE_TAG} . 

