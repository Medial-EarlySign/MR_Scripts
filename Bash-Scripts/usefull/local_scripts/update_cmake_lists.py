#!/usr/bin/env python
import os
from typing import Tuple
#BASE_PATH=os.path.join(os.environ['MR_ROOT'], 'Libs', 'Internal')
#BASE_PATH=os.path.join(os.environ['MR_ROOT'], 'Tools', 'AllTools')
BASE_PATH=os.path.join(os.environ['MR_ROOT'], 'Tools')
dry_run = False

TEMPLATE_CMAKE_HEADER = """cmake_minimum_required(VERSION 3.5.0)
file(GLOB SRC_FILES
     "*.h"
     "*.cpp"
)
"""
TEMPLATE_CMAKE_SUFFIX_EXECUTABLE = """
add_executable(_PROJECT_NAME ${SRC_FILES})
add_linking_flags(_PROJECT_NAME)
"""
TEMPLATE_CMAKE_SUFFIX_STATIC_LIBRAY = "add_library(_PROJECT_NAME STATIC ${SRC_FILES})"
TEMPLATE_CMAKE_SUFFIX_SHARED_LIBRAY = "add_library(_PROJECT_NAME SHARED ${SRC_FILES})"

def gen_cmake_template(project_name:str, executeable: bool = True, shared_libary:bool = True) -> str:
    res = TEMPLATE_CMAKE_HEADER
    if executeable:
        res += TEMPLATE_CMAKE_SUFFIX_EXECUTABLE.replace('_PROJECT_NAME', project_name)
    else:
        if shared_libary:
            res += TEMPLATE_CMAKE_SUFFIX_SHARED_LIBRAY.replace('_PROJECT_NAME', project_name)
        else:
            res += TEMPLATE_CMAKE_SUFFIX_STATIC_LIBRAY.replace('_PROJECT_NAME', project_name)
    return res

def test_code_dir(dir_path: str) -> bool:
    if not(os.path.isdir(dir_path)):
        return False
    all_files = os.listdir(dir_path)
    if 'CMakeLists.txt' in all_files:
        if len(list(filter(lambda x: x.endswith('.cpp') or x.endswith('.h'), all_files)))>0:
            return True
    return False

def get_state_cmake(dir_path: str) -> Tuple[bool,bool]:
    cmake = os.path.join(dir_path, 'CMakeLists.txt')
    with open(cmake) as fr:
        text = fr.read()
        is_executable = text.find('add_executable')>=0
        is_shared_library = False
        if not(is_executable):
            is_shared_library = text.find(' SHARED ') >= 0
    return [is_executable, is_shared_library]

def execute_fix(dir_path: str, dirn: str, dry_run: bool) -> None:
    if test_code_dir(dir_path):
        state = get_state_cmake(dir_path)
        lib_type = 'Shared Library' if state[1] else 'Static Library'
        print(f'Regeneate CMakeLists.txt in {dir_path} as {'Executable' if state[0] else lib_type}')
        cmake_text = gen_cmake_template(dirn, state[0], state[1])
        if not(dry_run):
            with open(os.path.join(dir_path, 'CMakeLists.txt'), 'w') as fw:
                fw.write(cmake_text)

black_list = set(['MedPyExport', 'ServerHandler'])
for dirn in os.listdir(BASE_PATH):
    full_p = os.path.join(BASE_PATH, dirn)
    if dirn in black_list:
        continue
    execute_fix(full_p, dirn, dry_run)
    if not(os.path.isdir(full_p)):
        continue
    for dirn2 in os.listdir(full_p):
        if dirn2 in black_list:
            continue
        full_p2 = os.path.join(full_p, dirn2)
        execute_fix(full_p2, dirn2, dry_run)
        if not(os.path.isdir(full_p2)):
            continue
        for dirn3 in os.listdir(full_p2):
            if dirn3 in black_list:
                continue
            full_p3 = os.path.join(full_p2, dirn3)
            execute_fix(full_p3, dirn3, dry_run)
