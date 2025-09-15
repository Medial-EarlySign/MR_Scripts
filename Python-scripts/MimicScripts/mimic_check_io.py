#!/usr/bin/python

import sys

# is an ID given ?
inIds = dict.fromkeys(sys.argv)

# Read ids
idsFileName = "/server/Work/Users/yaron/ICU/Mimic/ParseData/AdultsIds"
idsFile = open(idsFileName,"r")

ids = []
for _id in idsFile:
	id = _id.rstrip("\r\n")
	if (len(inIds) == 1 or id in inIds):
		ids.append(int(id))
	
nids = len(ids)
print ("Read %d ids"%nids)

# Read ItemId -> Signal
dicFileName = "/server/Work/Users/yaron/ICU/Mimic/InfraMed/IOEvents.Signals.More_Than_1000_Filtered_And_Dialysis"
dicFile = open(dicFileName,"r")

codes = {}
for line in dicFile:
	fields = str.split(line.rstrip("\n"),"\t")
	codes[int(fields[0])] = [fields[1],fields[3]]

dicFile.close()
signals = codes.values() ;

# Loop on IOEVENTS files
root = "/server/Work/ICU/Mimic"
for id in ids:
	fileName = "%s/%02d/%05d/IOEVENTS-%05d.txt"%(root,int(id/1000),id,id)
	file = open(fileName,"r")

	io = {signal[1]:[] for signal in signals}
	for line in file:
		fields = str.split(line.rstrip("\n"),",")
		info = [fields[i] for i in (2,3,9,14)]
		if (info[0] != "ITEMID" and int(info[0]) in codes):
			code = int(info[0])
			info.append(codes[code][0])
			io[codes[code][1]].append(info)
	
	for signal in io.keys():
		if (len(io[signal])):
			for rec in io[signal]:
				print (id,signal,rec)
				
	print ()
			