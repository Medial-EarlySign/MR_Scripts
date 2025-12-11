# We will use old ubuntu to have compitability with newer also. The output is only backwar compitible
#FROM ubuntu:22.04
FROM quay.io/pypa/manylinux2014_aarch64

# RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install binutils gcc g++ cmake make libgomp1 python3-dev swig bzip2 wget patchelf git sed gawk -y
RUN yum install wget bzip2 patchelf git sed gawk python3-devel -y

WORKDIR /earlysign

COPY Resources/ .

RUN /earlysign/Boost/setup_boost.sh