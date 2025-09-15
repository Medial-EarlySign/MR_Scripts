#!/usr/bin/python

from __future__ import print_function
from collections import defaultdict
import sys
import csv

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

instructionsFile = "/server/Work/Users/yaron/ICU/Mimic/Mimic3/InputEventsMvInstructions"
inputMVFile = "/server/Work/ICU/Mimic3/DataFiles/INPUTEVENTS_MV.csv"
problemsFile = "/tmp/mv_units"

# Read Instructions
signals = defaultdict(list)
id2signal = {}
file = open(instructionsFile,"r")
for line in file:
	fields = str.split(line.rstrip("\n"),"\t")
	signals[fields[-1]].append(fields[0])
	id2signal[fields[0]] = fields[-1]
eprint("Done reading signals")

# Read Problems
file = open(problemsFile,"r")
problems = defaultdict(list)
for line in file:
	fields = line.rstrip("\n").split()
	{problems[id].append(fields[-1]) for id in signals[fields[-2]]}
eprint("Done reading problems")

# Read InputMV
file = open(inputMVFile,"r")
lines = csv.reader(file,quotechar='"',delimiter=',',quoting=csv.QUOTE_ALL,skipinitialspace=True)
data = {x:defaultdict(dict) for x in id2signal.keys()}

for line in lines:
	if (line[6] in problems):
		if (line[7] in data[line[6]][line[8]]):
			data[line[6]][line[8]][line[7]] += 1
		else :
			data[line[6]][line[8]][line[7]] = 1
eprint("Done reading inputMV")

for id in data.keys():
	for unit in data[id].keys():
		for value in data[id][unit].keys():
			if (data[id][unit][value] > 10):
				print(id,id2signal[id],unit,value,data[id][unit][value])