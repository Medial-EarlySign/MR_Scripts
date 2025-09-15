#!/usr/bin/env python
from __future__ import print_function
import sys

# ID2NR
id2nrFile = "//server/Work/CancerData/AncillaryFiles/ID2NR"
id2nr = {}

file = open(id2nrFile,"r")
for line in file :
	fields = str.split(line,"\t")
	id2nr[fields[0]] = int(fields[1])

# Registry
registryFile = "//server/Work/CancerData/AncillaryFiles/Registry"
registry = {}

file = open(registryFile,"r")
for line in file :
	fields = str.split(line,"\t")
	nr = int(fields[0])
	registry[nr] = 1 ;


file.close()

# Comments
commentsFile = "//server/Data/THIN/EPIC 88/Ancillary files/THINComments.txt"
comments = {}

file = open(commentsFile,"r")
for line in file :
	newLine = line.rstrip(" \r\n")
	id = newLine[0:7]
	text = newLine[7:]
	comments[id] = text

file.close()
	
# Lookups
lookupFile = "//server//Data/THIN/EPIC 65/Ancil 1205/THINLookups.txt" ;
lookup = {}

file = open(lookupFile,"r")
for line in file :
	newLine = line.rstrip(" \r\n")
	table = newLine[0:10]
	table = table.rstrip(" ")
	table = table.lstrip(" ")
	
	key = newLine[10:13]
	key = key.rstrip(" ")
	key = key.lstrip(" ")
	
	value = newLine[13:]
	value = value.lstrip(" ")
	
	if (not table in lookup):
		lookup[table] = {}
	
	lookup[table][key] = value
	
file.close()

# ReadCodes	
readCodesFile = "//server//Data/THIN/EPIC 65/Ancil 1205/Readcodes1205.txt" ;
readCodes = {}

file = open(readCodesFile,"r")
for line in file:
	newLine = line.rstrip("\r\n")
	code = newLine[0:7]
	code = code.rstrip(" ")
	code = code.lstrip(" ")
	
	desc = newLine[7:67]
	desc = desc.rstrip(" ")
	desc = desc.lstrip(" ")
	readCodes[code] = desc
	
file.close()

# MedFile
medFiles = ("//server/Data/THIN/EPIC 88/MedialResearch_med.csv","//server/Work/CRC/NewCtrlTHIN/new_med.csv")
med = {id:[] for id in id2nr.keys()} 

for medFile in medFiles:
	file = open(medFile,"r")

	if (file.closed):
		sys.stderr.write("Cannot open file %s"%medFile)
		quit()
		
	for line in file :
		fields = str.split(line,",")
		id = fields[0] + fields[1]
		
		if (not id in id2nr):
			continue
		
		nr = id2nr[id]
		group = "CONTROL"
		if (nr in registry):
			group = "CANCER"
		
		dataType = fields[4]
		med = fields[5]
		category = fields[13]
		text = fields[12]
		
		if (dataType in lookup['datatype']):
			dataType = lookup['datatype'][dataType]
			
		if (category in lookup['category']):
			category = lookup['category'][category]
			
		if (med in readCodes):
			med = readCodes[med]
			
		if (text in comments):	
			text = comments[text]
			if (len(text)):
				print ("%s : %s // %s // %s // %s // %s" % (id,dataType,category,med,text,group))
		
	file.close()
