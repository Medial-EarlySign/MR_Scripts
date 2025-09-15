#!/usr/bin/python
import subprocess, time, sys, re, os
from datetime import datetime
try:
	from urllib import quote  # Python 2.X
except ImportError:
	from urllib.parse import quote  # Python 3+

if len(sys.argv) < 2:
	raise NameError('Please provide search app string')

full_cmd="ps -efo pid,ppid,state,cmd | grep %s | grep -v grep | grep -v %s | awk '$3!=\"Z\"' | wc -l"%(sys.argv[1], sys.argv[0])

last_time=datetime.now()
while True:
	result = subprocess.check_output(full_cmd, shell=True)
	r=int(result.decode('utf-8').strip())
	#print('got %d'%(r))
	if r==0:
		print('Done Wait')
		break
	diff_time=(datetime.now() - last_time).total_seconds()/60.0
	time.sleep(3)