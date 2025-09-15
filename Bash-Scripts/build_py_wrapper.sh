#!/bin/bash
if [ -z "${MR_ROOT}" ]; then
	source /nas1/UsersData/${USER%-*}/MR/Projects/Scripts/Bash-Scripts/startup.sh
fi

pushd ${MR_ROOT}/Libs/Internal/MedPyExport/generate_binding
# python_env python3x - not needed anymore. part of startup script
./make-simple.sh
PY_VERSION=$(python --version | awk '{print $2}' | awk -F. '{print $1 $2}')
pushd Release/medial-python${PY_VERSION}/

tar -cjSvf /server/Linux/${USER%-*}/PY.tar.bz2 *.py *.so

popd
popd


echo "The files are in: /server/Linux/${USER%-*}/PY.tar.bz2"
