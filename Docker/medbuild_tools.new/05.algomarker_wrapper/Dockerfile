# We will use old ubuntu to have compitability with newer also. The output is only backwar compitible
#FROM ubuntu_boost
FROM quay.io/pypa/manylinux2014_x86_64

WORKDIR /earlysign

COPY Resources/ .

RUN /earlysign/algomarker_wrapper/setup.sh