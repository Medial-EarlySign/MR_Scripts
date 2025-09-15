@echo off
set PATH=%PATH%;C:\PYTHON37\python-3.7.2.amd64\Scripts;C:\PYTHON37\python-3.7.2.amd64

python.exe C:\alon\remote_copy\remote_copy.py --blocks 10000 --is_binary 1 --key_strokes_sleep 0.001 --send_msg 1 --open_close_file 1 --do_conv 1

PAUSE