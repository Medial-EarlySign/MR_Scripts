#!/usr/bin/python

import sys
import csv

indexWordsFile = "/server/Work/Users/yaron/ICU/Mimic/mimic3/AntiBiotics"
prescriptionsFile = "/server/Work/ICU/Mimic3/DataFiles/PRESCRIPTIONS.csv"

# Read IndexWords
file = open(indexWordsFile,"r")
dictionary = {}
for line in file:
	dictionary[line.rstrip("\r\n").lower()] = 1

file.close

file = open(prescriptionsFile,"r")
lines = csv.reader(file,quotechar='"',delimiter=',',quoting=csv.QUOTE_ALL,skipinitialspace=True)
drugs = {}
for line in lines:
	for idx in range(7,10):
		if (line[idx] != ""):
			lline = line[idx].lower()
			for word in dictionary.keys():
				if (lline.find(word)!=-1):
					drugs[line[7]] = word
					break
					
for drug in drugs.keys():
	print("%s\t%s\tAnribiotics"%(drug,drugs[drug]))
