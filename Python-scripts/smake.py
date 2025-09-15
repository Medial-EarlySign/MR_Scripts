#!/usr/bin/env python
import os
import sys

def find_sln(path):
    fls = os.listdir(path)
    for f in fls:
        if f.endswith('.sln'):
            return os.path.basename(path)
        elif (f != 'CMakeBuild' and os.path.isdir( os.path.join(path, f)) and not(os.path.islink(os.path.join(path, f)))):
            res = find_sln(os.path.join(path, f))
            if len(res) > 0:
                return res
    return ''

def run():
    res = find_sln(os.path.abspath('.'))
    print(res)

root = os.environ["MR_ROOT"]
paths = [".","/",root,root+"/Tools/",root + "/Projects/Shared/"]

givenPath = sys.argv[1] ;
if (len(sys.argv) > 2):
	type = sys.argv[2]
else:
	type = "rel"
	
if (type == "dbg"):
	finalPath = "Debug"
else:
	finalPath = "Release"
	
baseCommand = "smake_" + type ;
	
done = 0 
for path in paths:
	fullPath = path + givenPath + "/CMakeBuild/Linux/" + finalPath
	if (os.path.exists(fullPath)):
		command = "pushd %s && make -j 8; popd"%fullPath
		os.system(command)
		done = 1
		
if (done==0):
	print("NO SUITABLE SOLUTION FOUND\n")