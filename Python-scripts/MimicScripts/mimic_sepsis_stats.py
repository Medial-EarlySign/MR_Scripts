#!/usr/bin/python

import numpy
from collections import defaultdict

# Read stderr summary
file = open("/server/Work/Users/yaron/ICU/Mimic/Sepsis/GetSepsisInfo/StderrSummary","r") ;

generationInfo = {}
for line in file:
	fields = str.split(line.rstrip("\n")," ")
	id = int(fields[0])
	type = fields[2]
	
	value = [fields[i] for i in range(3,len(fields))]
	
	if (id not in generationInfo):
		generationInfo[id] = {}
		
	generationInfo[id][type] = value
	
# Read Sepsis Values
file = open("/server/Work/Users/yaron/ICU/Mimic/Sepsis/PredictionsAtAdmission/SepsisSignals.values","r")
header = []

sepsisInfo = {}
for line in file:
	fields = str.split(line.rstrip("\n")," ")
	id = int(fields[1])
	if (id not in sepsisInfo):
		sepsisInfo[id] = {}
		
	signal = fields[0]
	if (signal == "InTime"):
		sepsisInfo[id][signal] = int(fields[2])
	else:
		sepsisInfo[id][signal] = {"time":(fields[2]),"value":float(fields[3])}
		
# Stats:
# Sepsis Info : Notes/ICD9/Diagnosis-Siganl
types = ["icd9-sepsis","notes","notesAdmin","notesRO","diagnosis","diagnosisMaybe","diagnosisRO"]

count = {}
totalCount={}
for type in types:
	totalCount[type] = 0
	count[type] = {x:0 for x in types}
		
for id in generationInfo.keys():
	icd9 = generationInfo[id]["Icd9Sepsis"]
	notes = generationInfo[id]["NotesSepsis"]
	diagnosis = generationInfo[id]["DiagnosisSepsis"]

	current = {x:0 for x in types}
	if (int(icd9[1])):
		current["icd9-sepsis"] = 1
	if (int(notes[1])):
		current["notes"] = 1
	if (int(notes[2])):
		current["notesAdmin"] = 1
	if (int(notes[3])):
		current["notesRO"] = 1
	if (int(diagnosis[1])):
		current["diagnosis"] = 1
	if (int(diagnosis[2])):
		current["diagnosisMaybe"] = 1
	if (int(diagnosis[3])):
		current["diagnosisRO"] = 1
			
	for type in types:
		if (current[type]==1):
			totalCount[type] += 1
		
			for type2 in types:
				if (type != type2 and current[type2]==1):
					count[type][type2] += 1
				
for type in types:
	for type1 in types:
		if (type != type1):
			print("Out of %d %s ; %d are %s . %.1f%%"%(totalCount[type],type,count[type][type1],type1,100*count[type][type1]/totalCount[type]))
print()

# Infection Info : ICD9/Microbiology/Antibiotics
types = ["icd9-infection","microbiology","antibiotics"]
count = {}
totalCount={}
for type in types:
	totalCount[type] = 0
	count[type] = {x:0 for x in types}
	
for id in generationInfo.keys():
	icd9 = generationInfo[id]["Icd9Infection"]
	mb = generationInfo[id]["microBilogyInfection"]
	
	current = {x:0 for x in types}
	
	if (int(icd9[0])):
		current["icd9-infection"] = 1
	if (mb[0] != "0/0"):
		current["microbiology"] = 1
	if ("POE" in generationInfo[id]):
		current["antibiotics"] = 1
			
	for type in types:
		if (current[type]==1):
			totalCount[type] += 1
		
			for type2 in types:
				if (type != type2 and current[type2]==1):
					count[type][type2] += 1
				
for type in types:
	if (totalCount[type]==0):
		continue
	for type1 in types:
		if (type != type1):
			print("Out of %d %s ; %d are %s . %.1f%%"%(totalCount[type],type,count[type][type1],type1,100*count[type][type1]/totalCount[type]))
print()

# SepsisIndication/InfectionIndication/dSOFA
types = ["Sepsis-0","Sepsis-1","Sepsis-2","Sepsis-3","Sepsis-4","Sepsis-5","Infection","dSOFA"]
order = {types[i]:i for i in range(len(types))}

count1 = {}
count2 = {}
count3 = {}

for type in types:
	count1[type] = 0
	count2[type] = {}
	count3[type] = {}
	for type2 in types:
		count2[type][type2] = 0
		count3[type][type2] = {x:0 for x in types}

counts={}
for id in generationInfo:
	current = {x:0 for x in types}
	current["Sepsis-%d"%int(sepsisInfo[id]["Sepsis_Indication"]["value"])] = 1
	if (int(sepsisInfo[id]["Infection_Indication"]["value"])):
		current["Infection"] = 1 
	if ("SOFA_Increase" in sepsisInfo[id]):
		current["dSOFA"] = 1

	for type in types:
		if (current[type]==1):
			count1[type] += 1
		
			for type2 in types:
				if (type != type2 and current[type2]==1):
					count2[type][type2] += 1

					for type3 in types:
						if (type != type3 and type2 != type3 and current[type3]==1):
							count3[type][type2][type3] += 1
						

for type in types:
	if (count1[type]==0):
		continue
	for type1 in count2[type].keys():
		if (count2[type][type1]):
			print("Out of %d %s ; %d are %s . %.1f%%"%(count1[type],type,count2[type][type1],type1,100*count2[type][type1]/count1[type]))
			
			if (order[type] < order[type1]):
				for type2 in count3[type][type1].keys():
					if (count3[type][type1][type2]):
						print("Out of %d %s+%s ; %d are %s . %.1f%%"%(count2[type][type1],type,type1,count3[type][type1][type2],type2,100*count3[type][type1][type2]/count2[type][type1]))
print()
						
# SepsisForLearn/SepsisForTest
total = 0
count = numpy.zeros((3,3))
for id in generationInfo:
	total +=1
	test=2
	learn=2
	if ("Sepsis_for_Learn" in sepsisInfo[id]):
		learn=int(sepsisInfo[id]["Sepsis_for_Learn"]["value"])
		
	if ("Sepsis_for_Test" in sepsisInfo[id]):
		test=int(sepsisInfo[id]["Sepsis_for_Test"]["value"])	
		
	count[learn][test] +=1

print("Total = %d"%total)
print("Learn\\Test\t0(%)\tNA(%)\t1(%)")
print("0\t\t%.1f\t%.1f\t%.1f"%(100*count[0][0]/total,100*count[0][2]/total,100*count[0][1]/total))	
print("NA\t\t%.1f\t%.1f\t%.1f"%(100*count[2][0]/total,100*count[2][2]/total,100*count[2][1]/total))
print("1\t\t%.1f\t%.1f\t%.1f"%(100*count[1][0]/total,100*count[1][2]/total,100*count[1][1]/total))	
print()


# Time to SpeisForLearn/SepsisForTest
startHist=defaultdict(int)
lenHist=defaultdict(int)
total = 0 
for id in sepsisInfo:
	if ("Sepsis_for_Learn" in sepsisInfo[id] and int(sepsisInfo[id]["Sepsis_for_Learn"]["value"])==1):
		total += 1
		times = [int(x) for x in str.split(sepsisInfo[id]["Sepsis_for_Learn"]["time"],"-")]
		inTime = sepsisInfo[id]["InTime"]
		startHour = int((times[0]-inTime)/60)
		if (startHour>36):
			startHour=36
			
		lenHour = int((times[1]-times[0])/60)
		if (lenHour>24):
			lenHour=24
		startHist[startHour] += 1
		lenHist[lenHour]+=1
		
print("Histogram of starting time for Sepsis_For_Learn(Hours)")
for hour in sorted(startHist.keys()):
	if (hour==36):
		print(">=36\t%d\t%.1f%%"%(startHist[hour],100*startHist[hour]/total))
	else:
		print("%d\t%d\t%.1f%%"%(hour,startHist[hour],100*startHist[hour]/total))
print()
		
print("Histogram of SOFA increase time for Sepsis_For_Learn(Hours)")
for hour in sorted(lenHist.keys()):
	if (hour==24):
		print(">=24\t%d\t%.1f%%"%(lenHist[hour],100*lenHist[hour]/total))
	else:
		print("%d\t%d\t%.1f%%"%(hour,lenHist[hour],100*lenHist[hour]/total))
print()	