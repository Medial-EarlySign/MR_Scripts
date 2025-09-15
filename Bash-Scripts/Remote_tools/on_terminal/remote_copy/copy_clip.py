#!/usr/bin/python
import pyautogui,time,os,argparse
from datetime import datetime
clipboard_supported=False
try:
    import clipboard
    clipboard_supported=True
except:
    print('Please pip install clipboard')

def sim_keyboard(content, sleep_time=3, key_strokes_sleep=0):
    time.sleep(sleep_time)
    start_tm=datetime.now()
    print('%s:: Start write'%(start_tm))
    pyautogui.write(content, interval=key_strokes_sleep)
    end_tm=datetime.now()
    tm_diff=(end_tm-start_tm).seconds
    print('%s:: End write within %d seconds'%(end_tm, tm_diff))

def upload_txt_file(file_path, sleep_time=3, key_strokes_sleep=0):
    if not(os.path.exists(file_path)):
        raise NameError('File not found %s'%(file_path))
    f=open(file_path, 'r')
    txt=f.read()
    f.close()
    print('File %s read'%(file_path))
    sim_keyboard(txt,sleep_time,key_strokes_sleep)

def handle_focus(flag):
    if flag:
        pyautogui.hotkey('alt', 'tab', interval=0.2)

parser = argparse.ArgumentParser(description='Keyboard send')
parser.add_argument('--sleep_time', type=int, default=3, help='an integer for sleep time')
parser.add_argument('--key_strokes_sleep', type=float, default=0.003, help='time fraction between strokes')
parser.add_argument('--focus', type=int, default=0, help='If true will type Alt+Tab to return last focus after launch')

args = parser.parse_args()
text=clipboard.paste()
if len(text) >0:
    handle_focus(args.focus)
    sim_keyboard(text, args.sleep_time, args.key_strokes_sleep)
else:
    print('clipboard is empty')
    