#!/bin/bash
echo "startup script, systemwide, at: /server/Linux/config/startup.sh "
#if test -f ~/.bashrc; then
#    echo "Found .bashrc, loading"
#    source ~/.bashrc
#fi

export PS1='$(whoami)@$(hostname):$(pwd)$ '

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
mkcd () { mkdir -p "$@" && cd "$@"; } 

alias smake_cln='pushd CMakeBuild/Linux/Release && make clean ; popd ; pushd CMakeBuild/Linux/Debug && make clean ; popd'
#alias Flow_mhs='Flow --rep /home/Repositories/MHS/build_Feb2016_Mode_3/maccabi.repository'
#alias Flowt='Flow --rep /home/Repositories/THIN/thin_final/thin.repository'
#alias Flow_mimic='Flow --rep /home/Repositories/MIMIC/Mimic3/mimic3.repository'
#alias Flow_rambam='Flow --rep /home/Repositories/Rambam/rambam_nov2018_fixed/rambam.repository'
#alias Flowk='Flow --rep /home/Repositories/KPNW/kpnw_jun19/kpnw.repository'
#alias thonny='/home/apps/thonny/bin/thonny'
#alias signal_dep='/server/UsersData/${USER%-*}/MR/Tools/SignalsDependencies/Linux/Release/SignalsDependencies'


export WORK_ROOT=/server/Work/Users/${USER%-*}

export MR_ROOT=/nas1/UsersData/${USER%-*}/MR
#export MEDIAL_LIBS=${MR_ROOT}/Libs
#export MEDIAL_EXTERNAL_LIBS=${MR_ROOT}/Libs/External
#export EXEC_DIR=${MR_ROOT}/LinuxExecs
export PERL_SCRIPTS=${MR_ROOT}/Projects/Scripts/Perl-scripts
export PYTHON_SCRIPTS=${MR_ROOT}/Projects/Scripts/Python-scripts
export BASH_SCRIPTS=${MR_ROOT}/Projects/Scripts/Bash-Scripts
export MR_LIBS_NAME="Logger.lib;InfraMed.lib;MedStat.lib;MedUtils.lib;MedAlgo.lib;MedProcessTools.lib;QRF.lib;TQRF.lib;Mars.lib;micNet.lib;MedTime.lib;MedSparseMat.lib;MedEmbed.lib;MedIO.lib;SerializableObject.lib;MedSplit.lib;MedMat.lib;MedPlotly.lib"
export ETL_LIB_PATH=${MR_ROOT}/Tools/RepoLoadUtils/common
export AUTOTEST_LIB=${MR_ROOT}/Tools/AutoValidation/kits
export PYTHONPATH=${ETL_LIB_PATH}

export PATH=$PATH:${PERL_SCRIPTS}:${PYTHON_SCRIPTS}:${BASH_SCRIPTS}:${MR_ROOT}/Tools/AllTools/Linux/Release

alias smake_rel='${BASH_SCRIPTS}/smake_rel.sh'
alias smake_dbg='${BASH_SCRIPTS}/smake_dbg.sh'
alias smake='${BASH_SCRIPTS}/smake.sh'

#alias create_cmake_files='${PERL_SCRIPTS}/create_cmake_files.pl --desired_sol_list=`python ${PYTHON_SCRIPTS=}/find_sln.py`'
alias sort="sort -S 80%"
shopt -s direxpand
alias ll='ls -l --color=auto -h'
complete -W "\`grep -oE '^[a-zA-Z0-9_-]+:([^=]|$)' Makefile | sed 's/[^a-zA-Z0-9_-]*$//'\`" make
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export work=/server/Work/Users/${USER%-*}

#export CPATH=/server/Work/Libs/Boost/latest
#export CPLUS_INCLUDE_PATH=/server/Work/Libs/Boost/latest
#export C_INCLUDE_PATH=/server/Work/Libs/Boost/latest
#export LIBRARY_PATH=/server/Work/Libs/Boost/latest/installation/lib
export LD_LIBRARY_PATH=/server/Work/Libs/Boost/boost_1_85_0/installation/lib
export HOME=/server/Linux/${USER%-*}
export XAUTHORITY=/server/Linux/${USER}/.Xauthority

python_env() {
	PY_ENV=${1-list}
	if [ $PY_ENV == "list" ]; then
		echo "List of environments:"
		ls -l /nas1/Work/python-env | egrep "^d" | awk '{print $NF}'
	else
		source /nas1/Work/python-env/${PY_ENV}/bin/activate
	fi
}

complete -F python_env python_env
complete -W "\`ls -l /nas1/Work/python-env | egrep '^d' | awk '{print \$NF}'  \`" python_env

python_local_env() {
	PY_ENV=${1-list}
	if [ $PY_ENV == "list" ]; then
		echo "List of environments:"
		ls -l /home/Work/python-env | egrep "^d" | awk '{print $NF}'
	else
		source /home/Work/python-env/${PY_ENV}/bin/activate
	fi
}

complete -F python_local_env python_local_env
complete -W "\`ls -l /home/Work/python-env | egrep '^d' | awk '{print \$NF}'  \`" python_local_env

source /nas1/Work/python-env/python312/bin/activate
