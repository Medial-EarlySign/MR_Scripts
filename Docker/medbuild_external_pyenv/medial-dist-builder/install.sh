#!/bin/bash

# sudo docker run -it --name test11 centos:7.1.1503 /bin/bash

INFOP="(II) INFO: "
MEDIAL_BASE=/opt/medial
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH
echo "${INFOP}Script working path: ${SCRIPTPATH}"
DLDIR="${SCRIPTPATH}/downloads"
BLDIR="${SCRIPTPATH}/build"
LGDIR="${SCRIPTPATH}/log"
CFDIR="${SCRIPTPATH}/conf"
DIST_RELEASE_PATH=/tmp
RELEASE_PATH=/tmp
DODL=true
DOBL=true
DORL=false
DODRL=false
DORLONLY=false


function install_req_centos7 {
if [ -f "$DLDIR/INSTALL_REQ" ] ; then
return 0
fi
yum remove fakesystemd-1-17.el7.centos.noarch -y 1>${LGDIR}/yum_out.log 2>${LGDIR}/yum_err.log
yum install sudo tar yum-utils make wget openssl-devel curl-devel cairo-devel libicu libicu-devel hostname xz-devel -y 1>>${LGDIR}/yum_out.log 2>>${LGDIR}/yum_err.log
yum-builddep python -y 1>>${LGDIR}/yum_out.log 2>>${LGDIR}/yum_err.log
yum-builddep R -y 1>>${LGDIR}/yum_out.log 2>>${LGDIR}/yum_err.log
yum-builddep openssl -y 1>>${LGDIR}/yum_out.log 2>>${LGDIR}/yum_err.log
#yum install xorg-x11-server-devel libX11-devel libXt-devel -y # <- for R
yum groupinstall 'Development Tools' -y 1>>${LGDIR}/yum_out.log 2>>${LGDIR}/yum_err.log
touch $DLDIR/INSTALL_REQ
}

################################################################## python 3


function install_python3 {


PYVER="3.6.10"
PYNAM="python36"
PYFILE="Python-${PYVER}.tgz"
PYLINK="https://www.python.org/ftp/python/${PYVER}/${PYFILE}"
INFOP="(II) INFO ${PYNAM}: "

SVER=${PYVER}
SNAM=${PYNAM}
SFILE=${PYFILE}
SLINK=${PYLINK}

if [ ! -f "$DLDIR/${PYFILE}" ]; then
echo "${INFOP}Getting file from: '${PYLINK}'"
wget ${PYLINK} -O ${DLDIR}/${PYFILE}
else
echo "${INFOP}Found file: '${DLDIR}/${PYFILE}'"
fi
cd $BLDIR
tar zxf "${DLDIR}/${PYFILE}"

MEDIAL_PYTHON_ROOT=${MEDIAL_BASE}/dist
MEDIAL_PYTHON_PREFIX=${MEDIAL_PYTHON_ROOT}/usr

mkdir -p $MEDIAL_PYTHON_ROOT
mkdir -p /etc$MEDIAL_PYTHON_ROOT
mkdir -p /var$MEDIAL_PYTHON_ROOT/lib
mkdir -p /var$MEDIAL_PYTHON_ROOT/jupyter_kernels

ln -f -s ${MEDIAL_PYTHON_ROOT} ${MEDIAL_BASE}/${PYNAM}

ENABLE_FILE=$MEDIAL_PYTHON_ROOT/enable
echo "${INFOP}Creating: '${ENABLE_FILE}'"
echo "export PATH=$MEDIAL_PYTHON_PREFIX/bin\${PATH:+:\${PATH}}" > $ENABLE_FILE
echo "export LD_LIBRARY_PATH=$MEDIAL_PYTHON_PREFIX/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" >> $ENABLE_FILE
echo "export MANPATH=$MEDIAL_PYTHON_PREFIX/share/man:\$MANPATH" >> $ENABLE_FILE
echo "export PKG_CONFIG_PATH=$MEDIAL_PYTHON_PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}" >> $ENABLE_FILE
echo "export XDG_DATA_DIRS=\"$MEDIAL_PYTHON_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"" >> $ENABLE_FILE
echo "export PYTHON_LIBRARY=$MEDIAL_PYTHON_PREFIX/lib/libpython3.so" >> $ENABLE_FILE
echo "export PYTHON_INCLUDE_DIR=$MEDIAL_PYTHON_PREFIX/include/python3.6m" >> $ENABLE_FILE
echo "export BOKEH_RESOURCES=inline" >> $ENABLE_FILE
#echo 'export JUPYTER_RUNTIME_DIR="/nas1/Work/Shared/nbconnection-files/"`hostname`"/jupyter"' >> $ENABLE_FILE
echo "export JUPYTER_RUNTIME_DIR=/var$MEDIAL_PYTHON_ROOT/jupyter_kernels" >> $ENABLE_FILE
#echo "export PYTHONHOME=$MEDIAL_PYTHON_PREFIX" >> $ENABLE_FILE

echo "${INFOP}Compiling ${BLDIR}/Python-${PYVER}"

MAKECOMPLETE="${DLDIR}/MAKE_${PYNAM}"

if [ ! -f "${MAKECOMPLETE}" ] ; then

cd "${BLDIR}/Python-${PYVER}"

CXX="g++" \
CFLAGS="-I$MEDIAL_PYTHON_PREFIX/include -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -D_GNU_SOURCE -fPIC -fwrapv" \
LDFLAGS="-L$MEDIAL_PYTHON_PREFIX/lib -Wl,-z,relro -Wl,-rpath,$MEDIAL_PYTHON_PREFIX/lib -Wl,--enable-new-dtags" \
CPPFLAGS="-I$MEDIAL_PYTHON_PREFIX/include" \
PKG_CONFIG_PATH="$MEDIAL_PYTHON_PREFIX/lib/pkgconfig::$MEDIAL_PYTHON_PREFIX/lib/pkgconfig:$MEDIAL_PYTHON_PREFIX/share/pkgconfig" \
./configure \
--build=x86_64-redhat-linux-gnu \
--host=x86_64-redhat-linux-gnu \
--program-prefix= \
--prefix=$MEDIAL_PYTHON_PREFIX \
--exec-prefix=$MEDIAL_PYTHON_PREFIX \
--bindir=$MEDIAL_PYTHON_PREFIX/bin \
--sbindir=$MEDIAL_PYTHON_PREFIX/sbin \
--sysconfdir=/etc$MEDIAL_PYTHON_ROOT \
--datadir=$MEDIAL_PYTHON_PREFIX/share \
--includedir=$MEDIAL_PYTHON_PREFIX/include \
--libdir=$MEDIAL_PYTHON_PREFIX/lib \
--libexecdir=$MEDIAL_PYTHON_PREFIX/libexec \
--localstatedir=/var$MEDIAL_PYTHON_ROOT \
--sharedstatedir=/var$MEDIAL_PYTHON_ROOT/lib \
--mandir=$MEDIAL_PYTHON_PREFIX/share/man \
--infodir=$MEDIAL_PYTHON_PREFIX/share/info \
--enable-ipv6 \
--enable-shared \
--with-computed-gotos=yes \
--with-dbmliborder=gdbm:ndbm:bdb \
--with-system-expat \
--with-system-ffi \
--enable-loadable-sqlite-extensions \
--with-dtrace \
--with-valgrind \
--without-ensurepip \
build_alias=x86_64-redhat-linux-gnu \
host_alias=x86_64-redhat-linux-gnu \
 2>${LGDIR}/${SNAM}-conf-err.log 1>${LGDIR}/${SNAM}-conf-out.log

#--enable-optimizations \

make 2>${LGDIR}/${SNAM}-make-err.log 1>${LGDIR}/${SNAM}-make-out.log && \
make altinstall 2>${LGDIR}/${SNAM}-inst-err.log 1>${LGDIR}/${SNAM}-inst-out.log && \
touch ${MAKECOMPLETE}

cd ..
fi

echo "${INFOP}Creating symlinks"
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/pydoc3.6 $MEDIAL_PYTHON_PREFIX/bin/pydoc3
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/pydoc3 $MEDIAL_PYTHON_PREFIX/bin/pydoc
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python3.6 $MEDIAL_PYTHON_PREFIX/bin/python3
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python3 $MEDIAL_PYTHON_PREFIX/bin/python
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python3.6m-config $MEDIAL_PYTHON_PREFIX/bin/python3.6-config
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python3.6-config $MEDIAL_PYTHON_PREFIX/bin/python3-config
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python3-config $MEDIAL_PYTHON_PREFIX/bin/python-config
ln -f -s $MEDIAL_PYTHON_PREFIX/lib $MEDIAL_PYTHON_PREFIX/lib64

echo "import sys; sys.path.append('/opt/medial/python36/usr/lib/python3.6'); sys.path.append('/opt/medial/python36/usr/lib/python3.6/lib-dynload');" > $MEDIAL_PYTHON_PREFIX/lib/python3.6/site-packages/sitecustomize.py
cat >>$MEDIAL_PYTHON_PREFIX/lib/python3.6/site-packages/sitecustomize.py <<- EOM
import sysconfig as sc
import os
pfx = sc._CONFIG_VARS['prefix']
if 'anaconda2' in pfx: dist_name = 'anaconda-python27'
elif '/opt/medial/python27' in pfx: dist_name = 'medial-python27'
elif '/opt/medial/dist' in pfx: dist_name = 'medial-python36'
elif '/usr' == pfx: dist_name = 'rh-python27'
else: dist_name = 'unknown'
if 'USER' in os.environ:
  medpy_release_path = '/nas1/UsersData/'+os.environ['USER'].replace('-internal','')+'/MR/Libs/Internal/MedPyExport/generate_binding/Release/'+dist_name
  if os.path.isdir(medpy_release_path): sys.path.insert(0, medpy_release_path)
EOM

echo "${INFOP}Installing pip"
GETPIP=${DLDIR}/get-pip.py
if [ ! -f "${GETPIP}" ] ; then
wget https://bootstrap.pypa.io/get-pip.py -O ${GETPIP} 2>${LGDIR}/${SNAM}-get-pip-err.log 1>${LGDIR}/${SNAM}-get-pip-out.log
fi
bash -c ". ${ENABLE_FILE} && python ${GETPIP}" 2>${LGDIR}/${SNAM}-get-pip-err.log 1>${LGDIR}/${SNAM}-get-pip-out.log

PIP_INSTALL_F="${DLDIR}/PIP_INSTALL_${PYNAM}"
PIP_INSTALL_REQFILE="${CFDIR}/py3env-requirements.txt"
PIP_REPODIR="${DLDIR}/${PYNAM}-repo"
mkdir -p $PIP_REPODIR
if [ ! -f "${PIP_INSTALL_F}" ] ; then
echo "${INFOP}Downloading package from ${PIP_INSTALL_REQFILE}"
rm -f ${LGDIR}/pip_${PYNAM}_err.txt ${LGDIR}/pip_${PYNAM}_out.txt
bash -c ". ${ENABLE_FILE} && pip install numpy"
for i in `cat ${PIP_INSTALL_REQFILE}`; do bash -c ". ${ENABLE_FILE} && pip download -d $PIP_REPODIR $i" ; done 2>> ${LGDIR}/pip_${PYNAM}_err.txt 1>>${LGDIR}/pip_${PYNAM}_out.txt
#bash -c ". ${ENABLE_FILE} && pip download -d $PIP_REPODIR -r $PIP_INSTALL_REQFILE" 2>> ${LGDIR}/pip_${PYNAM}_err.txt 1>>${LGDIR}/pip_${PYNAM}_out.txt
touch ${PIP_INSTALL_F}
#cat ${LGDIR}/pip_${PYNAM}_out.txt  | egrep -v '^(  Runnung|  Downloading|Collecting|Successfully|Requirement|  Stored|Building|Installing|  Running)'
else
echo "${INFOP}Skipping package install for ${PYNAM}"
fi

PIP_SITEINSTALL_F="${DLDIR}/PIP_SITEINSTALL_${PYNAM}"
if [ ! -f "${PIP_SITEINSTALL_F}" ] ; then
echo "${INFOP}Installing package from ${PIP_INSTALL_REQFILE}"
rm -f ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
bash -c ". ${ENABLE_FILE} && pip install --no-index --find-links=file://${PIP_REPODIR} numpy" 2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>>${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
bash -c ". ${ENABLE_FILE} && pip install --no-index --find-links=file://${PIP_REPODIR} -r $PIP_INSTALL_REQFILE" 2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>>${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
touch ${PIP_SITEINSTALL_F}
#### ORIG #### PYCURL_SSL_LIBRARY=openssl LDFLAGS=-L/usr/lib64/openssl CPPFLAGS=-I/usr/include/openssl/ bash -c ". /opt/medial/${PYNAM}/enable && pip install pycurl --compile --no-cache-dir"
PYCURL_SSL_LIBRARY=openssl LDFLAGS=-L/opt/medial/dist/usr/lib CPPFLAGS=-I/opt/medial/dist/usr/include/openssl/ bash -c ". /opt/medial/${PYNAM}/enable && pip install pycurl --compile --no-cache-dir" \
2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>> ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
#cat ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt  | egrep -v '^(  Runnung|  Downloading|Collecting|Successfully|Requirement|  Stored|Building|Installing|  Running)'
else
echo "${INFOP}Skipping package siteinstall for ${PYNAM}"
fi

#setup for system-wide jupyter configuration
mkdir -p ${MEDIAL_PYTHON_PREFIX}/etc/jupyter/
mkdir -p ${MEDIAL_PYTHON_PREFIX}/share/jupyter/kernels/
cp ${CFDIR}/jupyter_notebook_config.py ${MEDIAL_PYTHON_PREFIX}/etc/jupyter/
cp ${CFDIR}/jupyterhub_config.py ${MEDIAL_PYTHON_PREFIX}/etc/jupyter/
cp ${CFDIR}/jupyter_init_d_script ${MEDIAL_PYTHON_PREFIX}/bin/
cp ${CFDIR}/jupyterhub_init_d_script ${MEDIAL_PYTHON_PREFIX}/bin/
cp ${CFDIR}/jupyter_init_d_script /etc/init.d/jupyter
cp ${CFDIR}/jupyterhub_init_d_script /etc/init.d/jupyterhub
#system-wide add python2 kernel to jupyter
cp -r ${CFDIR}/kernels/python2 ${MEDIAL_PYTHON_PREFIX}/share/jupyter/kernels/

if [ ! -f $MEDIAL_PYTHON_PREFIX/bin/gdbgui ] ; then
echo "${INFOP}Creating virtualenv for gdbgui"
bash -c ". $ENABLE_FILE && cd $MEDIAL_PYTHON_PREFIX/bin && virtualenv gdbgui-venv" 2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>> ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
bash -c ". $MEDIAL_PYTHON_PREFIX/bin/gdbgui-venv/bin/activate && pip install gdbgui --upgrade" 2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>> ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
echo '#!/usr/bin/bash' > $MEDIAL_PYTHON_PREFIX/bin/gdbgui
echo 'source /opt/medial/python36/usr/bin/gdbgui-venv/bin/activate' > $MEDIAL_PYTHON_PREFIX/bin/gdbgui
echo 'exec /opt/medial/python36/usr/bin/gdbgui-venv/bin/gdbgui $@' > $MEDIAL_PYTHON_PREFIX/bin/gdbgui
chmod +x $MEDIAL_PYTHON_PREFIX/bin/gdbgui
fi

#world writable for ipython/jpyter sqlite files
mkdir -p /var${MEDIAL_BASE}/jupyter
chmod a+rw /var${MEDIAL_BASE}/jupyter

SSK_FILE=$MEDIAL_PYTHON_PREFIX/bin/start-spyder-kernel
echo "#!/bin/bash" > $SSK_FILE
echo "source $ENABLE_FILE && python -m spyder_kernels.console --HistoryManager.hist_file=:memory: --ip=\`hostname -i\` -f /nas1/Work/Shared/nbconnection-files/\`hostname\`/\${USER}-\`date +%Y%m%d%H%M%S\`-spyder-kernel.json" >> $SSK_FILE
chmod a+x $SSK_FILE

#install nltk data
NLTK_DATA_F="${DLDIR}/DL_nltk_data"
if [ ! -f $NLTK_DATA_F ]; then
bash -c "source $ENABLE_FILE && python $CFDIR/dl_nltk_data.py"
touch $NLTK_DATA_F
fi

#install bokeh data
BOKEH_DATA_F="${DLDIR}/DL_bokeh_data"
if [ ! -f $BOKEH_DATA_F ]; then
bash -c "source $ENABLE_FILE && python $CFDIR/dl_bokeh_sample_data.py"
mv -f ~/.bokeh/data ${MEDIAL_PYTHON_PREFIX}/share/bokeh_sample_data
touch $BOKEH_DATA_F
fi

TORCH_F="${DLDIR}/DL_torch"
if [ ! -f $TORCH_F ]; then
bash -c "source $ENABLE_FILE && pip install torch==1.3.1+cpu torchvision==0.4.2+cpu -f https://download.pytorch.org/whl/torch_stable.html" 2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>> ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
touch $DL_torch
fi

echo "[FreeTDS]" >> /etc/odbcinst.ini
echo "Description=FreeTDS Driver for Linux & MSSQL" >> /etc/odbcinst.ini
echo "Driver=/usr/lib64/libtdsodbc.so" >> /etc/odbcinst.ini
echo "Setup=/usr/lib64/libtdsodbc.so" >> /etc/odbcinst.ini
echo "fileusage=1" >> /etc/odbcinst.ini
echo "dontdlclose=1" >> /etc/odbcinst.ini
echo "UsageCount=1" >> /etc/odbcinst.ini
}

################################################################## python 2


function install_python2 {

PYVER="2.7.17"
PYNAM="python27"
PYFILE="Python-${PYVER}.tgz"
PYLINK="https://www.python.org/ftp/python/${PYVER}/${PYFILE}"
INFOP="(II) INFO ${PYNAM}: "

SVER=${PYVER}
SNAM=${PYNAM}
SFILE=${PYFILE}
SLINK=${PYLINK}

if [ ! -f "$DLDIR/${PYFILE}" ]; then
echo "${INFOP}Getting file from: '${PYLINK}'"
wget ${PYLINK} -O ${DLDIR}/${PYFILE}
else
echo "${INFOP}Found file: '${DLDIR}/${PYFILE}'"
fi
cd $BLDIR
tar zxf "${DLDIR}/${PYFILE}"

MEDIAL_PYTHON_ROOT=$MEDIAL_BASE/${PYNAM}
MEDIAL_PYTHON_PREFIX=${MEDIAL_PYTHON_ROOT}/usr

mkdir -p $MEDIAL_PYTHON_ROOT
mkdir -p /etc$MEDIAL_PYTHON_ROOT
mkdir -p /var$MEDIAL_PYTHON_ROOT/lib

ENABLE_FILE=$MEDIAL_PYTHON_ROOT/enable
echo "${INFOP}Creating: '${ENABLE_FILE}'"
echo "export PATH=$MEDIAL_PYTHON_PREFIX/bin\${PATH:+:\${PATH}}" > $ENABLE_FILE
echo "export LD_LIBRARY_PATH=$MEDIAL_PYTHON_PREFIX/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" >> $ENABLE_FILE
echo "export MANPATH=$MEDIAL_PYTHON_PREFIX/share/man:\$MANPATH" >> $ENABLE_FILE
echo "export PKG_CONFIG_PATH=$MEDIAL_PYTHON_PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}" >> $ENABLE_FILE
echo "export XDG_DATA_DIRS=\"$MEDIAL_PYTHON_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"" >> $ENABLE_FILE
echo "export PYTHON_LIBRARY=$MEDIAL_PYTHON_PREFIX/lib/libpython2.7.so" >> $ENABLE_FILE
echo "export PYTHON_INCLUDE_DIR=$MEDIAL_PYTHON_PREFIX/include/python2.7" >> $ENABLE_FILE
echo "export BOKEH_RESOURCES=inline" >> $ENABLE_FILE
#echo "export PYTHONHOME=$MEDIAL_PYTHON_PREFIX" >> $ENABLE_FILE

echo "${INFOP}Compiling ${BLDIR}/Python-${PYVER}"

MAKECOMPLETE="${DLDIR}/MAKE_${PYNAM}"

if [ ! -f "${MAKECOMPLETE}" ] ; then

cd "${BLDIR}/Python-${PYVER}"

CC="gcc" \
CFLAGS="-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches   -m64 -mtune=generic -D_GNU_SOURCE -fPIC -fwrapv" \
LDFLAGS="-Wl,-z,relro" \
CPPFLAGS="" \
CXX="g++" \
PKG_CONFIG_PATH="$MEDIAL_PYTHON_PREFIX/lib/pkgconfig::$MEDIAL_PYTHON_PREFIX/lib/pkgconfig:$MEDIAL_PYTHON_PREFIX/share/pkgconfig" \
./configure --prefix=$MEDIAL_PYTHON_PREFIX \
--exec-prefix=$MEDIAL_PYTHON_PREFIX \
--build=x86_64-redhat-linux-gnu \
--host=x86_64-redhat-linux-gnu \
--program-prefix= \
--bindir=$MEDIAL_PYTHON_PREFIX/bin \
--sbindir=$MEDIAL_PYTHON_PREFIX/sbin \
--sysconfdir=/etc/$MEDIAL_PYTHON_ROOT \
--datadir=$MEDIAL_PYTHON_PREFIX/share \
--includedir=$MEDIAL_PYTHON_PREFIX/include \
--libdir=$MEDIAL_PYTHON_PREFIX/lib \
--libexecdir=$MEDIAL_PYTHON_PREFIX/libexec \
--localstatedir=/var/$MEDIAL_PYTHON_ROOT \
--sharedstatedir=/var/$MEDIAL_PYTHON_ROOT/lib \
--mandir=$MEDIAL_PYTHON_PREFIX/share/man \
--infodir=$MEDIAL_PYTHON_PREFIX/share/info \
--enable-ipv6 \
--enable-shared \
--enable-unicode=ucs4 \
--with-dbmliborder=gdbm:ndbm:bdb \
--with-system-expat \
--with-system-ffi \
--with-valgrind \
build_alias=x86_64-redhat-linux-gnu \
host_alias=x86_64-redhat-linux-gnu \
 2>${LGDIR}/${SNAM}-conf-err.log 1>${LGDIR}/${SNAM}-conf-out.log

#--enable-optimizations \

make 2>${LGDIR}/${SNAM}-make-err.log 1>${LGDIR}/${SNAM}-make-out.log && \
make altinstall 2>${LGDIR}/${SNAM}-inst-err.log 1>${LGDIR}/${SNAM}-inst-out.log && \
touch ${MAKECOMPLETE}

cd ..
fi

echo "${INFOP}Creating symlinks"
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python2.7 $MEDIAL_PYTHON_PREFIX/bin/python2
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python2 $MEDIAL_PYTHON_PREFIX/bin/python
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python2.7-config $MEDIAL_PYTHON_PREFIX/bin/python2-config
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python2-config $MEDIAL_PYTHON_PREFIX/bin/python-config
ln -f -s $MEDIAL_PYTHON_PREFIX/lib $MEDIAL_PYTHON_PREFIX/lib64

KERNEL_START_FILE="${MEDIAL_PYTHON_PREFIX}/bin/start-python2-kernel.sh"
echo "#!/usr/bin/env bash" > $KERNEL_START_FILE
echo "source ${ENABLE_FILE}" >> $KERNEL_START_FILE
echo "exec ${MEDIAL_PYTHON_PREFIX}/bin/python -m ipykernel_launcher \$@" >> $KERNEL_START_FILE
chmod a+x $KERNEL_START_FILE

echo "import sys; sys.path.append('/opt/medial/python27/usr/lib/python2.7'); sys.path.append('/opt/medial/python27/usr/lib/python2.7/lib-dynload');" > $MEDIAL_PYTHON_PREFIX/lib/python2.7/site-packages/sitecustomize.py

cat >>$MEDIAL_PYTHON_PREFIX/lib/python2.7/site-packages/sitecustomize.py <<- EOM
import sysconfig as sc
import os
pfx = sc._CONFIG_VARS['prefix']
if 'anaconda2' in pfx: dist_name = 'anaconda-python27'
elif '/opt/medial/python27' in pfx: dist_name = 'medial-python27'
elif '/opt/medial/dist' in pfx: dist_name = 'medial-python36'
elif '/usr' == pfx: dist_name = 'rh-python27'
else: dist_name = 'unknown'
if 'USER' in os.environ:
  medpy_release_path = '/nas1/UsersData/'+os.environ['USER']+'/MR/Libs/Internal/MedPyExport/generate_binding/Release/'+dist_name
  if os.path.isdir(medpy_release_path): sys.path.insert(0, medpy_release_path)
EOM

echo "${INFOP}Installing pip"
GETPIP=${DLDIR}/get-pip.py
if [ ! -f "${GETPIP}" ] ; then
wget https://bootstrap.pypa.io/get-pip.py -O ${GETPIP} 2>${LGDIR}/${SNAM}-get-pip-err.log 1>${LGDIR}/${SNAM}-get-pip-out.log
fi
bash -c ". ${ENABLE_FILE} && python ${GETPIP}" 2>${LGDIR}/${SNAM}-get-pip-err.log 1>${LGDIR}/${SNAM}-get-pip-out.log

PIP_INSTALL_F="${DLDIR}/PIP_INSTALL_${PYNAM}"
PIP_INSTALL_REQFILE="${CFDIR}/py2env-requirements.txt"
PIP_REPODIR="${DLDIR}/${PYNAM}-repo"
mkdir -p $PIP_REPODIR
if [ ! -f "${PIP_INSTALL_F}" ] ; then
echo "${INFOP}Downloading package from ${PIP_INSTALL_REQFILE}"
rm -f ${LGDIR}/pip_${PYNAM}_err.txt ${LGDIR}/pip_${PYNAM}_out.txt
bash -c ". ${ENABLE_FILE} && pip install numpy"
for i in `cat ${PIP_INSTALL_REQFILE}`; do bash -c ". ${ENABLE_FILE} && pip download -d $PIP_REPODIR $i" ; done 2>> ${LGDIR}/pip_${PYNAM}_err.txt 1>> ${LGDIR}/pip_${PYNAM}_out.txt
#bash -c ". ${ENABLE_FILE} && pip download -d $PIP_REPODIR -r $PIP_INSTALL_REQFILE" 2>> ${LGDIR}/pip_${PYNAM}_err.txt 1>> ${LGDIR}/pip_${PYNAM}_out.txt
touch ${PIP_INSTALL_F}
#cat ${LGDIR}/pip_${PYNAM}_out.txt  | egrep -v '^(  Runnung|  Downloading|Collecting|Successfully|Requirement|  Stored|Building|Installing|  Running)'
else
echo "${INFOP}Skipping package install for ${PYNAM}"
fi

PIP_SITEINSTALL_F="${DLDIR}/PIP_SITEINSTALL_${PYNAM}"
if [ ! -f "${PIP_SITEINSTALL_F}" ] ; then
echo "${INFOP}Installing package from ${PIP_INSTALL_REQFILE}"
rm -f ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
bash -c ". ${ENABLE_FILE} && pip install --no-index --find-links=file://${PIP_REPODIR} numpy" 2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>> ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
bash -c ". ${ENABLE_FILE} && pip install --no-index --find-links=file://${PIP_REPODIR} -r $PIP_INSTALL_REQFILE" 2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>> ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
touch ${PIP_SITEINSTALL_F}
### ORIG ### PYCURL_SSL_LIBRARY=openssl LDFLAGS=-L/usr/lib64/openssl CPPFLAGS=-I/usr/include/openssl/ bash -c ". /opt/medial/${PYNAM}/enable && pip install pycurl --compile --no-cache-dir"
PYCURL_SSL_LIBRARY=openssl LDFLAGS=-L/opt/medial/dist/usr/lib CPPFLAGS=-I/opt/medial/dist/usr/include/openssl bash -c ". /opt/medial/${PYNAM}/enable && pip install pycurl --compile --no-cache-dir" \
2>> ${LGDIR}/pip_siteinstall_${PYNAM}_err.txt 1>> ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt
#cat ${LGDIR}/pip_siteinstall_${PYNAM}_out.txt  | egrep -v '^(  Runnung|  Downloading|Collecting|Successfully|Requirement|  Stored|Building|Installing|  Running)'
else
echo "${INFOP}Skipping package siteinstall for ${PYNAM}"
fi
}



################################################################## nodejs


function install_nodejs {

NJVER="8.12.0"
#NJVER="12.13.0"
NJNAM="nodejs"
NJFILE="node-v${NJVER}.tar.gz"
NJLINK="https://nodejs.org/dist/v${NJVER}/${NJFILE}"
INFOP="(II) INFO ${NJNAM}: "

SVER=${NJVER}
SNAM=${NJNAM}
SFILE=${NJFILE}
SLINK=${NJLINK}

if [ ! -f "$DLDIR/${NJFILE}" ]; then
echo "${INFOP}Getting file from: '${NJLINK}'"
wget ${NJLINK} -O ${DLDIR}/${NJFILE}
else
echo "${INFOP}Found file: '${DLDIR}/${NJFILE}'"
fi
cd $BLDIR
tar zxf "${DLDIR}/${NJFILE}" 2>>/dev/null 1>>/dev/null

MEDIAL_NODEJS_ROOT=$MEDIAL_BASE/dist
MEDIAL_NODEJS_PREFIX=$MEDIAL_BASE/dist/usr

mkdir -p $MEDIAL_NODEJS_ROOT
mkdir -p /etc$MEDIAL_NODEJS_ROOT
mkdir -p /var$MEDIAL_NODEJS_ROOT/lib

ln -f -s ${MEDIAL_NODEJS_ROOT} $MEDIAL_BASE/${NJNAM}

ENABLE_FILE=$MEDIAL_NODEJS_ROOT/enable
if [ ! -f ${ENABLE_FILE} ]; then
echo "${INFOP}Creating: '${ENABLE_FILE}'"
echo "export PATH=$MEDIAL_NODEJS_PREFIX/bin\${PATH:+:\${PATH}}" > $ENABLE_FILE
echo "export LD_LIBRARY_PATH=$MEDIAL_NODEJS_PREFIX/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" >> $ENABLE_FILE
echo "export MANPATH=$MEDIAL_NODEJS_PREFIX/share/man:\$MANPATH" >> $ENABLE_FILE
echo "export PKG_CONFIG_PATH=$MEDIAL_NODEJS_PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}" >> $ENABLE_FILE
echo "export XDG_DATA_DIRS=\"$MEDIAL_NODEJS_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"" >> $ENABLE_FILE
fi

echo "${INFOP}Compiling ${BLDIR}/node-v${NJVER}"

MAKECOMPLETE="${DLDIR}/MAKE_${NJNAM}"

if [ ! -f "${MAKECOMPLETE}" ] ; then

cd "${BLDIR}/node-v${NJVER}"

wget https://sourceforge.net/projects/icu/files/ICU4C/60.1/icu4c-60_1-src.zip/download -O ${DLDIR}/icu4c-60_1-src.zip

./configure \
--with-icu-source=${DLDIR}/icu4c-60_1-src.zip \
--prefix=$MEDIAL_NODEJS_PREFIX \
--with-intl=full-icu \
--download=all \
 2>${LGDIR}/${SNAM}-conf-err.log 1>${LGDIR}/${SNAM}-conf-out.log


# it downloads : https://ssl.icu-project.org/files/icu4c/60.1/icu4c-60_1-src.zip

make -j4 2>${LGDIR}/${SNAM}-make-err.log 1>${LGDIR}/${SNAM}-make-out.log  && \
make install 2>${LGDIR}/${SNAM}-inst-err.log 1>${LGDIR}/${SNAM}-inst-out.log && \
touch ${MAKECOMPLETE}

cd ..
fi

bash -c ". ${ENABLE_FILE} && npm install -g configurable-http-proxy" 2>${LGDIR}/${SNAM}-pkgs-err.log 1>${LGDIR}/${SNAM}-pkgs-out.log

}

################################################################## R

function install_R {


RVER="3.5.1"
RNAM="R"
RFILE="R-${RVER}.tar.gz"
RLINK="https://cloud.r-project.org/src/base/R-3/${RFILE}"
INFOP="(II) INFO ${RNAM}: "

SVER=${RVER}
SNAM=${RNAM}
SFILE=${RFILE}
SLINK=${RLINK}

if [ ! -f "$DLDIR/${RFILE}" ]; then
echo "${INFOP}Getting file from: '${RLINK}'"
wget ${RLINK} -O ${DLDIR}/${RFILE}
else
echo "${INFOP}Found file: '${DLDIR}/${RFILE}'"
fi
cd $BLDIR
tar zxf "${DLDIR}/${RFILE}"

MEDIAL_R_ROOT=$MEDIAL_BASE/dist
MEDIAL_R_PREFIX=$MEDIAL_BASE/dist/usr

mkdir -p $MEDIAL_R_ROOT
mkdir -p /etc$MEDIAL_R_ROOT
mkdir -p /var$MEDIAL_R_ROOT/lib

ln -f -s ${MEDIAL_R_ROOT} $MEDIAL_BASE/${RNAM}

ENABLE_FILE=$MEDIAL_R_ROOT/enable
if [ ! -f ${ENABLE_FILE} ]; then
echo "${INFOP}Creating: '${ENABLE_FILE}'"
echo "export PATH=$MEDIAL_R_PREFIX/bin\${PATH:+:\${PATH}}" > $ENABLE_FILE
echo "export LD_LIBRARY_PATH=$MEDIAL_R_PREFIX/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" >> $ENABLE_FILE
echo "export MANPATH=$MEDIAL_R_PREFIX/share/man:\$MANPATH" >> $ENABLE_FILE
echo "export PKG_CONFIG_PATH=$MEDIAL_R_PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}" >> $ENABLE_FILE
echo "export XDG_DATA_DIRS=\"$MEDIAL_R_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"" >> $ENABLE_FILE
fi

echo "${INFOP}Compiling ${BLDIR}/R-${RVER}"

MAKECOMPLETE="${DLDIR}/MAKE_${RNAM}"

if [ ! -f "${MAKECOMPLETE}" ] ; then

cd "${BLDIR}/R-${RVER}"

./configure \
--prefix=$MEDIAL_R_PREFIX \
--enable-R-shlib \
--with-blas \
--with-x=no \
--disable-java \
--with-lapack \
 2>${LGDIR}/${SNAM}-conf-err.log 1>${LGDIR}/${SNAM}-conf-out.log

make -j4 2>${LGDIR}/${SNAM}-make-err.log 1>${LGDIR}/${SNAM}-make-out.log && \
make install 2>${LGDIR}/${SNAM}-inst-err.log 1>${LGDIR}/${SNAM}-inst-out.log && \
touch ${MAKECOMPLETE}

echo "${INFOP}Installing R Packages ${BLDIR}/R-${RVER}"
bash -c "source ${ENABLE_FILE} && ${MEDIAL_R_PREFIX}/bin/Rscript ${CFDIR}/rpackages_install.r" 2> ${LGDIR}/r_pkg_inst_err.log 1> ${LGDIR}/r_pkg_inst_out.log

cd ..
fi

#ln -f -s ${MEDIAL_R_PREFIX}/lib64 ${MEDIAL_R_PREFIX}/lib

echo "" >> ${MEDIAL_R_PREFIX}/lib/R/library/base/R/Rprofile
echo "## Set default 'type' for png() calls - useful when X11 device is not available!" >> ${MEDIAL_R_PREFIX}/lib/R/library/base/R/Rprofile
echo "### NOTE: Needs 'cairo' capability" >> ${MEDIAL_R_PREFIX}/lib/R/library/base/R/Rprofile
echo "options(bitmapType='cairo')" >> ${MEDIAL_R_PREFIX}/lib/R/library/base/R/Rprofile

}

################################################################## openssl


function install_openssl {

SVER="1.1.1"
SNAM="openssl"
SFILE="${SNAM}-${SVER}.tar.gz"
SLINK="https://www.openssl.org/source/${SFILE}"
INFOP="(II) INFO ${SNAM}: "


if [ ! -f "$DLDIR/${SFILE}" ]; then
echo "${INFOP}Getting file from: '${SLINK}'"
wget ${SLINK} -O ${DLDIR}/${SFILE}
else
echo "${INFOP}Found file: '${DLDIR}/${SFILE}'"
fi
cd $BLDIR
tar zxf "${DLDIR}/${SFILE}"

MEDIAL_DIST_ROOT=$MEDIAL_BASE/dist
MEDIAL_DIST_PREFIX=$MEDIAL_BASE/dist/usr
MEDIAL_OPENSSL_DIR=${MEDIAL_DIST_PREFIX}/share/ssl/pki/tls

mkdir -p $MEDIAL_DIST_ROOT

ENABLE_FILE=$MEDIAL_DIST_ROOT/enable
echo "${INFOP}Creating: '${ENABLE_FILE}'"
echo "export PATH=$MEDIAL_DIST_PREFIX/bin\${PATH:+:\${PATH}}" > $ENABLE_FILE
echo "export LD_LIBRARY_PATH=$MEDIAL_DIST_PREFIX/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" >> $ENABLE_FILE
echo "export MANPATH=$MEDIAL_DIST_PREFIX/share/man:\$MANPATH" >> $ENABLE_FILE
echo "export PKG_CONFIG_PATH=$MEDIAL_DIST_PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}" >> $ENABLE_FILE
echo "export XDG_DATA_DIRS=\"$MEDIAL_DIST_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"" >> $ENABLE_FILE

echo "${INFOP}Compiling ${BLDIR}/${SNAM}-${SVER}"

MAKECOMPLETE="${DLDIR}/MAKE_${SNAM}"

if [ ! -f "${MAKECOMPLETE}" ] ; then

cd "${BLDIR}/${SNAM}-${SVER}"

mkdir -p ${MEDIAL_OPENSSL_DIR}

./config \
--prefix=${MEDIAL_DIST_PREFIX} \
--libdir=${MEDIAL_DIST_PREFIX}/lib \
--openssldir=${MEDIAL_OPENSSL_DIR} \
enable-ec_nistp_64_gcc_128 \
zlib \
enable-camellia \
enable-seed \
enable-rfc3779 \
enable-sctp \
enable-cms \
enable-md2 \
enable-rc5 \
enable-ssl3 \
enable-ssl3-method \
enable-weak-ssl-ciphers \
no-mdc2 no-ec2m no-sm2 no-sm4 \
shared \
-fPIC 2>${LGDIR}/${SNAM}-conf-err.log 1>${LGDIR}/${SNAM}-conf-out.log

# it downloads : https://ssl.icu-project.org/files/icu4c/60.1/icu4c-60_1-src.zip

make -j4 2>${LGDIR}/${SNAM}-make-err.log 1>${LGDIR}/${SNAM}-make-out.log && \
make install 2>${LGDIR}/${SNAM}-inst-err.log 1>${LGDIR}/${SNAM}-inst-out.log && \
mkdir -p ${MEDIAL_OPENSSL_DIR}/certs
wget https://curl.haxx.se/ca/cacert.pem -O ${MEDIAL_OPENSSL_DIR}/certs/ca-bundle.crt
touch ${MAKECOMPLETE}

cd ..
fi

}

################################################################## libcurl


function install_curl {

SVER="7.62.0"
SNAM="curl"
SFILE="${SNAM}-${SVER}.tar.gz"
SLINK="https://curl.haxx.se/download/${SFILE}"
INFOP="(II) INFO ${SNAM}: "


if [ ! -f "$DLDIR/${SFILE}" ]; then
echo "${INFOP}Getting file from: '${SLINK}'"
wget ${SLINK} -O ${DLDIR}/${SFILE}
else
echo "${INFOP}Found file: '${DLDIR}/${SFILE}'"
fi
cd $BLDIR
tar zxf "${DLDIR}/${SFILE}"

MEDIAL_DIST_ROOT=$MEDIAL_BASE/dist
MEDIAL_DIST_PREFIX=$MEDIAL_BASE/dist/usr

mkdir -p $MEDIAL_DIST_ROOT

ENABLE_FILE=$MEDIAL_DIST_ROOT/enable
if [ ! -f ${ENABLE_FILE} ]; then
echo "${INFOP}Creating: '${ENABLE_FILE}'"
echo "export PATH=$MEDIAL_DIST_PREFIX/bin\${PATH:+:\${PATH}}" > $ENABLE_FILE
echo "export LD_LIBRARY_PATH=$MEDIAL_DIST_PREFIX/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" >> $ENABLE_FILE
echo "export MANPATH=$MEDIAL_DIST_PREFIX/share/man:\$MANPATH" >> $ENABLE_FILE
echo "export PKG_CONFIG_PATH=$MEDIAL_DIST_PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}" >> $ENABLE_FILE
echo "export XDG_DATA_DIRS=\"$MEDIAL_DIST_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"" >> $ENABLE_FILE
fi

echo "${INFOP}Compiling ${BLDIR}/${SNAM}-${SVER}"

MAKECOMPLETE="${DLDIR}/MAKE_${SNAM}"

if [ ! -f "${MAKECOMPLETE}" ] ; then

cd "${BLDIR}/${SNAM}-${SVER}"

bash -c "source $ENABLE_FILE && ./configure --prefix=${MEDIAL_DIST_PREFIX} --with-ssl" 2>${LGDIR}/${SNAM}-conf-err.log 1>${LGDIR}/${SNAM}-conf-out.log

make -j4 2>${LGDIR}/${SNAM}-make-err.log 1>${LGDIR}/${SNAM}-make-out.log && \
make install 2>${LGDIR}/${SNAM}-inst-err.log 1>${LGDIR}/${SNAM}-inst-out.log && \
touch ${MAKECOMPLETE}

cd ..
fi

}

################################################################## gen_pack

function gen_pack {
MEDIAL_DIST_VER=0.0.18
DIST_FILE=medial-ds-dist-${MEDIAL_DIST_VER}.tar.bz2
DIST_SRC_FILE=medial-ds-src-${MEDIAL_DIST_VER}.tar.gz

if $DODRL ; then
if [ ! -f ${DIST_RELEASE_PATH}/${DIST_FILE} ]; then
cd /
tar jcf ${DIST_RELEASE_PATH}/${DIST_FILE} /etc/init.d/jupyter* /etc/opt/medial /var/opt/medial/ /opt/medial
fi
fi

if $DORL ; then
if [ ! -f ${RELEASE_PATH}/${DIST_SRC_FILE} ]; then
cd ${SCRIPTPATH}/../
tar zcf ${RELEASE_PATH}/${DIST_SRC_FILE} medial-envgen/install.sh medial-envgen/conf/ medial-envgen/TODO
fi
fi

}
################################################################## Main

OPTIONS=d:b:l:c:hosr:p:x
LONGOPTS=download-path,build-path,log-path,config-path,help,download-only,skip-download,release-path,dist-pack-path,release-only

PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
GETOPT_EXIT_CODE=$?
if [[ ${GETOPT_EXIT_CODE} -ne 0 ]]; then
    echo "Bad options given"
    exit 2
fi
eval set -- "$PARSED"

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -d|--download-path)
            DLDIR="$2"
            shift 2
            ;;
        -b|--build-path)
            BLDIR="$2"
            shift 2
            ;;
        -l|--log-path)
            LGDIR="$2"
            shift 2
            ;;
        -c|--config-path)
            CFDIR="$2"
            shift 2
            ;;
        -h|--help)
OPTIONS=d:b:l:c:hosr:p:x
LONGOPTS=download-path,build-path,log-path,config-path,help,download-only,skip-download,release-path,dist-pack-path,release-only
            echo "script options:"
            echo "  -d [PATH],--download-path=[PATH] Specify download path"
            echo "  -b [PATH],--build-path=[PATH] Specify build path"
            echo "  -l [PATH],--log-path=[PATH] Specify log path"
            echo "  -c [PATH],--config-path=[PATH] Specify config path"
            echo "  -h,--help This message"
            echo "  -o,--download-only Only download sources"
            echo "  -s,--skip-download Only build and install"
            echo "  -r [PATH],--release-path=[PATH] Specify script release path"
            echo "  -p [PATH],--dist-pack-path=[PATH] Specify distribution package release path"
            echo "  -x,--release-only Only do release (mus specify -r or -p or both)"
            exit 0
            ;;
        -o|--download-only)
            DODL=true
            DOBL=false
            shift
            ;;
        -s|--skip-download)
            DODL=false
            DOBL=true
            shift
            ;;
        -r|--release-path)
            RELEASE_PATH="$2"
            DORL=true
            echo "${INFOP}Using release path: ${RELEASE_PATH}"
            shift 2
            ;;
        -p|--dist-pack-path)
            DIST_RELEASE_PATH="$2"
            DODRL=true
            echo "${INFOP}Using dist package path: ${DIST_RELEASE_PATH}"
            shift 2
            ;;
        -x|--release-only)
            DORLONLY=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

echo "${INFOP}Using download path: ${DLDIR}"
echo "${INFOP}Using build path: ${BLDIR}"
echo "${INFOP}Using log path: ${LGDIR}"
echo "${INFOP}Using config path: ${CFDIR}"

mkdir -p $DLDIR
mkdir -p $BLDIR
mkdir -p $LGDIR

if ! $DORLONLY ; then

install_req_centos7
install_openssl
install_curl
install_python2
install_python3
install_nodejs
install_R

fi

gen_pack

exit 0

