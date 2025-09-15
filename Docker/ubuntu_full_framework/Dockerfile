FROM ubuntu:latest
RUN apt-get update && apt-get install binutils perl htop ncdu net-tools vim bzip2 libgomp1 gcc g++ zip p7zip-full openssh-server gawk dos2unix cgdb sed file systemtap-sdt-dev make less libffi-dev swig cmake lsof libssl-dev zlib1g-dev locate libbz2-dev libsqlite3-dev nano screen ccrypt freetds-dev freetds-bin unixodbc-dev tdsodbc docker.io curl lzma python3-pip iputils-ping unzip -y
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && curl -s https://packages.microsoft.com/config/ubuntu/`lsb_release -a | grep Release | awk '{print $2}'`/prod.list | tee /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install -y msodbcsql* mssql-tools*

RUN mkdir -p /earlysign && mkdir -p /build
COPY mes_full.tar /earlysign
 
COPY requirements.txt install_python.sh install_mes_env.sh /build
RUN cd /build && /build/install_python.sh
RUN /build/install_mes_env.sh


