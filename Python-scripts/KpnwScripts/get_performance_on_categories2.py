#!/usr/bin/python
import sys
from collections import defaultdict
import datetime as dt

# Demographics (for index year)
demFile = "//server/Data/KPNW_MeScore_Apr2015/MeScoreDemograhics_v02.txt"
indexYear = {}

file = open(demFile,"r")
for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	if (fields[13] != "IndexYear"):
		indexYear[fields[0]] = int(fields[13])

# Index Year -> Date
indexDay = {}
for id in indexYear.keys():
         indexDay[id] = dt.date(indexYear[id],7,1)
	
	
# Categories
ctgFile = "//server/Work/Users/yaron/CRC/KPNW/TestSample.Larger/Category.ICD9.no_upper"
icd9 = {}

file = open(ctgFile,"r")
for line in file:
	fields = str.split(line.rstrip("\r\n")," ")
	print(fields)
	icd9[fields[1]] = fields[0]
	
	
# Dx
dxFile = "//server/Data/KPNW_MeScore_Apr2015/MeScoreDiagnosis_v01.txt"
dx = {}

file = open(dxFile,"r")
for line in file:
	fields = str.split(line.rstrip("\r\n"),"\t")
	if (fields[0] == "StudyID"):
		continue
	
	id = fields[0]
	code = fields[2].replace(".","")
	if (code in icd9.keys()):
		category = icd9[code]
		dxDay = int(fields[1])
		dxDate = indexDay[id] + dt.timedelta(days=dxDay)
		print("%s\t%s\t%04d%02d%02d"%(id,category,dxDate.year,dxDate.month,dxDate.day))
	
	
