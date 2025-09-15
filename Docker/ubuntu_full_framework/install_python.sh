#!/bin/bash

PYVER="3.12.8"
PYNAM="python312"
PYFILE="Python-${PYVER}.tgz"
PYLINK="https://www.python.org/ftp/python/${PYVER}/${PYFILE}"
INFOP="(II) INFO ${PYNAM}: "
MEDIAL_BASE=/earlysign
DLDIR="$(realpath ${0%/*}/downloads)"
BLDIR="$(realpath ${0%/*})"
LGDIR="$(realpath ${0%/*}/log)"
CFDIR="$(realpath ${0%/*})"
PYVER_M=$(echo $PYVER | awk -F"." '{print $1 "." $2}')

mkdir -p ${LGDIR}
mkdir -p ${DLDIR}
mkdir -p ${BLDIR}

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

MEDIAL_PYTHON_ROOT=${MEDIAL_BASE}/python
MEDIAL_PYTHON_PREFIX=${MEDIAL_PYTHON_ROOT}/usr

mkdir -p $MEDIAL_PYTHON_ROOT
mkdir -p /etc$MEDIAL_PYTHON_ROOT
mkdir -p /var$MEDIAL_PYTHON_ROOT/lib

ln -f -s ${MEDIAL_PYTHON_ROOT} ${MEDIAL_BASE}/${PYNAM}

ENABLE_FILE=$MEDIAL_PYTHON_ROOT/enable
echo "${INFOP}Creating: '${ENABLE_FILE}'"
echo "export PATH=$MEDIAL_PYTHON_PREFIX/bin\${PATH:+:\${PATH}}" > $ENABLE_FILE
echo "export LD_LIBRARY_PATH=$MEDIAL_PYTHON_PREFIX/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" >> $ENABLE_FILE
echo "export MANPATH=$MEDIAL_PYTHON_PREFIX/share/man:\$MANPATH" >> $ENABLE_FILE
echo "export PKG_CONFIG_PATH=$MEDIAL_PYTHON_PREFIX/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}" >> $ENABLE_FILE
echo "export XDG_DATA_DIRS=\"$MEDIAL_PYTHON_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"" >> $ENABLE_FILE
echo "export PYTHON_LIBRARY=$MEDIAL_PYTHON_PREFIX/lib/libpython3.so" >> $ENABLE_FILE

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
--enable-loadable-sqlite-extensions \
 2>&1 | tee ${LGDIR}/${SNAM}-conf.log

#--enable-optimizations \

make 2>&1 | tee ${LGDIR}/${SNAM}-make.log && \
make altinstall 2>&1 | tee ${LGDIR}/${SNAM}-inst.log && \
touch ${MAKECOMPLETE}

cd ..
fi

echo "${INFOP}Creating symlinks"
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/pydoc${PYVER_M} $MEDIAL_PYTHON_PREFIX/bin/pydoc3
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/pydoc3 $MEDIAL_PYTHON_PREFIX/bin/pydoc
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python${PYVER_M} $MEDIAL_PYTHON_PREFIX/bin/python3
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python3 $MEDIAL_PYTHON_PREFIX/bin/python
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python${PYVER_M}m-config $MEDIAL_PYTHON_PREFIX/bin/python${PYVER_M}-config
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python${PYVER_M}-config $MEDIAL_PYTHON_PREFIX/bin/python3-config
ln -f -s $MEDIAL_PYTHON_PREFIX/bin/python3-config $MEDIAL_PYTHON_PREFIX/bin/python-config
ln -f -s $MEDIAL_PYTHON_PREFIX/lib $MEDIAL_PYTHON_PREFIX/lib64

#echo "${INFOP}Installing pip"
#GETPIP=${DLDIR}/get-pip.py
#if [ ! -f "${GETPIP}" ] ; then
#wget https://bootstrap.pypa.io/get-pip.py -O ${GETPIP} 2>&1 | tee ${LGDIR}/${SNAM}-get-pip.log
#fi
#bash -c ". ${ENABLE_FILE} && python ${GETPIP}" 2>&1 | tee -a ${LGDIR}/${SNAM}-get-pip.log 

PIP_INSTALL_F="${DLDIR}/PIP_INSTALL_${PYNAM}"
PIP_INSTALL_REQFILE="${CFDIR}/requirements.txt"
PIP_REPODIR="${DLDIR}/${PYNAM}-repo"
mkdir -p $PIP_REPODIR
if [ ! -f "${PIP_INSTALL_F}" ] ; then
echo "${INFOP}Downloading package from ${PIP_INSTALL_REQFILE}"
bash -c ". ${ENABLE_FILE} && python -m pip install --upgrade pip"
for i in `cat ${PIP_INSTALL_REQFILE}`; do bash -c ". ${ENABLE_FILE} && python -m pip download -d $PIP_REPODIR $i" ; done 2>&1 | tee -a ${LGDIR}/pip_${PYNAM}.txt
#bash -c ". ${ENABLE_FILE} && pip download -d $PIP_REPODIR -r $PIP_INSTALL_REQFILE" 2>> ${LGDIR}/pip_${PYNAM}_err.txt 1>>${LGDIR}/pip_${PYNAM}_out.txt
touch ${PIP_INSTALL_F}
#cat ${LGDIR}/pip_${PYNAM}_out.txt  | egrep -v '^(  Runnung|  Downloading|Collecting|Successfully|Requirement|  Stored|Building|Installing|  Running)'
else
echo "${INFOP}Skipping package install for ${PYNAM}"
fi

PIP_SITEINSTALL_F="${DLDIR}/PIP_SITEINSTALL_${PYNAM}"
if [ ! -f "${PIP_SITEINSTALL_F}" ] ; then
echo "${INFOP}Installing package from ${PIP_INSTALL_REQFILE}"
bash -c ". ${ENABLE_FILE} && python -m pip install --no-index --find-links=file://${PIP_REPODIR} -r $PIP_INSTALL_REQFILE" 2>&1 | tee -a ${LGDIR}/pip_siteinstall_${PYNAM}.txt
touch ${PIP_SITEINSTALL_F}
else
echo "${INFOP}Skipping package siteinstall for ${PYNAM}"
fi

echo "[FreeTDS]" >> /etc/odbcinst.ini
echo "Description=FreeTDS Driver for Linux & MSSQL" >> /etc/odbcinst.ini
echo "Driver=/usr/lib64/libtdsodbc.so" >> /etc/odbcinst.ini
echo "Setup=/usr/lib64/libtdsodbc.so" >> /etc/odbcinst.ini
echo "fileusage=1" >> /etc/odbcinst.ini
echo "dontdlclose=1" >> /etc/odbcinst.ini
echo "UsageCount=1" >> /etc/odbcinst.ini
