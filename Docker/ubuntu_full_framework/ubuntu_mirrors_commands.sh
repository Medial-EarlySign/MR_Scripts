apt install -y  gnupg
wget -qO - https://www.aptly.info/pubkey.txt | apt-key add -
apt install -y aptly

gpg --no-default-keyring --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg --export | gpg --no-default-keyring --keyring trustedkeys.gpg --import

aptly mirror create -architectures=amd64 -filter='binutils | perl | htop | ncdu | net-tools | vim | bzip2 | libgomp1 | gcc | zip | p7zip-full | openssh-server | gawk | dos2unix | valgrind | cgdb | sed | file | systemtap-sdt-dev | make | less | libffi-dev | swig | cmake | lsof | libssl-dev | zlib1g-dev | locate | libbz2-dev | libsqlite3-dev | nano | screen | chrony | keyutils | cifs-utils | g++ | python3-pip | mini-httpd | doxygen | docker.io | sssd-ad | sssd-tools | realmd | adcli | postgresql | libpython3-all-dev | freetds-dev | freetds-bin | unixodbc-dev | tdsodbc | ccrypt' -filter-with-deps ubuntu https://mirrors.edge.kernel.org/ubuntu/ jammy main

aptly mirror update ubuntu

gpg --gen-key
DT=$(date +'%Y%m%d')

aptly snapshot create ubuntu-${DT} from mirror ubuntu
aptly publish snapshot ubuntu-${DT}

aptly serve -listen=":7070"