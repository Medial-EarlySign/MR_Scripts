#!/usr/bin/python
import sys
from collections import defaultdict

# Read subset of ids
demFile = "/server/Work/Users/yaron/CRC/KPNW/TestSample/Sample.Demographics.txt"
file = open(demFile)
ids = {}

for line in file :
	fields = str.split(line.rstrip("\r\n")," ")
	ids[fields[0]] = 1
	
nIds = len(ids.keys())
print("# of ids = ",nIds)	

# Read registry
regFile = "/server/Work/Users/yaron/CRC/KPNW/TestSample/registry.txt"
file = open(regFile)
cases = {}

for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	if (fields[0] in ids):
		cases[fields[0]] = 1

nCases = len(cases.keys())
print("# of Cases = ",nCases)

# Read Colonoscopies
colonoscopyFile = "//server/Data/KPNW_MeScore_Apr2015/MeScoreCombine_v01.txt"
file = open(colonoscopyFile,"r")

idRefferrals = {}
idIndexDays = {}

for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	
	id = fields[0]
	if (id == "StudyID"):
		continue
		
	procedure = fields[1]
	if (procedure != "Colonoscopy"):
		continue
		
	if (id in ids):
		refferral = fields[4]
		indexDays = int(fields[2])
		
		# for cases - take only colonoscopies prior to index-day
		if (id in cases and indexDays>0):
			continue
			
		if (id not in idIndexDays or abs(indexDays) < abs(idIndexDays[id])):
			idIndexDays[id] = indexDays
			idRefferrals[id] = refferral

# Print
for id in idIndexDays:
	print("%s\t%d\t%s"%(id,idIndexDays[id],idRefferrals[id]))
