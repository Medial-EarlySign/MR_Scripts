FROM medbuild_external_resources:latest AS builder1
ARG GIT_USER
ARG GIT_PASS
ARG BUILD_MARCH=x86-64
#ARG BUILD_MARCH=native
ARG GIT_TAG
ENV MR_ROOT=/build/MR \
    CPATH=/build/boost_1_67_0 \
    R_INCL_DIR=/build/R-3.4.0/src/include \
    LIBRARY_PATH=/opt/medial/tools/lib/ \
    LD_LIBRARY_PATH=/opt/medial/tools/lib/ \
    MR_LIBS_NAME="Logger.lib;InfraMed.lib;MedStat.lib;MedUtils.lib;MedAlgo.lib;MedProcessTools.lib;QRF.lib;TQRF.lib;Mars.lib;gbm.lib;micNet.lib;xgboost.lib;rabit.lib;dmlccore.lib;MedTime.lib;lightgbm.lib;libvw.lib;vw_dynamic.lib;MedSparseMat.lib;MedEmbed.lib;MedIO.lib;SerializableObject.lib;MedSplit.lib;MedMat.lib"
COPY Resources /build/Resources
RUN echo "(II) INFO: Compiling Boost" && \
    mkdir -p /build/lib/ && \
    cd /build/boost_1_67_0/ && \
    ./b2 --clean && \
    ./b2 cxxflags="-march=${BUILD_MARCH}" link=static variant=release linkflags=-static-libstdc++ -j8 cxxflags="-fPIC" --stagedir="/build" --with-program_options --with-system --with-regex --with-filesystem && \
    mkdir -p /build/MR && \
    mkdir -p /build/MR/Libs && \
    mkdir -p /build/MR/Projects/Resources && \
    mkdir -p /build/MR/Projects/Scripts && \
    mkdir -p /build/MR/Projects/Shared && \
    mkdir -p /build/MR/Tools && \
    echo "(II) INFO: Cloning git " && \
    cd ${MR_ROOT} && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_libs.git Libs && \
    cd ${MR_ROOT} && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_tools.git Tools && \
    cd ${MR_ROOT}/Projects && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_scripts.git Scripts && \
    cd ${MR_ROOT}/Projects && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_resources.git Resources && \
    echo "(II) Checkout Libs, tag '${GIT_TAG}' ..." && cd ${MR_ROOT}/Libs && git checkout ${GIT_TAG} && \
    echo "(II) Checkout Tool, tag '${GIT_TAG}' ..." && cd ${MR_ROOT}/Tools && git checkout ${GIT_TAG} && \
    echo "(II) Checkout Scripts, tag '${GIT_TAG}' ..." && cd ${MR_ROOT}/Projects/Scripts && git checkout ${GIT_TAG} && \
    echo "(II) INFO: Compiling XGBoost " && \
    mkdir -p /build/MR/Libs/External/xgboost/lib && \
    mkdir -p /build/MR/Libs/External/xgboost/rabit/lib && \
    cd /build/MR/Libs/External/xgboost/ && \
    find ./ -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    find . -name '*.a' -exec rm {} \; && \
    cd /build/MR/Libs/External/xgboost/rabit && make clean && make -j20 && \
    cd /build/MR/Libs/External/xgboost && make clean && make -j20 && \
    cp ./lib/libxgboost.a /build/lib/ && \
    cp ./rabit/lib/librabit.a /build/lib/ && \
    cp ./dmlc-core/libdmlc.a /build/lib/ && \
    mkdir -p /opt/medial/tools/lib/python && \
    mkdir -p /opt/medial/tools/bin && \
    mkdir -p /server/Work/SharedLibs/linux/lib64/Release/ && \
    echo "(II) INFO: Compiling LightGBM" && \
    mkdir -p /build/MR/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/build && \
    cd /build/MR/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/build && \
    command cp -f ../CMakeLists.fixed.txt ../CMakeLists.txt && \
    sed -i -e "s/ SHARED / STATIC /g" ../CMakeLists.txt && \
    cmake .. && \
    cd /build/MR/Libs/External/LightGBM && \
    find ./ -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    cd /build/MR/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/build && \
    make -j20 && \
    command cp -f $MR_ROOT/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/lib_lightgbm.a /build/lib && \
    echo "(II) INFO: Compiling AlgoMarker" && \
    cd $MR_ROOT/Projects/Resources/CMakeUtils && \
    find ./ -type f -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    perl ${MR_ROOT}/Projects/Scripts/Perl-scripts/create_cmake_files.pl --des=AlgoMarker && \
    command cp -f /build/Resources/AlgoMarker/CMakeLists.Toplevel.txt $MR_ROOT/Libs/Internal/AlgoMarker/CMakeLists.txt && \
    command cp -f /build/Resources/AlgoMarker/CMakeLists.AM.txt $MR_ROOT/Libs/Internal/AlgoMarker/AlgoMarker/CMakeLists.txt && \
    command cp -f /build/Resources/AlgoMarker/CMakeLists.AMApiTester.txt $MR_ROOT/Libs/Internal/AlgoMarker/AMApiTester/CMakeLists.txt && \
    find ${MR_ROOT}/Libs/Internal/AlgoMarker -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    mkdir -p ${MR_ROOT}/Libs/Internal/AlgoMarker/CMakeBuild/Linux/Release && \
    cd ${MR_ROOT}/Libs/Internal/AlgoMarker/CMakeBuild/Linux/Release && \
    cmake ${MR_ROOT}/Libs/Internal/AlgoMarker/ && \
    make -j8 && \
    mkdir -p /Release/ && \
    cp ${MR_ROOT}/Libs/Internal/AlgoMarker/CMakeBuild/Linux/Release/AlgoMarker/libdyn_AlgoMarker.so /Release/libdyn_AlgoMarker.2.so && \
    cp ${MR_ROOT}/Libs/Internal/AlgoMarker/Linux/Release/AMApiTester /Release/AMApiTester.2 && \
    nm -CD /Release/libdyn_AlgoMarker.2.so | grep " T " > /Release/AlgoMarker.2.public_symbols && \
    ldd /Release/libdyn_AlgoMarker.2.so > /Release/AlgoMarker.2.ldd && \
    echo "(II) SUCCESS: AlgoMarker Shared Object file written to /Release/libdyn_AlgoMarker.2.so"
     

