#!/usr/bin/python
import pyautogui,time,os,argparse,base64,math,hashlib
from datetime import datetime
from SendMsg import SendMsg

def md5(fname):
    with open(fname, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()

def sim_keyboard(content, sleep_time=3, key_strokes_sleep=0, blocks=10000):
    time.sleep(sleep_time)
    start_tm=datetime.now()
    print('%s:: Start write'%(start_tm))
    step_cnt=math.ceil(len(content)/blocks)
    iter=0
    len_full=len(content)
    while len(content)>0:
        curr_block=content[:blocks]
        pyautogui.write(curr_block, interval=key_strokes_sleep)
        content=content[blocks:]
        steps_took=(datetime.now()-start_tm).seconds
        iter=iter+1
        if step_cnt >0 and len(content) > 0:
            complete_ratio=(iter*blocks)/len_full
            est=(1-complete_ratio)/complete_ratio*steps_took/60
            if steps_took >60:
                print('Update %d/%d(%2.1f%%) - time elapsed %2.1f minutes, estimated %2.1f minutes'%(iter,step_cnt, 100.0*complete_ratio, steps_took/60.0,est))
            else:
                print('Update %d/%d(%2.1f%%) - time elapsed %2.1f seconds, estimated %2.1f minutes'%(iter,step_cnt, 100.0*complete_ratio, steps_took,est))
    end_tm=datetime.now()
    tm_diff=(end_tm-start_tm).seconds
    print('%s:: End write within %d seconds of %d chars'%(end_tm, tm_diff, len_full))

def upload_txt_file(file_path, is_binary, sleep_time=3, key_strokes_sleep=0, blocks=10000):
    if not(os.path.exists(file_path)):
        raise NameError('File not found %s'%(file_path))
    read_flags='r'
    if is_binary:
        read_flags='rb'
    f=open(file_path, read_flags)
    txt=f.read()
    f.close()
    if is_binary:
        txt = base64.b64encode(txt).decode('ascii')
    print('File %s read(binary=%d), length=%d'%(file_path,is_binary, len(txt)))
    sim_keyboard(txt,sleep_time,key_strokes_sleep,blocks)
    return len(txt)

def prepare_open_file(f_name, key_strokes_sleep):
    time.sleep(3)
    f_name=f_name.replace(" ","_")
    cmd='echo -ne %s.txt\n'%(f_name)
    pyautogui.write(cmd, interval=key_strokes_sleep)
    time.sleep(1)
    cmd='vim %s.txt\n'%(f_name)
    pyautogui.write(cmd, interval=key_strokes_sleep)
    time.sleep(1)
    pyautogui.write('i', interval=key_strokes_sleep)
def prepare_close_file(f_name, md5, key_strokes_sleep, do_conv):
    f_name=f_name.replace(" ","_")
    #escape and than :wq
    time.sleep(8)
    pyautogui.press('esc')
    time.sleep(2)
    pyautogui.write(':wq\n', interval=key_strokes_sleep)
    
    cmd='echo -ne "%s\\t%s\n" > %s.md5\n'%(md5, f_name, f_name)
    pyautogui.write(cmd, interval=key_strokes_sleep)
    
    if do_conv:
        time.sleep(3)
        cmd='conv_bin.py %s.txt %s\n'%(f_name, f_name)
        pyautogui.write(cmd, interval=key_strokes_sleep)
        #check MD5
        cmd='md5sum -c %s.md5\n'%(f_name)
        pyautogui.write(cmd, interval=key_strokes_sleep)
    
    
parser = argparse.ArgumentParser(description='Keyboard send')
parser.add_argument('--sleep_time', type=int, default=3, help='an integer for sleep time')
parser.add_argument('--key_strokes_sleep', type=float, default=0.001, help='time fraction between strokes')
parser.add_argument('--is_binary', type=int, default=0, help='Flag to indicate if file is binary')
parser.add_argument('--blocks', type=int, default=5000, help='update interval')
parser.add_argument('--input', default='', help='input text by command')
parser.add_argument('--send_msg', type=int, default=0, help='If true will send message when finished')
parser.add_argument('--open_close_file', type=int, default=0, help='If true will open and close file - will assert in terminal')
parser.add_argument('--do_conv', type=int, default=0, help='If true will also do conv_bin')

args = parser.parse_args()
if len(args.input) >0:
    raw_s=r'{}'.format(args.input)
else:
    try:
        input = raw_input("Enter input: ")
        raw_s = r'{}'.format(input)
    except:
        input = input("Enter input: ")
        raw_s = r'{}'.format(input)
file_name_clean=os.path.basename(raw_s)
if args.open_close_file:
    prepare_open_file(file_name_clean, args.key_strokes_sleep) 
txt_len=upload_txt_file(raw_s, args.is_binary, args.sleep_time, args.key_strokes_sleep, args.blocks)
md5_txt=md5(raw_s)
if args.send_msg > 0:
    m=SendMsg('', '', None, None)
    file_name_clean_m=file_name_clean.replace('_','\\_')
    send_msg_text='File Transfer completed!\nFile: %s\nFile Length: %d\nMD5: %s'%(file_name_clean_m, txt_len, md5_txt)
    m.send_alert(send_msg_text)
    #print(res)
print('MD5 for %s is %s'%(raw_s, md5_txt))
if args.open_close_file:
    prepare_close_file(file_name_clean, md5_txt, args.key_strokes_sleep, args.do_conv)
