#!/usr/bin/python

ageFileName = "/server/Work/Users/yaron/ICU/Mimic/ParseData/ICUSTAY_DETAIL"
ageFile = open(ageFileName,"r")

ages = {}
idCol = ageCol = -1
for line in ageFile:
	fields = str.split(line,",")
	if (idCol==-1):
		# Header
		for i in range(len(fields)):
			if (fields[i] == "ICUSTAY_ADMIT_AGE"):
				ageCol = i
			elif (fields[i] == "SUBJECT_ID"):
				idCol = i
		
		if (idCol==-1 or ageCol==-1):
			print ("Parsing header failed for %s\n"%ageFileName)
			exit()
		else:
			print ("ID col = %d , Age col = %d\n"%(idCol,ageCol))
	else:
		ages[fields[idCol]] = float(fields[ageCol])
ageFile.close()
		
ioFileName = "/server/Work/Users/yaron/ICU/Mimic/ParseData/IOEVENTS"
ioFile = open(ioFileName,"r")

idCol = itemCol = -1
minmax = {}

for line in ioFile:
	fields = str.split(line,",")
	if (idCol==-1):
		# Header
		for i in range(len(fields)):
			if (fields[i] == "ITEMID"):
				itemCol = i
			elif (fields[i] == "SUBJECT_ID"):
				idCol = i
		
		if (idCol==-1 or ageCol==-1):
			print ("Parsing header failed for %s\n"%ioFileName)
			exit()
		else:
			print ("ID col = %d , Item col = %d\n"%(idCol,itemCol))
	else:
		item = fields[itemCol]
		id = fields[idCol]
		if (id in ages):
			age = ages[fields[idCol]]
			
			if (not (item in minmax)):
				minmax[item] = {'min':age,'max':age}
			elif (age < minmax[item]['min']):
				minmax[item]['min'] = age
			elif (age > minmax[item]['max']):
				minmax[item]['max'] = age

for item in minmax.keys():
	print("%d : %f - %f"%(int(item),float(minmax[item]['min']),float(minmax[item]['max'])))
		
		
ioFile.close()