#!/usr/bin/python
import sys
from collections import defaultdict

# Demographics (for index year)
demFile = "//server/Data/KPNW_MeScore_Apr2015/MeScoreDemograhics_v02.txt"
indexYear = {}

file = open(demFile,"r")
for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	indexYear[fields[0]] = fields[13]

# SnoMed
snoMedFile = "//server/Work/Data/SnoMed/KPNW_SNOMED_desc_02012016.txt"
snoMed = {}

file = open(snoMedFile,"r")
for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	snoMed[fields[0]] = fields[1]
	
# Colonoscopies
colonoscopyFile = "//server/Data/KPNW_MeScore_Apr2015/MeScoreCombine_v01.txt"
counts = defaultdict(int)

file = open(colonoscopyFile,"r")
for line in file :
	fields = str.split(line.rstrip("\r\n"),"\t")
	
	id = fields[0]
	if (id == "StudyID"):
		continue
		
	procedure = fields[1]
	if (procedure != "Colonoscopy"):
		continue
		
	colYear = int(indexYear[id]) + int(fields[2])/365
	if (colYear < 2007):
		relation = "Before"
	else:
		relation = "After"	
		
	pathReport = fields[3] 
	refferral = fields[4]
																				   
#	if (refferral == "REFERRAL COLON CANCER SCREENING HI RISK." or refferral == "REFERRAL GI, COLONOSCOPY, PATIENT REQUEST" or refferral == "REFERRAL GI, FAMILY HISTORY COLON CANCER"):
	if (1):
		info = "Screening " + relation + " 2007 "
		counts[info] += 1 
		
		if (pathReport == "True"):	
			snoMedInfo = fields[5].replace(" ","")
			if (snoMedInfo != ''):
				snoMeds = str.split(snoMedInfo,",")
				for finding in snoMeds:
					description = snoMed[finding]
					info = "Screening " + relation + " 2007 with " + description
					counts[info] += 1  
			else :
				info = "Screening " + relation + " 2007 with empty report"
				counts[info] += 1
		else :
				info = "Screening " + relation + " 2007 without report"
				counts[info] += 1
					
for description in sorted(counts,key=counts.get,reverse=True):
	print("%s : %d"%(description,counts[description]))
