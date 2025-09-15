#!/usr/bin/env python

from datetime import date
import sys
from collections import defaultdict

colId2MedId={}
birthDays={}
firstEnDate={}

cbcCodes = {"5041":1,"5048":1,"50221":1,"50223":1,"50224":1,"50225":1,"50226":1,"50227":1,
			"50228":1,"50229":1,"50230":1,"50232":1,"50233":1,"50234":1,"50235":1,"50236":1,
			"50237":1,"50238":1,"50239":1,"50241":1}

timeHist = defaultdict(int)
panelHist = defaultdict(int)

# Handling function
def handle (info):
	medId = "dummy"
	lastDays = -1 
	panel = {}
	
	for line in info:
		fields=line.split(",")
		medId = fields[0]
		if (medId not in firstEnDate):
#			print("Cannot find %s in endoscopies"%medId)
			continue
			
		code = fields[2]
		if (code in cbcCodes):
			dateTimeInfo = fields[3].split(" ")
			dateInfo = [int(x) for x in dateTimeInfo[0].split("-")]
			days = date(dateInfo[0],dateInfo[1],dateInfo[2]).toordinal()
			
			if (days not in panel):
				panel[days]={}
				
			panel[days][code]=1	
			
			if (days <= firstEnDate[medId] and days > lastDays):
				lastDays = days
	
	if (lastDays!=-1):
		deltaWeeks = (firstEnDate[medId] - lastDays)/7
		timeHist[deltaWeeks] += 1
		nCodes = len(panel[lastDays].keys())
		panelHist[nCodes] += 1
	else:
		timeHist[9999] += 1
	
# Read Mapping of ids
dicFile = open("/server/Work/Users/yaron/CRC/Ichilov/Demographic_Data.txt","r")

for line in dicFile:
	fields = line.split("\t")
	idFields = fields[0].split(".")
	
	if (idFields[0] != "ID" and fields[4] != "NULL"):
		colId2MedId[idFields[1]] = fields[2]
		dateInfo = [int(x) for x in fields[4].split("/")]
		days = date(dateInfo[2],dateInfo[1],dateInfo[0]).toordinal()
		birthDays[idFields[1]] = days
	
	
# Read colonoscopies
endFile = open("/server/Work/Users/yaron/CRC/Ichilov/endoscopies.txt","r")

for line in endFile:
	fields = line.split("\t")
	colId = fields[0]
	if (colId != "track number"):
		
		dateInfo = [int(x) for x in fields[1].split("/")]
		days = date(dateInfo[2],dateInfo[1],dateInfo[0]).toordinal()
	
		if (colId not in colId2MedId):
#			print("Cannot find %s in table"%colId)
			continue
			
		if (colId not in birthDays):
			print("Cannot find birthdate for %s"%colId)
			exit(-1)
			
		age = (days-birthDays[colId])/365.0
		
#		if (age>=50 and age<=75):
		if (age>=40 and age<=80):
			medId = colId2MedId[colId]
			if (medId not in firstEnDate or days < firstEnDate[medId]):
				firstEnDate[medId] = days
		
# Read blood tests
labFile = open("/server/Work/Users/yaron/CRC/Ichilov/LabResults","r")

prevMedId = "dummy"
info = []

for line in labFile:
	fields=line.split(",")
	medId = fields[0]
	if (medId != prevMedId):
		if (medId != "RANDOM_ID" and prevMedId != "RANDOM_ID"):
			handle(info)
		info = []
		
	prevMedId=medId
	info.append(line)
	
print("TimeHist")
for delta in sorted(timeHist.keys()):
	print("%d\t%d"%(delta,timeHist[delta]))
print("\nPanelHist")
for size in sorted(panelHist.keys()):
	print("%d\t%d"%(size,panelHist[size]))	