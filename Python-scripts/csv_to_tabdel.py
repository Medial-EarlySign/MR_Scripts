#!/usr/bin/env python

import fileinput
import csv
import sys

csvFile = open(sys.argv[1],"r")
outSep = "\t"
if (len(sys.argv) > 2):
	outSep = sys.argv[2]

lines = csv.reader(csvFile,quotechar='"',delimiter=',',quoting=csv.QUOTE_ALL,skipinitialspace=True)


for line in lines:
	print(outSep.join(line))
