# We will use old ubuntu to have compitability with newer also. The output is only backwar compitible
#FROM ubuntu_boost
FROM quay.io/pypa/manylinux2014_x86_64

RUN yum install wget bzip2 git -y

WORKDIR /earlysign

COPY Resources/ .

RUN /earlysign/algomarker_wrapper/setup.sh