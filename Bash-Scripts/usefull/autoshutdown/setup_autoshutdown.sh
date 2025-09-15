#!/bin/bash
set -e
FP_PATH=$(realpath ${0%/*})
PY_PATH=$(which python)
#Setup auto shutdown:

yes | pip install -r ${FP_PATH}/requirements.txt

sudo sed -i 's|ExecStart=.*|ExecStart='${PY_PATH}' '${FP_PATH}'/auto_shutdown.py|g' ${FP_PATH}/auto_shutdown.service
sudo cp ${FP_PATH}/auto_shutdown.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable auto_shutdown.service
sudo systemctl start auto_shutdown.service
