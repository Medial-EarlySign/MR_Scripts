#!/usr/bin/python

import sys
import csv

mimic2LabItemsFile = "/server/Work/Users/yaron/ICU/Mimic/InfraMed/LabEvents.Signals.More_Than_1000_Events"
dictionaryFile = "/server/Work/ICU/Mimic3/mimic-code-master/migrating/labid.csv"
mimic3LabItemsFile = "/server/Work/Users/yaron/ICU/Mimic/mimic3/LabEvents.Signals.More_Than_1000_Events"

print("Using %s to translate %s into %s"%(dictionaryFile,mimic2LabItemsFile,mimic3LabItemsFile))

# Read Translation file
file = open(dictionaryFile,"r")
dictionary = {}
lines = csv.reader(file,quotechar='"',delimiter=',',quoting=csv.QUOTE_ALL,skipinitialspace=True)

for line in lines:
	mimic3Code = line[0]
	mimic2Code = line[7]
	dictionary[mimic2Code] = mimic3Code
file.close
	
# Translate
inFile = open(mimic2LabItemsFile,"r")
outFile = open(mimic3LabItemsFile,"w")
outSep = "\t"
for line in inFile:
	fields = str.split(line.rstrip("\n"),"\t")
	if (fields[0] in dictionary):
		fields[0] = dictionary[fields[0]]
		outLine = outSep.join(fields)
		outFile.write("%s\n"%outLine)
	else:
		print("Cannot find mimic3 code for %s"%fields[0])