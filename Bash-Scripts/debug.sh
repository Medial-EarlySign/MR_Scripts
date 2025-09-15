#!/bin/bash

pushd `which $1`/../..
${PERL_SCRIPTS}/create_cmake_files.pl --desired_sol_list=`python ${PYTHON_SCRIPTS=}/find_sln.py`
pushd CMakeBuild/Linux/Debug
time make -j 20
popd
cgdb Linux/Debug/$1
popd
