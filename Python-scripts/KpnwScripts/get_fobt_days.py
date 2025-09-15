#!/usr/bin/python
import sys
from collections import defaultdict
import datetime as dt 

fr = int(sys.argv[1])
to = int(sys.argv[2])


# Read Demographics
demFile = "//server/Data/KPNW_MeScore_Apr2015/MeScoreDemograhics_v02.txt"
file = open(demFile,"r")
indexYear = {}

for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	if (fields[0] != "StudyID"):
		indexYear[fields[0]] = int(fields[13])

# Index Year -> Date
indexDay = {}
for id in indexYear.keys():
	 indexDay[id] = dt.date(indexYear[id],7,1)

# Get FOBT/Fit and transform days	 
fitFile = "/server/Data/KPNW_MeScore_Apr2015/MeScoreFOBTFIT_v01.txt"
file = open(fitFile)

fitData = {}
for line in file:
	fields = str.split(line.rstrip("\r\n"),"\t")
	if (fields[0] != "StudyID"):
		id = fields[0]
		labIndexDay = int(fields[1])
		labIndexDate = indexDay[id] + dt.timedelta(days=labIndexDay)
		if (id not in fitData or labIndexDate < fitData[id]["date"]):
			fitData[id] = {"date":labIndexDate, "result":fields[4]}
	
# Get Scores
scoresfile = "/server/Work/Users/yaron/CRC/KPNW/TestSample/Sample.SelectedScores"
file = open(scoresfile)

outData = {}
for line in file:
	fields = str.split(line.rstrip("\r\n"),"\t")
	id = fields[0]
	if (id in fitData):
		scoreDate = dt.date(int(fields[1][0:4]),int(fields[1][4:6]),int(fields[1][6:8]))
		if (scoreDate <= fitData[id]["date"] - dt.timedelta(days=fr) and scoreDate >= fitData[id]["date"] - dt.timedelta(days=to) and (id not in outData or scoreDate > outData[id]["date"]) and (fitData[id]["result"]=="True" or fitData[id]["result"] == "False")):
			outData[id] = {"date":scoreDate,"delta":fitData[id]["date"]-scoreDate, "score":float(fields[2]), "label":fitData[id]["result"]}
		
for id in outData:
	if (outData[id]["label"] == "True"):
		print("%s\t%d\t%f\t1"%(id,outData[id]["delta"].days,outData[id]["score"]))
	else:
		print("%s\t%d\t%f\t0"%(id,outData[id]["delta"].days,outData[id]["score"]))