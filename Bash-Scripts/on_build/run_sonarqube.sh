#!/bin/bash
source /nas1/UsersData/${USER%-*}/MR/Projects/Scripts/Bash-Scripts/startup.sh
set -e

IS_RUNNING=$(sudo docker ps | grep sonarqube | wc -l)
if [ $IS_RUNNING -lt 1 ]; then
	echo "Starting sonarqube docker"
	sudo docker start sonarqube
fi

export SONAR_SCANNER_VERSION=5.0.1.3006
mkdir -p $HOME/.sonar
export SONAR_SCANNER_HOME=$HOME/.sonar/sonar-scanner-$SONAR_SCANNER_VERSION-linux

if [ ! -d ${SONAR_SCANNER_HOME} ]; then
	cp /nas1/Work/docker_images/sonarqube/sast/sonar-scanner-${SONAR_SCANNER_VERSION}-linux $HOME/.sonar/ -R
fi
export PATH=$PATH:/nas1/Work/docker_images/sonarqube/sast/build-wrapper-linux-x86/:${SONAR_SCANNER_HOME}/bin
export SONAR_SCANNER_OPTS="-server"
export SONAR_TOKEN=sqp_8f8f466aef79b55433bb6ddf11f5cc84c0d256f3
export LD_LIBRARY_PATH=/server/Work/Libs/Boost/boost_1_67_0-fPIC.ubuntu/installation/lib
export LIBRARY_PATH=/server/Work/Libs/Boost/boost_1_67_0-fPIC.ubuntu/installation/lib

VERSION_ID=$(date +'Build_%Y%m%d_%H%M')
pushd $MR_ROOT/Libs/Internal/AlgoMarker
new_create_cmake_files.pl --new_compiler 1
cd LinuxSharedLib
build-wrapper-linux-x86-64 --out-dir /tmp/bw-output ./so_compilation_ubuntu
popd
pushd $MR_ROOT/Libs/Internal
sonar-scanner -Dsonar.host.url=http://`hostname`:7200 -Dsonar.projectKey=MedialInfra -Dsonar.token=sqp_8f8f466aef79b55433bb6ddf11f5cc84c0d256f3 -Dsonar.projectVersion="${VERSION_ID}" -Dsonar.sources=. -Dsonar.cfamily.build-wrapper-output=/tmp/bw-output
popd