FROM centos:7.6.1810
RUN yum install -y epel-release \
    && yum install -y less vim nano zip unzip tar man curl wget gzip dos2unix \
    file valgrind screen ssh rsync autoconf automake cscope ctags gcc gcc-c++ \
    gettext git indent libtool make patch bzip2 cpp gdb ssh links telnet \
    postgresql-libs sudo icu libicu libicu-devel readline-devel gcc-gfortran \
    bzip2-devel zlib-devel xz-devel pcre-devel libcurl-devel libicu-50 \
    libicu-devel-50 cmake swig tk tk-devel libtk htop ncdu iftop nload lsof \
    krb5-workstation bind-utils unixODBC unixODBC-devel freetds freetds-devel net-tools \
	p7zip libffi-devel python3-devel xz-devel \
    && yum clean all \
    && echo "[FreeTDS]" >> /etc/odbcinst.ini \
    && echo "Description=FreeTDS Driver for Linux & MSSQL" >> /etc/odbcinst.ini \
    && echo "Driver=/usr/lib64/libtdsodbc.so" >> /etc/odbcinst.ini \
    && echo "Setup=/usr/lib64/libtdsodbc.so" >> /etc/odbcinst.ini \
    && echo "fileusage=1" >> /etc/odbcinst.ini \
    && echo "dontdlclose=1" >> /etc/odbcinst.ini \
    && echo "UsageCount=1" >> /etc/odbcinst.ini
