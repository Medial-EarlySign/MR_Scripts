#!/bin/bash
BASE_PATH=/earlysign
mkdir -p ${BASE_PATH}
mkdir -p ${BASE_PATH}/bins
mkdir -p ${BASE_PATH}/libs

cd $BASE_PATH
tar -xvf mes_full.tar

set -e
#Copy all files: bins, libs, PY, scripts, ETL
cd ${BASE_PATH}/libs; tar -xvf $BASE_PATH/libs.tar.bz2; tar -xvf $BASE_PATH/PY.tar.bz2

cd ${BASE_PATH}/bins; tar -xvf $BASE_PATH/bin_apps.x86-64.tar.bz2
cd ${BASE_PATH}; tar -xvf $BASE_PATH/scripts.tar.bz2; mv ${BASE_PATH}/Scripts ${BASE_PATH}/scripts
cd ${BASE_PATH}/scripts; tar -xvf $BASE_PATH/ETL.tar.bz2
mv ${BASE_PATH}/AutoValidation ${BASE_PATH}/scripts
mv ${BASE_PATH}/AlgoMarker_python_API ${BASE_PATH}/scripts

rm $BASE_PATH/libs.tar.bz2 $BASE_PATH/PY.tar.bz2 $BASE_PATH/bin_apps.x86-64.tar.bz2  $BASE_PATH/scripts.tar.bz2 $BASE_PATH/ETL.tar.bz2 $BASE_PATH/mes_full.tar

echo -e "export LD_LIBRARY_PATH=$BASE_PATH/libs\nexport PATH=$PATH:$BASE_PATH/bins:$BASE_PATH/scripts/Bash-Scripts:$BASE_PATH/scripts/Perl-scripts:$BASE_PATH/scripts/Python-scripts\nexport ETL_LIB_PATH=$BASE_PATH/scripts/RepoLoadUtils/common\nexport AUTOTEST_LIB=$BASE_PATH/scripts/AutoValidation/kits\nexport PYTHONPATH=$BASE_PATH/libs:\${ETL_LIB_PATH}" > ~/update_env.sh
echo -e "source $BASE_PATH/python/enable" >> ~/update_env.sh
echo -e "alias rm='rm -i'" >> ~/update_env.sh
echo -e "alias ll='ls -l'" >> ~/update_env.sh
echo -e "ulimit -S -c 0" >> ~/update_env.sh
cat ~/update_env.sh >>  ~/.bashrc

#Update this terminal session
source ~/update_env.sh

py_cmd=python3
if command -v python3 &> /dev/null
then
    PY_PATH=$(which python3)
	sed -i 's|^#!/usr/bin/env python$|#!/usr/bin/env python3|g' $BASE_PATH/scripts/Python-scripts/*.py
elif command -v python &> /dev/null
then
	py_cmd=python
else
	echo "Python not found"
fi

PY_VERSION=$(${py_cmd} --version 2>&1 | awk '{print $2}' | awk -F. '{print $1}')
if [ $PY_VERSION -ne "3" ]; then
	echo "ERROR ${py_cmd} is not python 3, but python $PY_VERSION"
else
	echo "python3 was found - good"
fi
#dpkg -L libpython3.10 #To locate libpython3.so and create symbolic link

#Change html templates:
PLT_PATH=$(find ${BASE_PATH} -name plotly.min.js)
sed -i 's|"W:\\Graph_Infra\\plotly-latest.min.js"|"'${PLT_PATH}'"|g' $BASE_PATH/scripts/Python-scripts/templates/*.html
#sed -i 's|W:\\Graph_Infra\\plotly-latest.min.js|'${PLT_PATH}'|g' $BASE_PATH/scripts/RepoLoadUtils/common/ETL_Infra/plot_graph.py
#sed -i 's|W:\\Graph_Infra\\plotly-latest.min.js|'${PLT_PATH}'|g' ${BASE_PATH}/scripts/AutoValidation/kits/resources/lib/PY_Helper.py

ln -s ${BASE_PATH} ${BASE_PATH}/earlysign

mkdir -p ${BASE_PATH}/workspace
mkdir -p ${BASE_PATH}/workspace/notebooks
ln -s ${BASE_PATH} ${BASE_PATH}/workspace/notebooks/earlysign
echo "jupyter-lab --ip 0.0.0.0 --allow-root --port 7002 --no-browser --notebook-dir ${BASE_PATH}/workspace/notebooks --ServerApp.terminado_settings=\"shell_command=['/bin/bash']\" --NotebookApp.token='' --NotebookApp.password=''" > $BASE_PATH/scripts/Bash-Scripts/start_jupyter
chmod +x $BASE_PATH/scripts/Bash-Scripts/start_jupyter

#Set trust html by default in jupyter
if [ -f $HOME/.jupyter/lab/user-settings/@jupyterlab/htmlviewer-extension/plugin.jupyterlab-settings ]; then
	sed -i 's|"trustByDefault".*|"trustByDefault": true|g' $HOME/.jupyter/lab/user-settings/@jupyterlab/htmlviewer-extension/plugin.jupyterlab-settings
else
	mkdir -p $HOME/.jupyter/lab/user-settings/@jupyterlab/htmlviewer-extension
	echo '{ "trustByDefault": true }' > $HOME/.jupyter/lab/user-settings/@jupyterlab/htmlviewer-extension/plugin.jupyterlab-settings
fi
mkdir -p $HOME/.jupyter/lab/user-settings/@jupyterlab/apputils-extension
echo '{  "checkForUpdates": false  }' > $HOME/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/notification.jupyterlab-settings
echo -e "c.ServerApp.disable_check_xsrf = True\nc.ServerApp.allow_origin = '*'" >> $HOME/.jupyter/jupyter_notebook_config.py

mkdir -p ${BASE_PATH}/AlgoMarkers
mkdir -p ${BASE_PATH}/data
mkdir -p ${BASE_PATH}/data.outcome

#Test:
set +e
bootstrap_app --version
#Test python
echo -e "#######################################\nPython test:"
${py_cmd} -c "import med; print(med.Global.version_info)"

echo "Done All - success!"
