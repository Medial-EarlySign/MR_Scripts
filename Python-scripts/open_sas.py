#!/opt/medial/dist/usr/bin/python

import sys
from sas7bdat import SAS7BDAT

with SAS7BDAT(sys.argv[1], skip_header=True) as reader:
	print(reader.header)
	for row in reader:
		print(row)

