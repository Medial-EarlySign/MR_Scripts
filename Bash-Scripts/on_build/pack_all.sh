#!/bin/bash
source /etc/profile.d/startup.sh
${0%/*}/build.sh 1
pack_etl.sh
pack_libs.sh
pack_scripts.sh
build_py_wrapper.sh

tar cfv /nas1/Work/Users/Git/mes_full.tar -C ${0%/*}/../usefull  medial_earlysign_setup.sh -C /server/Linux/${USER%-*} libs.tar.bz2 PY.tar.bz2 scripts.tar.bz2 ETL.tar.bz2 -C /nas1/UsersData/git/MR/Tools/AllTools/Linux/Release bin_apps.x86-64.tar.bz2
echo "full package in /nas1/Work/Users/Git/mes_full.tar"