#/bin/bash

# generic image making script

export TS=`date +"%Y%m%d"`
export DN=`pwd | rev | cut -d/ -f1 | rev`

if [[ ! "$(docker images -q ${DN}:latest 2> /dev/null)" == "" ]]; then
  docker rmi ${DN}:latest
fi
if [[ ! "$(docker images -q ${DN}:${TS} 2> /dev/null)" == "" ]]; then
  docker rmi ${DN}:${TS}
fi

echo "(II) Building tags ${DN}:latest , ${DN}:${TS}"

docker build . -t ${DN}:latest -t ${DN}:${TS}
