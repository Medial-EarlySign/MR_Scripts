#!/usr/bin/env python
from __future__ import print_function
import sys
import scipy.stats as stats

inFile = sys.argv[1]
file = open(inFile,"r")

cancerStatus = {}
textIds = {}

for line in file :
	newLine = line.rstrip("\n")
	fields = str.split(newLine," // ")
	
	nFields = len(fields)
	id = fields[0]
	cancer = fields[nFields-1]
	text = fields[nFields-2]
	
	if (not text in textIds):
		textIds[text] = {}
	
	cancerStatus[id] = cancer
	textIds[text][id] = 1
		
file.close()

totalCount = {'CANCER':0,'CONTROL':0}
for id in cancerStatus:
	totalCount[cancerStatus[id]] += 1

for text in (textIds):
	textCount = {'CANCER':0,'CONTROL':0}
	for id in textIds[text].keys():
		textCount[cancerStatus[id]] += 1 
		
	table = [[textCount['CONTROL'],totalCount['CONTROL']-textCount['CONTROL']],[textCount['CANCER'],totalCount['CANCER']-textCount['CANCER']]]
	pCancer = (100.0 * textCount['CANCER'])/totalCount['CANCER']
	pControl = (100.0 * textCount['CONTROL'])/totalCount['CONTROL']
	oddsratio,pvalue = stats.fisher_exact(table)
	print("%f\t%f\t%s\t[%d %f] vs [%d %f]"%(pvalue,oddsratio,text,textCount['CANCER'],pCancer,textCount['CONTROL'],pControl))