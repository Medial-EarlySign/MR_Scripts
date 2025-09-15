ARG GENERIC_BUILD=1
FROM centos1810dev:latest
RUN yum install -y icu libicu libicu-devel readline-devel gcc-gfortran bzip2-devel zlib-devel xz-devel pcre-devel libcurl-devel && \
    mkdir -p /build/dl && \
    wget https://dl.bintray.com/boostorg/release/1.67.0/source/boost_1_67_0.tar.gz -P /build/dl && \
    wget https://cran.r-project.org/src/base/R-3/R-3.4.0.tar.gz -P /build/dl

WORKDIR /build

RUN export EXTRA_FLAGS="" && \
    if [ "$GENERIC_BUILD" = "1" ] ; then export EXTRA_FLAGS="cxxflags=\"-march=x86-64\"" ; fi && \
    tar zxf /build/dl/boost_*.tar.gz && \
    cd boost* && \
    ./bootstrap.sh && \
    ./b2 $EXTRA_FLAGS variant=release link=shared --with-program_options --with-system --with-regex --with-filesystem && \
    cd /build && \
    tar zxf /build/dl/R-*.tar.gz && \
    cd /build/R-* && \
    mkdir -p /build/rtmp && \
    ./configure --enable-R-shlib --with-blas --with-x=no --disable-java --with-lapack --prefix=/build/rtmp && \
    make -j20 && \
    rm -rf /build/dl/*.tar.gz && \
    mkdir -p /opt/medial/tools/lib && \
    cp /build/boost_1_67_0/stage/lib/* /opt/medial/tools/lib/



#For clang:
#RUN yum install -y centos-release-scl scl-utils && \
#    yum install -y llvm-toolset-7 llvm-toolset-7-libomp llvm-toolset-7-libomp-devel && \
#RUN echo '#!/bin/bash' > /etc/profile.d/enable-clang.sh && \
#    echo "source scl_source enable llvm-toolset-7" >> /etc/profile.d/enable-clang.sh && \
#    chmod +x /etc/profile.d/enable-clang.sh
#ENV CC=/opt/rh/llvm-toolset-7/root/usr/bin/clang \
#    CXX=/opt/rh/llvm-toolset-7/root/usr/bin/clang++ \
#    X_SCLS=llvm-toolset-7 \
#ENV PATH=/opt/rh/llvm-toolset-7/root/usr/bin:/opt/rh/llvm-toolset-7/root/usr/sbin:${PATH} \
#    LD_LIBRARY_PATH=/opt/rh/llvm-toolset-7/root/usr/lib64/:${LD_LIBRARY_PATH} \
#    MANPATH=/opt/rh/llvm-toolset-7/root/usr/share/man:${MANPATH} \
#    PKG_CONFIG_PATH=/opt/rh/llvm-toolset-7/root/usr/lib64/pkgconfig:${PKG_CONFIG_PATH}
#RUN ln -s `which clang` /usr/bin/clang && \
#    ln -s `which clang++` /usr/bin/clang++ && \
# ...
#./bootstrap.sh --with-toolset=clang && \


#multi stage builds example:
#FROM centos1810dev:latest AS boostbuild
#FROM centos1810dev:latest
#RUN mkdir -p /opt/medial/tools/lib/
#COPY --from=boostbuild:latest /build/boost_1_67_0/stage/lib/* /opt/medial/tools/lib/

#    make install && \

