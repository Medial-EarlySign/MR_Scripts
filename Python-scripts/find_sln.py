#!/usr/bin/env python
import os

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

run()