#!/usr/bin/env python
import time
import os
import psutil
import daemon
from datetime import datetime, timedelta
import requests

SHUTDOWN_TIMEOUT_MINUTES = 10  # Time in minutes
CHECK_INTERVAL_SECONDS = 60    # Check interval in seconds

def get_bash_process(print_findings:bool=True):
    proc = list(filter(lambda x:x.name()=='sshd',psutil.process_iter()))
    root_proc = list(filter(lambda x:x.parent().pid==1,proc))
    assert(len(root_proc)==1)
    root_proc = root_proc[0]
    # Get bash processes and see if something is running:
    bash_proc = []
    current_nodes = [root_proc]
    while len(current_nodes) > 0:
        next_level = []
        for proc in current_nodes:
            if proc.name()=='bash':
                last_bash_proc = proc
                while len(last_bash_proc.children())==1 and last_bash_proc.children()[0].name()=='bash':
                    last_bash_proc = last_bash_proc.children()[0]
                bash_proc.append(last_bash_proc)
            else:
                next_level.extend(proc.children())
        current_nodes = next_level
    running_childs = []
    for proc in bash_proc:
        child_proc = proc.children()
        child_proc = list(filter(lambda x: x.name()!='jupyter-lab',child_proc))
        if len(child_proc)>0:
            running_childs.append([proc, child_proc])
    if print_findings:
        if len(running_childs)>0:
            print('Running processes:')
            for parent_bash, childs in running_childs:
                print(f'Running pid {parent_bash.pid} with {len(childs)} process:')
                print('\t'+'\n\t'.join( map(lambda x: f'Process status:{x.status()} cpu:{x.cpu_percent()} "{" ".join(x.cmdline())}"',childs) ))
    return running_childs

def get_jupyter_running(print_findings:bool=True):
    try:
        resp = requests.get('http://localhost:7002/api/kernels')
        js=resp.json()
        collected_ker = []
        last_activity = None
        for ker in js:
            if ker['execution_state'] == 'busy':
                collected_ker.append(ker) # "id", "last_activity", "execution_state", "connections"
            if last_activity is None or ker['last_activity']>last_activity:
                last_activity = ker['last_activity']
            
        if print_findings:
            for ker in collected_ker:
                print(f'Running {ker["id"]}, connections:{ker["connections"]}, "last_activity": {ker["last_activity"]}')
        if last_activity is not None:
            last_activity = datetime.strptime(last_activity, '%Y-%m-%dT%H:%M:%S.%fZ')
        return collected_ker, last_activity
    except:
        return None

def is_user_logged_in():
    users = psutil.users()
    return len(users) > 0

def is_pc_idle():
    is_logged_in = is_user_logged_in()
    if is_logged_in:
        return True, None
    proc = get_bash_process(False)
    if len(proc) > 0:
        return True, None
    jp_proc = get_jupyter_running(False)
    last_activity = None
    if jp_proc is not None:
        last_activity = jp_proc[1]
    if jp_proc is not None and len(jp_proc[0]) > 0:
        return True, last_activity
    return False, last_activity

def shutdown_system():
    os.system('shutdown -h now')

def run():
    last_logged_in_time = datetime.now()
    
    while True:
        is_active,last_act = is_pc_idle()
        if is_active:
            last_logged_in_time = datetime.now()
        else:
            if last_act is not None and last_act > last_logged_in_time:
                last_logged_in_time = last_act
            elapsed_time = datetime.now() - last_logged_in_time
            if elapsed_time > timedelta(minutes=SHUTDOWN_TIMEOUT_MINUTES):
                shutdown_system()
        
        time.sleep(CHECK_INTERVAL_SECONDS)

def main():
    with daemon.DaemonContext():
        run()

if __name__ == "__main__":
    main()
