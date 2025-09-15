#!/usr/bin/env python

import random

locationDict = {"ICDO[C180]:COLON: Cecum":"cecum",
				"ICDO[C182]:COLON: Ascending colon":"ascend",
				"ICDO[C183]:COLON: Hepatic flexure of colon":"hep flx",
				"ICDO[C184]:COLON: Transverse colon":"trans",
				"ICDO[C185]:COLON: Splenic flexure of colon":"spl flx",
				"ICDO[C186]:COLON: Descending colon":"desc",
				"ICDO[C187]:COLON: Sigmoid colon":"sigm",
				"ICDO[C199]:RECTOSIGMOID JUNCTION: Rectosigmoid junction":"rs",
				"ICDO[C209]:RECTUM: Rectum, NOS":"rectum"
				}

# Read Historgram of Hilsden
file = open("//server/Work/Users/yaron/CRC/Hilsden/Gender.Location.Hist","r")
count = {"male":{}, "female":{}}
probs = {"male":{}, "female":{}}
sums = {"male":0,"female":0}

for line in file:
	fields = str.split(line.rstrip("\n"),"\t")
	if (fields[1] != "NA"):
		count[fields[0]][fields[1]] = int(fields[2])
		sums[fields[0]] += int(fields[2])

for gender in count:
	probs[gender] = {loc:float(count[gender][loc])/sums[gender] for loc in count[gender].keys()}
	
#Degmographics	
file = open("//server/Work/CancerData/AncillaryFiles/Demographics.FEB2016","r")
gender={}
for line in file:
	ll = line.rstrip("\r\n")
	fields = ll.split()
	if (int(fields[0]) < 4000000):
		if (fields[2] == "M"):
			gender[fields[0]] = "male"
		else:
			gender[fields[0]] = "female"
	
# Registry	
file = open("//server/Work/CancerData/AncillaryFiles/Registry","r")	

mhsCount = {"male":{}, "female":{}}
mhsProbs = {"male":{}, "female":{}}
mhsSums = {"male":0,"female":0}
mhsLines ={"male":{}, "female":{}}
sep = "\t" ;

for line in file:
	ll = line.rstrip("\n")
	fields = ll.split("\t")
	if (int(fields[0])<4000000 and (fields[2] == "Digestive Organs,Digestive Organs,Rectum" or fields[2] == "Digestive Organs,Digestive Organs,Colon")):
		if (fields[-2] in locationDict):
			g = gender[fields[0]]
			loc =locationDict[fields[-2]]
			mhsSums[g] += 1
			if (loc in mhsCount[g]):
				mhsCount[g][loc] += 1
			else:
				mhsCount[g][loc] = 1
			if (loc in mhsLines[g]):
				mhsLines[g][loc].append(ll)
			else:
				mhsLines[g][loc] = [ll]
		else :
			fields[2] = "Dummy,Dummy,Dummy"
			line = sep.join(fields)
			print(line)
	else:
		print(ll)

for gender in mhsCount:
	mhsProbs[gender] = {loc:float(mhsCount[gender][loc])/mhsSums[gender] for loc in mhsCount[gender].keys()}

# Sample
for gender in probs.keys():
	minR=-1
	for loc in mhsCount[gender].keys():
		r = float(mhsCount[gender][loc])/count[gender][loc]
#		print(gender,loc,count[gender][loc],mhsCount[gender][loc],r)
		
		if (minR==-1 or r<  minR):
			minR=r
#			print("->",gender,loc,count[gender][loc],mhsCount[gender][loc],minR)
			
	for loc in mhsCount[gender].keys():
		n = count[gender][loc]*minR
		p = n/mhsCount[gender][loc]
		
		for ll in mhsLines[gender][loc]:
			pp = random.random()
			if (pp < p):
				print(ll)
			else:
				fields = ll.split("\t")
				fields[2] = "Dummy,Dummy,Dummy"
				line = sep.join(fields)
				print(line)
	
	