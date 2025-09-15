#!/usr/bin/env python
import subprocess, os
from datetime import datetime

def fetch_git_last_commit(dir_path):
    res=subprocess.run('git fetch && git log -n 1 --no-color origin/master', capture_output=True, cwd=dir_path, shell=True, encoding='utf-8')
    if res.returncode !=0:
        raise NameError(res.stderr)
    res=list(filter(lambda x:len(x)>0,res.stdout.split('\n')))

    disp_id=res[0].split()[1]
    author_index=list(filter(lambda i:  res[i].startswith('Author:'), range(len(res))))
    if len(author_index) == 0:
        raise NameError('Not found git Author')
    author_index=author_index[0]
    last_author=res[author_index][8:]
    last_author=last_author[:last_author.find('<')-1]

    date_index=list(filter(lambda i:  res[i].startswith('Date:'), range(len(res))))
    if len(date_index) == 0:
        raise NameError('Not found git Date')
    date_index=date_index[0]
    last_tm=datetime.strptime(res[date_index][5:].strip()[4:-6], '%b %d %H:%M:%S %Y')

    msg=res[-1].strip()
    return disp_id,last_author,last_tm,msg

build_time = datetime.now()
disp_id,last_author,last_tm,msg=fetch_git_last_commit('/nas1/UsersData/git/MR/Libs')
full_msg='Build on %s\n=> Libs Git Head: %s by %s at %s\nLast Commit Note: %s\n##########\n'%(build_time.strftime('%d-%m-%Y_%H:%M:%S') ,disp_id, last_author, last_tm.date(), msg)

disp_id,last_author,last_tm,msg=fetch_git_last_commit('/nas1/UsersData/git/MR/Tools')
full_msg=full_msg + '=> Tools Git Head: %s by %s at %s\nLast Commit Note: %s'%(disp_id, last_author, last_tm.date(), msg)

full_msg='"' + full_msg.replace('\n', '\\n') + '"'
print(full_msg)
