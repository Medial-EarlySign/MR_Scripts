#!/usr/bin/python
import sys
from collections import defaultdict
import math

def getStats(ages):

	n = len(ages)
	print(n)
	
	sum = 0.0 
	for age in ages:
		sum += age 
	mean = sum/n 
	print(mean)
	
	sum=0.0
	for age in ages:
		sum += (age-mean)*(age-mean)
	sdv = math.sqrt(sum/n)
	print(sdv)

# Read scored ids
scoresFile = "/server/Work/Users/yaron/CRC/KPNW/TestSample.Larger/Sample.Scores.txt"
file = open(scoresFile)
ids = {}
 
for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	ids[fields[0]] = 1

# Read subset of ids
demFile = "/server/Work/Users/yaron/CRC/KPNW/TestSample.Larger/Sample.Demographics.txt"
file = open(demFile)
gender = {}
byear = {}

for line in file :
	fields = str.split(line.rstrip("\r\n")," ")
	if (fields[0] in ids):
		gender[fields[0]] = fields[2]
		byear[fields[0]] = int(fields[1])
	
nIds = len(gender.keys())
print("# of ids = ",nIds)	

# Read registry
regFile = "/server/Work/Users/yaron/CRC/KPNW/TestSample.Larger/registry.txt"
file = open(regFile)
cases = {}

for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	if (fields[0] in gender):
		cases[fields[0]] = 1

nCases = len(cases.keys())
print("# of Cases = ",nCases)

# Read IndexYear
demFile = "/server/Data/KPNW_MeScore_Apr2015/MeScoreDemograhics_v02.txt"
file = open(demFile,"r")
indexYear = {}

for line in file :
        fields = str.split(line.rstrip("\r\n"),"\t")
        if (fields[0] != "StudyID" and fields[0] in gender):
                indexYear[fields[0]] = int(fields[13])
				
# Collect ages
ages = {"ALL":[],"MaleCase":[], "MaleControl":[], "FemaleCase":[], "FemaleControl":[],"Case":[],"Control":[],"F":[],"M":[]}
for id in indexYear.keys():
	age = int(indexYear[id]) - int(byear[id])
	ages[gender[id]].append(age)
	ages["ALL"].append(age)
	if (id in cases):
		ages["Case"].append(age)
		if (gender[id] == "M"):
			ages["MaleCase"].append(age)
		else:
			ages["FemaleCase"].append(age)
	else:
		ages["Control"].append(age)
		if (gender[id] == "M"):
			ages["MaleControl"].append(age)
		else:
			ages["FemaleControl"].append(age)
			
for type in ages.keys():
	print(type)
	getStats(ages[type])
	

		
