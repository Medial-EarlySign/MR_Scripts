#!/opt/medial/dist/usr/bin/python
import os
import sys
import pandas as pd
import argparse as ap
import datetime as dt

parser = ap.ArgumentParser(description = "dates to days")
parser.add_argument('--in_file',help='input file',type=str,required=True)
parser.add_argument('--out_file',help='output file',type=str,required=True)
parser.add_argument('--sep',default='\t',help='separator',type=str)
parser.add_argument('--col_name',help='name of date columns', type=str,required='True')
args = parser.parse_args()

df = pd.read_csv(args.in_file,sep=args.sep)
df['days_'] = pd.to_datetime(df[args.col_name].apply(str), format='%Y%m%d', errors='coerce')
df['epochDate'] = 19000101
df['epochDays'] = pd.to_datetime(df.epochDate.apply(str), format='%Y%m%d', errors='coerce')
df['delta_'] = (df.days_ - df.epochDays)
df['__days__'] =  df['delta_'].apply(lambda x: x.days)
del df['days_']
del df['delta_']
del df['epochDate']
del df['epochDays']

df.to_csv(args.out_file,sep=args.sep,index=None)


    