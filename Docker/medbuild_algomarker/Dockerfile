FROM ubuntu:latest

RUN apt-get update && apt-get upgrade -y && apt-get install binutils libgomp1 gcc g++ cmake make swig wget bzip2 -y

RUN mkdir -p /earlysign

# Boost compile
RUN echo "(II) INFO: Cloning git " && \
    cd /earlysign && wget https://archives.boost.io/release/1.85.0/source/boost_1_85_0.tar.bz2
RUN echo "(II) INFO: Extracting Boost" && \
    cd /earlysign && tar -xjf boost_1_85_0.tar.bz2 && \
    rm -f boost_1_85_0.tar.bz2
RUN echo "(II) INFO: Compiling Boost" && \
    cd /earlysign/boost_1_85_0 && \
    ./bootstrap.sh && \
    ./b2 --clean && \
    ./b2 cxxflags="-march=x86-64" link=static variant=release linkflags=-static-libstdc++ -j8 cxxflags="-fPIC" --stagedir="/earlysign/Boost" --with-program_options --with-system --with-regex --with-filesystem  && mkdir -p /earlysign/Boost/include && \
    ln -s /earlysign/boost_1_85_0/boost  /earlysign/Boost/include && \
    ./b2 cxxflags="-march=x86-64" link=shared variant=release linkflags=-static-libstdc++ -j8 cxxflags="-fPIC" --stagedir="/earlysign/Boost" --with-program_options --with-system --with-regex --with-filesystem


#RUN echo "(II) INFO: Cloning git " && \
#   cd /earlysign && git clone git@github.com:Medial-EarlySign/medpython.git

# Our code compile: - change Boost path to your local Boost path
#RUN cd /earlysign/MR_Libs/Internal/AlgoMarker && \
#    sed -i 's|#set(BOOST_ROOT.*|set(BOOST_ROOT "/earlysign/Boost")|g' CMakeLists.txt \
#    ./full_build.sh