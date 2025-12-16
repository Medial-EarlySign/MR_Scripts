# We will use old ubuntu to have compitability with newer also. The output is only backwar compitible
#FROM ubuntu_boost
FROM quay.io/pypa/manylinux2014_aarch64

RUN yum install wget bzip2 git sed gawk python3-devel -y

WORKDIR /earlysign

COPY Resources/ .

RUN /earlysign/medpython/setup.sh