#!/usr/bin/env python
from __future__ import print_function

help = """Perform git commands on multiple repository
		  Usage : med_git.py [--dir med-config-directory || --file file-of-repositories] --command command
          config file is either directly given or .med_git in dir or in current directory, gives list of directories of repositories in full path 
		  not including /h/Medial/; e.g. /nas1/UsersData/yaron/Medial/Libs/ROCR is given as Libs/ROCR
		"""
  
import argparse as ap
import re
import sys
import getpass
import os
from subprocess import call

parser = ap.ArgumentParser(description = "performa git command")
parser.add_argument("-d","--dir",help="directory of .med_git config file",default="")
parser.add_argument("-f","--file",help="file of repositories",default="")
parser.add_argument("command",help="git command to perform",default="")

args = parser.parse_args() 

config_file = ".med_git"
if args.dir:
	config_file = args.dir + "/" + config_file
elif args.file:
	config_file = args.file
	
# Read config file
platform = sys.platform
if (platform[0:5] == "linux"):
	user = getpass.getuser()
	prefix = os.environ['MEDIAL_ROOT'] + "/"
elif (platform == "cygwin"):
	prefix = "/cygfrive/h/Medial/"
else:
	print("Unknwon platform %s. %s Quitting"%platform)
	sys.exit(1)

git_directories = []
file = open(config_file,"r")

for line in file:
	name = line.rstrip("\r\n")
	if (name[0] != "#"):
		git_directories.append(prefix + name)

# Loop and perform command
cwd = os.getcwd()
for dir in git_directories:
	print("Working on repository %s"%dir)
	try:
		os.chdir(dir)
	except OSError as e:
		print("fatal: cannot change to directory %s : %s"% (dir, e.strerror), file=sys.stderr)
	
	command = ["git"]
	command += args.command.split()

	try:
		call(command)
	except OSError as e:
		print("fatal: cannot run git command in directory %s : %s"% (dir, e.strerror), file=sys.stderr)	