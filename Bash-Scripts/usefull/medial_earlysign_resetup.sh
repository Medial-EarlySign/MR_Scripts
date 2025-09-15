#!/bin/bash
BASE_PATH=${1-$HOME/earlysign}
FP_PATH=$(realpath ${0%/*})

#Only installs local system things  - for example after starting from docker OS.

#Check if Debian/Ubuntu:
if command -v apt &> /dev/null
then
	if command -v sudo &> /dev/null; then
		sudo apt update
		sudo apt install binutils perl htop ncdu net-tools vim bzip2 python3-pip python3-dev libpython3-dev libgomp1 gcc zip p7zip-full openssh-server gawk dos2unix cgdb sed file systemtap-sdt-dev make less libffi-dev swig cmake lsof libssl-dev zlib1g-dev locate libpython3 postgresql libpq-dev ccrypt libsqlite3-dev curl freetds-bin freetds-dev iputils-ping libbz2-dev lzma nano screen tdsodbc unixodbc-dev -y
	else
		apt update
		apt install binutils perl htop ncdu net-tools vim bzip2 python3-pip python3-dev libpython3-dev libgomp1 gcc zip p7zip-full openssh-server gawk dos2unix cgdb sed file systemtap-sdt-dev make less libffi-dev swig cmake lsof libssl-dev zlib1g-dev locate libpython3 postgresql libpq-dev ccrypt libsqlite3-dev curl freetds-bin freetds-dev iputils-ping libbz2-dev lzma nano screen tdsodbc unixodbc-dev -y
	fi
elif command -v yum &> /dev/null
then
	if command -v sudo &> /dev/null; then
		sudo yum install epel-release -y
		sudo yum install binutils libgomp gawk openssl openssl-devel gcc sqlite-devel zlib-devel libicu libffi-devel python3 python3-devel bzip2 bzip2-devel python-libs xz-devel p7zip screen perl htop ncdu iftop nload dos2unix cgdb zip less vim nano unzip tar man curl wget gzip file ssh gettext lsof unixODBC unixODBC-devel freetds freetds-devel sed -y
	else
		yum install epel-release -y
		yum install binutils libgomp gawk openssl openssl-devel gcc sqlite-devel zlib-devel libicu libffi-devel python3 python3-devel bzip2 bzip2-devel python-libs xz-devel p7zip screen perl htop ncdu iftop nload dos2unix cgdb zip less vim nano unzip tar man curl wget gzip file ssh gettext lsof unixODBC unixODBC-devel freetds freetds-devel sed -y
	fi
else
	echo "Operating System package manager unrecgonized:"
	cat /etc/issue
	lsb_release
fi

echo -e "export LD_LIBRARY_PATH=$BASE_PATH/libs\nexport PATH=$PATH:$BASE_PATH/bins:$BASE_PATH/scripts/Bash-Scripts:$BASE_PATH/scripts/Perl-scripts:$BASE_PATH/scripts/Python-scripts\nexport ETL_LIB_PATH=$BASE_PATH/scripts/RepoLoadUtils/common\nexport AUTOTEST_LIB=$BASE_PATH/scripts/AutoValidation/kits\nexport PYTHONPATH=$BASE_PATH/libs:\${ETL_LIB_PATH}" > ~/update_env.sh
echo -e "alias rm='rm -i'" >> ~/update_env.sh
echo -e "alias ll='ls -l'" >> ~/update_env.sh
#Test if inside docker and has cpui limits:
if [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]; then
        CPU_COUNTS=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us | awk '{print int($1/100000+0.5)}')
        echo "Has CPU limit to ${CPU_COUNTS}"
		if [ $CPU_COUNTS -gt 0 ]; then
			echo "export OMP_NUM_THREADS=${CPU_COUNTS}" >> ~/update_env.sh
		fi
fi
cat ~/update_env.sh >>  ~/.bashrc

#Install python packages
set +e
pip3 install pandas numpy plotly fastapi jupyterlab ipython argparse tqdm SQLAlchemy scikit-learn psycopg2 Keras Flask openpyxl pyodbc gnureadline
set -e

#Update this terminal session
source ~/update_env.sh

#Setup Jupyter with Medial Lib:
JUPYTER_CFG=$(jupyter kernelspec list | grep python3 | awk '{print $2 "/kernel.json"}')
if [ ! -z "${JUPYTER_CFG}" ]; then
	CNT=$(grep LD_LIBRARY_PATH ${JUPYTER_CFG} | wc -l)
	if [ $CNT -lt 1 ]; then
		sed -i 's|"language": "python"|"language": "python",\n"env":{  "LD_LIBRARY_PATH":"'$LD_LIBRARY_PATH'", "PYTHONPATH":"'$PYTHONPATH'", "ETL_LIB_PATH":"'$ETL_LIB_PATH'", "AUTOTEST_LIB":"'$AUTOTEST_LIB'" }|g' ${JUPYTER_CFG}
		echo "Patched python jupyter kernel to recognize medpython"
	else
		echo "python jupyter kernel already recognize medpython"
	fi
fi

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

#Test:
set +e
bootstrap_app --version
#Test python
echo "Python test:"
python -c "import med; print(med.Global.version_info)"

echo "Done All - success!"
