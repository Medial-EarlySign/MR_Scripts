#!/bin/bash
if [ ${USER} == "root" ] || [ ${USER} == "local" ] || [ ${USER} == "earlysign" ] ; then
#	source /nas1/UsersData/${USER%-*}/MR/Projects/Scripts/Bash-Scripts/startup.sh
	export LOCAACC=1
	return
fi
#
alias ll='ls -l'
alias rm='rm -i'
alias mv='mv -i'

export MR_ROOT=/nas1/UsersData/${USER%-*}/MR
#export MR_ROOT=${HOME}/MR_ROOT
export ETL_LIB_PATH=${MR_ROOT}/Tools/RepoLoadUtils/common
export AUTOTEST_LIB=${MR_ROOT}/Tools/AutoValidation/kits
export PYTHONPATH=${ETL_LIB_PATH}:${MR_ROOT}/Libs/Internal/MedPyExport/generate_binding/Release/medial-python310

export CPATH=/server/Work/Libs/Boost/boost_1_85_0
export CPLUS_INCLUDE_PATH=${CPATH}
export C_INCLUDE_PATH=${CPATH}
export LIBRARY_PATH=${CPATH}/installation/lib
export LD_LIBRARY_PATH=${CPATH}/installation/lib

export PERL_SCRIPTS=${MR_ROOT}/Projects/Scripts/Perl-scripts
export PYTHON_SCRIPTS=${MR_ROOT}/Projects/Scripts/Python-scripts
export BASH_SCRIPTS=${MR_ROOT}/Projects/Scripts/Bash-scripts

export PATH=$PATH:${MR_ROOT}/Tools/AllTools/Linux/Release:${PERL_SCRIPTS}:${PYTHON_SCRIPTS}:${BASH_SCRIPTS}

source /nas1/Work/python-env/python310/bin/activate
