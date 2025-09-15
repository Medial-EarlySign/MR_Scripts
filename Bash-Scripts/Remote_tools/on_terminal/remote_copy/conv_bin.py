import os,base64,argparse,hashlib

def conv_fp(fp, sp):
    if not(os.path.exists(fp)):
        raise NameError('file not exist %s'%(fp))
    f=open(fp, 'r')
    txt=f.read()
    f.close()
    bin=base64.b64decode(txt)
    fw=open(sp, 'wb')
    fw.write(bin)
    fw.close()
    md5=hashlib.md5(bin).hexdigest()
    print('COnverted to %s\nMD5: %s'%(sp,md5))
    
parser=argparse.ArgumentParser(description="Convert")
parser.add_argument('input', help='input')
parser.add_argument('output', help='output')

args=parser.parse_args()

res=conv_fp(args.input, args.output)