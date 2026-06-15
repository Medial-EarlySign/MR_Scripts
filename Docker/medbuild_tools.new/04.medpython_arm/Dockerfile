# We will use old ubuntu to have compitability with newer also. The output is only backwar compitible
#FROM ubuntu_boost
FROM quay.io/pypa/manylinux2014_aarch64

ARG PYTHON_VERSION=3.13

RUN yum install python3-devel -y

WORKDIR /earlysign

COPY Resources/ .

RUN /earlysign/medpython/setup.sh ${PYTHON_VERSION}