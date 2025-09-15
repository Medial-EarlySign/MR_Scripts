#!/opt/medial/dist/usr/bin/python
import os
import sys
import pandas as pd

full_file = sys.argv[1]
all_df = pd.DataFrame()
for kp_labs in pd.read_sas(full_file, chunksize=500000, iterator=True, encoding='latin-1'):
    print(kp_labs)
    all_df = all_df.append(kp_labs)
all_df.to_csv(sys.argv[1], sep='\t') 
print('DONE')
    