#!/usr/bin/env python3

import sys
import datetime
import subprocess
import tempfile
import re
import argparse
import os
from os import path
from os.path import expandvars
from os import environ as env

def eprint(*args,**kwargs):
  kwargs['file']=sys.stderr
  print(*args,**kwargs)
def pdie(*args,**kwargs):
  kwargs['file']=sys.stderr
  print(*args,**kwargs)
  sys.exit();


def open_file(fn,mode):
  #print STDERR "Opening file $fn in mode $mode\n";
  if fn== '-': fn = sys.stdin
  try:
    return open(fn, mode)
  except IOError as e:
    print(f"Couldn't open or write to file ({fn}).")

def read_text_from_file(fn):
  with open_file(fn,'r') as fh:
    return fh.read()
  
def write_text_to_file(fn, txt):
  with open_file(fn,'w') as fh:
    fh.write(txt)
  
def safe_exec(cmd, exitOnError=True):
  #eprint(f'"{cmd}" starting on '+str(datetime.datetime.now()))
  sp = subprocess.run(cmd,shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  rc = sp.returncode
  #eprint(f'"{cmd}" finished execution on '+str(datetime.datetime.now()))
  if rc != 0:
    eprint(f'ERROR: Bad exit code {rc} on running "{cmd}"')
    if exitOnError:
      import traceback as tb
      tb.print_stack()
      sys.exit();

def safe_backtick(cmd):
  #eprint(f'"{cmd}" starting on '+str(datetime.datetime.now()))
  sp = subprocess.run(cmd,shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE, universal_newlines=True)
  rc = sp.returncode
  #eprint(f'"{cmd}" finished execution on '+str(datetime.datetime.now()))
  if rc != 0:
    eprint(f'Bad exit code {rc}')
    sys.exit();
  return sp.stdout


### main ###

ap = argparse.ArgumentParser()
ap.add_argument("--cmake_top_level_templ", type=str, default=expandvars('${MR_ROOT}/Projects/Resources/CMakeUtils/CmakeTopLevelTemplate.txt'),
  help="file name with template for top level CMakeLists.txt in library repositories (VS solution)")
ap.add_argument("--cmake_base_level_templ", type=str, default=expandvars('${MR_ROOT}/Projects/Resources/CMakeUtils/CmakeBaseLevelTemplate.txt'),
  help="file name with template for base level CMakeLists.txt in library repositories (VS project)")
ap.add_argument("--skip_sol_list", type=str, default="",
  help="list of solutions to ignore (comma separated, no spaces)")
ap.add_argument("--desired_sol_list", type=str, default="",
  help="list of solutions to work on (comma separated, no spaces)")
ap.add_argument("--run_make", default=0,
  help="whether to run 'make' after generating the Makefiles")
ap.add_argument("--j_make", type=int, default=8,
  help="number of threads for make")
ap.add_argument("--shared_libs", default=0,
  help="add build of shared libraries")
ap.add_argument("--log_infra", default=False, action='store_true',
  help="whather or not print and log infra libs compilation")
ap.add_argument("--new_compiler", default=False, action='store_true',
  help="if compile with the new compiler")
ap.add_argument("--shared_lib_folder", default='/server/Work/SharedLibs/linux/lib64/', type=str,
  help="library to compiler and work with")
ap.add_argument("--cwd", default=False, action='store_true',
  help="Operate on current working directory")
p = ap.parse_args()

eprint('Command line:' , ' '.join(sys.argv))
eprint('Parameters: ', vars(p))


# list of Medial Libs to skip
skipMedialLibs = {'AlgoLib' : True}

# list of libraries to ignore as dependencies
ignoreLibsStr = "kernel32.lib;user32.lib;gdi32.lib;winspool.lib;comdlg32.lib;advapi32.lib;shell32.lib;ole32.lib;oleaut32.lib;uuid.lib;odbc32.lib;odbccp32.lib"
ignoreLibsStr = ignoreLibsStr.replace('.lib','')
ignoreLibAsDep = { x:True for x in ignoreLibsStr.split(';')}

# list of external libraries that appear as named dependencies in vcxproj files
extNamedLibs = {'libxl' : env['LIBXL_LIB']}

# read CMakeLists.txt templates
cmakeTopLevelTxt = read_text_from_file(p.cmake_top_level_templ);
cmakeBaseLevelTxt = read_text_from_file(p.cmake_base_level_templ);

vcxprojFiles=[]
libFiles = []

if not p.cwd:
  toplevel_vcx_scan_dir = env["MR_ROOT"]
else:
  toplevel_vcx_scan_dir = env["MR_ROOT"] + '/Libs'

fout = safe_backtick(f'find {toplevel_vcx_scan_dir} -name \'*.vcxproj\'')
for line in fout.splitlines():
  if 'AutoRecover' in line: continue
  if not p.cwd and not (f'{env["MR_ROOT"]}/Libs' in line 
    or f'{env["MR_ROOT"]}/Projects' in line 
    or f'{env["MR_ROOT"]}/Tools' in line): continue
  vcxprojFiles.append(line.rstrip())
#eprint(vcxprojFiles.__repr__())

if p.cwd: libFiles = vcxprojFiles

slnFiles = []
if p.cwd:
  fout = safe_backtick(f'find . -name \'*.sln\'')
  for line in fout.splitlines():
    if 'AutoRecover' in line: continue
    slnFiles.append(line.rstrip())
    
if p.log_infra:
	if p.cwd: eprint('slnFiles' + ', '.join(slnFiles))
	else: eprint('vcxprojFiles' + ', '.join(vcxprojFiles))

# insert given list of solutions to skip
solCmake = { x:{'ignore':True} for x in p.skip_sol_list.split(',') }

dSolList = p.desired_sol_list.split(',')

projCmake = {}
medialLibPath = {}

if p.cwd:
  for libPrj in vcxprojFiles:
    if libPrj=='': continue
    inMedialLibs = True
    if 'xgboost' in libPrj: inMedialLibs = False
    projText = read_text_from_file(libPrj)
    isLib = re.search(r'Library</ConfigurationType', projText) is not None
    projName = path.basename(path.dirname(libPrj))
    if isLib and inMedialLibs:
      path_to = path.dirname(libPrj)
      if p.log_infra:
        eprint(f'debug: path_to: {path_to}')
      medialLibPath[projName] = path_to
  vcxprojFiles=[]
  for sln in slnFiles:
    if sln=='': continue
    fullPath_sln = path.abspath(path.dirname(sln))
    eprint(f'Scanning Solution {sln} Solution Dir: {fullPath_sln} .')
    slnkey = path.splitext(path.basename(sln))[0]
    solCmake.setdefault(slnkey,{})['name'] = slnkey
    solCmake.setdefault(slnkey,{})['path'] = fullPath_sln
    for line in read_text_from_file(sln).splitlines():
      if not line.startswith('Project'): continue
      proj_path = line.split('=')[1].split(',')[1].strip().strip('"')
      inMedialLibs = '/Libs/' in proj_path or '\\Libs\\' in proj_path
      if inMedialLibs: continue
      if not proj_path: continue
      if proj_path=="Solution Items": continue
      proj_path = proj_path.replace('\\','/')
      if p.log_infra:
        eprint(proj_path)
      vcxprojFiles.append(path.abspath(path.join(path.dirname(sln), proj_path)))
#      eprint("adding "+path.abspath(path.join(path.dirname(sln), proj_path)))
#      eprint("from line '"+line+"'")
      

#for vcx in vcxprojFiles:
#  eprint(f"vcx = {vcx}")
        
#if not p.cwd:
for vcx in vcxprojFiles:
  m = re.match(r'(?P<basePath>.*?)/(?P<solName>[^/]+)/(?P<projName>[^/]+)/(?P<projFileName>[^/]+)\.vcxproj$', vcx)
  if not m: 
    pdie(f"Wrong vcxproj path: {vcx}")
  locals().update((m.groupdict()))
  inMedialLibs = env['MR_ROOT'] + '/Libs' in basePath
  inDesiredSol = solName in dSolList
  if projFileName != projName:
    if p.log_infra or inDesiredSol:
      eprint("WARNING: Incompatibe Project dir and vcxproj names: {0}, {1}, {2}, {3}!={4}".format(vcx,basePath,solName, projName, projFileName))
    continue
  if not solName in solCmake: solCmake[solName] = { f'{solName}/{projName}':{}  }
  solCmake[solName]['path'] = path.join(basePath,solName)
  projText = read_text_from_file(vcx);


  if 'xgboost' in vcx: inMedialLibs = False
  isLib = re.search(r'Library</ConfigurationType', projText) is not None
  isSharedLib = re.search(r'DynamicLibrary</ConfigurationType', projText) is not None
  if p.log_infra or inDesiredSol:
    print(f"Solution: {solName}\tProject: {projName}\tinMedialLibs: {inMedialLibs}\tisLib: {isLib}")

  if isLib and inMedialLibs and projName in skipMedialLibs:
    solCmake[solName]['ignore'] = True
    if p.log_infra or inDesiredSol:
      eprint(f"Solution {solName} under MEDIAL_LIBS relies on a MEDIAL_LIBS libarary {projName} which is not included in the list of applicable MEDIAL_LIBS; Solution is ignored")
    continue

  # assumes that there are no two same-named libraries in different MEDIAL_LIBS repositories
  if isLib and inMedialLibs:
    path_to = path.dirname(vcx)
    if p.log_infra or inDesiredSol:
      eprint(f"debug: path_to: {path_to}")
    medialLibPath[projName] = path_to


  if 'projList' not in solCmake[solName]: solCmake[solName]['projList'] = []
  projKey = f'{solName}/{projName}'
  solCmake[solName]['projList'].append(projKey)
  if f'{solName}/{projName}' not in projCmake: projCmake[ f'{solName}/{projName}'] = {}
  projCmake[projKey]['name'] = projName
  projCmake[projKey]['path'] = f"{basePath}/{solName}/{projName}"
  projCmake[projKey]['isLib'] = isLib
  projCmake[projKey]['isSharedLib'] = isSharedLib
  projCmake[projKey]['inMedialLibs'] = inMedialLibs
  projCmake[projKey]['inDesiredSol'] = inDesiredSol

  if p.log_infra or inDesiredSol:
    eprint('debug: ',projCmake[projKey].__repr__())

  if not isLib:
    """ Executable """
    for (depStr) in re.findall(r'<AdditionalDependencies>(\S+)</AdditionalDependencies>',projText):
      if p.log_infra:
        eprint(f'Dependencies for {solName}/{projName}: {depStr}')
      projCmake[projKey]['depAllInternal'] = '$(MR_LIBS_NAME)' in depStr
      depStr = re.sub(r'\$\(MR_LIBS_NAME\);*','',depStr)
      for (depLib,*rest) in re.findall(r'(\S+?)\.lib(;*)', depStr):
        if p.log_infra:
          eprint(f'debug: depStr: {depStr} :: {depLib}')
        if depLib in ignoreLibAsDep:
          if p.log_infra:
            eprint(f'Ignoring {depLib} as a dependency.')
        elif  depLib in extNamedLibs:
          projCmake[projKey].setdefault('extDepList',{})[depLib] = True
        else:
          """different from alon's here"""
          projCmake[projKey].setdefault('depList',{})[depLib] = True
          solCmake[solName].setdefault('depList',{})[depLib] = True

    projCmake[projKey]['depBoostPO'] = re.search('boost',projText,re.IGNORECASE) is not None
    projCmake[projKey]['depXGBoostPO'] = re.search('xgboost',projText,re.IGNORECASE) is not None
    projCmake[projKey]['depVWPO'] = re.search('libvw',projText,re.IGNORECASE) is not None

    if projCmake[projKey].setdefault('depAllInternal',False):
      internal_libs = re.split(r'\.lib;*',env['MR_LIBS_NAME'])
      internal_libs.remove('')
      for lib_name in internal_libs:
        projCmake[projKey].setdefault('depList',{})[lib_name] = True
        solCmake[solName].setdefault('depList',{})[lib_name] = True
      projCmake[projKey]['depXGBoostPO'] = True
    
eprint('Finished scanning vcxproj files')

solList = list(sorted((solCmake.keys())))
solList.remove('')

#Regenerate all Libs h, cpp files:
if p.cwd:
  for libPrj in libFiles:
    if not libPrj: continue
    baseTxt = cmakeBaseLevelTxt
    projName = path.basename(path.dirname(libPrj))
    projPath = path.abspath(path.dirname(libPrj))
    projText = read_text_from_file(libPrj)
    isSharedLib = 'DynamicLibrary</ConfigurationType' in projText
    
    h_files_txt = safe_backtick(f'find {projPath} -name "*.h" -o -name "*.hpp" | sort')
  
    h_files = []
    for hfile in h_files_txt.splitlines():
      hfile = hfile.rstrip()
      hfile = hfile.replace(projPath+'/','')
      h_files.append(hfile)
    h_files_txt = h_files_txt.replace(projPath+'/','\t')
    src_files_txt = safe_backtick(f'find {projPath} -name "*.c" -o -name "*.cpp"| sort')
    src_files_txt = src_files_txt.replace(projPath+'/','\t')
  
    baseTxt = baseTxt.replace('_H_FILES_TXT_',h_files_txt)
    baseTxt = baseTxt.replace('_SRC_FILES_TXT_',src_files_txt)
  
    addTargetTxt= f'add_library({projName} STATIC ' + '${H_FILES} ${SRC_FILES})\n'
    if p.shared_libs or isSharedLib:
      addTargetTxt += f'add_library(dyn_{projName} SHARED ' + '${H_FILES} ${SRC_FILES})\n'
    baseTxt = baseTxt.replace('_ADD_TARGET_TXT_', addTargetTxt)
    write_text_to_file(f"{projPath}/CMakeLists.txt", baseTxt)


for solName in solList:
  if 'ignore' in solCmake[solName]:
    eprint(f'\nSkipping solution {solName}')
    continue
  addSubdirTxt = ''
  printed_sol_name = False
  if not p.cwd:
    for uniqProjName in solCmake[solName]['projList']:
      projName = projCmake[uniqProjName]['name']
      solCmake[solName].setdefault('depList',{})[projName] = False  # mark local dependencies

  uniqueFullName={}
  for uniqProjName in solCmake[solName]['projList']:
    projName = projCmake[uniqProjName]['name']

    if not projName in uniqueFullName:
      if p.cwd: addSubdirTxt += f'add_subdirectory({projCmake[uniqProjName]["path"]} {projName})\n'
      else: addSubdirTxt += f'add_subdirectory({projName})\n'
      uniqueFullName[projName] = True

    baseTxt = cmakeBaseLevelTxt

    # get the lists of header and source files and plug into the project level (base) CMake file
    projPath = projCmake[uniqProjName]['path']
    h_files_txt = safe_backtick(f'find {projPath} -name "*.h" -o -name "*.hpp" | sort')

    h_files = h_files_txt.splitlines()
    if p.log_infra or projCmake[uniqProjName]['inDesiredSol']:
      eprint(f'{h_files}')
    
    h_files = [ x.rstrip().replace(projPath+'/','') for x in h_files]
    if p.log_infra or projCmake[uniqProjName]['inDesiredSol']:
      eprint(f'{h_files}')

    h_files_txt = h_files_txt.replace(projPath+'/','\t')
    src_files_txt = safe_backtick(f'find {projPath} -name "*.c" -o -name "*.cpp"| sort')
    src_files_txt = src_files_txt.replace(projPath+'/','\t')

    baseTxt = baseTxt.replace('_H_FILES_TXT_', h_files_txt)
    baseTxt = baseTxt.replace('_SRC_FILES_TXT_', src_files_txt)
    
    addTargetTxt = ''
    
    if p.log_infra or projCmake[uniqProjName]['inDesiredSol']:
      if not printed_sol_name:
        eprint(f'\nWorking on solution {solName} ({solCmake[solName]["path"]})')
        printed_sol_name = True
      eprint(f'debug 235: projCmake={projCmake} uniqProjName={uniqProjName} isLib {projCmake[uniqProjName]["isLib"]}')
    if projCmake[uniqProjName]['isLib']:
      addTargetTxt += f'add_library({projName} ' + 'STATIC ${H_FILES} ${SRC_FILES})\n'
      if p.shared_libs or projCmake[uniqProjName]['isSharedLib']:
        addTargetTxt += f'add_library(dyn_{projName} ' + 'SHARED ${H_FILES} ${SRC_FILES})\n';
    else:
      """ executable """
      addTargetTxt += f'add_executable({projName} ' + '${H_FILES} ${SRC_FILES})\n'
      linkLibList = []
      internalLibList = []
      if 'depList' in projCmake[uniqProjName]:
        # LOCAL or in MEDIAL_LIBS
        depLibList = []
        for item in sorted(projCmake[uniqProjName]['depList'].keys()):
          if (not solCmake[solName]['depList'][item]) or item in medialLibPath:
            depLibList.append(item)
        # each dependency library appears three times in order to resolve inter-library calls
        internalLibList = depLibList
      
      # external libraries - special treatment for Boost program_options library which does not appear explicitly in the vcxproj files
      if 'extDepList' in projCmake[uniqProjName]:
        extDepList = sorted(projCmake[uniqProjName]['extDepList'].keys())
        linkLibList = [extNamedLibs[x] for x in extDepList]
      
      if projCmake[uniqProjName]['depBoostPO']:
        linkLibList.append('libboost_regex.so')
        linkLibList.append('libboost_program_options.so')
        linkLibList.append('libboost_filesystem.so')
        linkLibList.append('libboost_system.so')
      
      if projCmake[uniqProjName]['depXGBoostPO']:
        linkLibList.append('/server/Work/SharedLibs/linux/lib64/${CMAKE_BUILD_TYPE}/libxgboost.so')
        if not p.new_compiler:
          linkLibList.append(p.shared_lib_folder + '${CMAKE_BUILD_TYPE}/lib_lightgbm.so')
        else:
          linkLibList.append('/server/Work/SharedLibs/linux/gcc-7.2_lib64/${CMAKE_BUILD_TYPE}/lib_lightgbm.so')
      if projCmake[uniqProjName]['depVWPO'] and p.new_compiler:
        linkLibList.append('/usr/local/lib/libvw.so')
        linkLibList.append('/usr/local/lib/libvw_c_wrapper.so')
      
      if len(linkLibList) > 0:
        addTargetTxt += f'target_link_libraries({projName} -Wl,--start-group ' + ' '.join(internalLibList) + ' -Wl,--end-group ' + ' '.join(linkLibList) + ')\n'
    baseTxt = baseTxt.replace('_ADD_TARGET_TXT_',addTargetTxt)
    write_text_to_file(f'{projPath}/CMakeLists.txt', baseTxt)  

  # we assume that a solution depends only on libraries under MEDIAL_LIBS or in-solution libraries or libraries in , and not libraries from other MEDIAL_PROJECTS solutions
  if 'depList' in solCmake[solName]:
    # need to handle correctly MEDIAL_LIBS vs. in-solution
    for solDep in sorted(solCmake[solName]['depList'].keys()):
      depNotLocal = solCmake[solName]['depList'][solDep] # local (in-solution) libraries have already been added as direct subdirs
      if depNotLocal:
        # $solDep must now be either a MEDIAL_LIBS library or an unsupported external library;
        # an unsupported library is ignored and the CMake file for the solution is incomplete, but this solution is actually not aplicable for the type of build provided by this script
        if not solDep in medialLibPath:
          if p.log_infra:
            eprint(f"Dependency '{solDep}' for solution '{solName}' is not under MEDIAL_LIBS and is skipped")
        else:
          addSubdirTxt += f'add_subdirectory({medialLibPath[solDep]} {solDep})\n' # adding as indirect subdir
  

  topTxt = cmakeTopLevelTxt
  topTxt = topTxt.replace('_SOLNAME_', solName)
  topTxt = topTxt.replace('_ADD_SUBDIR_TXT_', addSubdirTxt)
  if p.new_compiler:
    topTxt =re.sub(r'(.*include_directories[^\n\r]*)',r'\1\ninclude_directories(/server/Linux/alon/packages/boost_1_63_0)',topTxt)
  write_text_to_file(f"{solCmake[solName]['path']}/CMakeLists.txt", topTxt)

# restricting CMake runs to a desired list of solutions, if required
if p.desired_sol_list != "":
  desSolList = p.desired_sol_list.split(',')
  [ pdie(f'Desired solution {x} is not in the list of solutions found in file system') for x in desSolList if not x in solCmake]
  solList = desSolList

eprint('Going to work on solutions:' + ', '.join(solList))
for solName in solList:
  if 'ignore' in solCmake[solName]:
    eprint(f'\nSkipping solution {solName}')
    continue
  eprint(f'\nRunning CMake on solution {solName} ({solCmake[solName]["path"]})')
  for buildType in ['Release', 'Debug']:
    buildDir = f'{solCmake[solName]["path"]}/CMakeBuild/Linux/{buildType}'
    safe_exec(f'mkdir -p {buildDir}')
    os.chdir(buildDir)
    if not p.new_compiler:
      safe_exec(f'cmake -DCMAKE_BUILD_TYPE={buildType} -DCMAKE_C_COMPILER="/usr/bin/gcc" -DCMAKE_CXX_COMPILER="/usr/bin/c++" "Unix Makefiles" ../../../', exitOnError=False)
    else:
      safe_exec(f'cmake -DCMAKE_BUILD_TYPE={buildType} -DCMAKE_C_COMPILER=/usr/local/bin/gcc -DCMAKE_CXX_COMPILER=/usr/local/bin/c++ -DCMAKE_EXE_LINKER_FLAGS=" -static-libstdc++" "Unix Makefiles" ../../../', exitOnError=False)
    if p.run_make:
      eprint(f'\n>>>>>>>>> Start building solution {solName} in mode {buildType}')
      safe_exec(f'make -j {p.j_make}', exitOnError=False)
      eprint(f'<<<<<<<<< Finished building solution {solName} in mode {buildType}\n')

