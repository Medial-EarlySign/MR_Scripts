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
    cd ${MR_ROOT}/Libs && git checkout ${GIT_TAG} && \
    cd ${MR_ROOT}/Tools && git checkout ${GIT_TAG} && \
    cd ${MR_ROOT}/Projects/Scripts && git checkout ${GIT_TAG} && \
    echo "(II) INFO: Compiling XGBoost " && \
    mkdir -p /build/MR/Libs/External/xgboost/lib && \
    mkdir -p /build/MR/Libs/External/xgboost/rabit/lib && \
    cd /build/MR/Libs/External/xgboost/ && \
    find ./ -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    find . -name '*.a' -exec rm {} \; && \
    cd /build/MR/Libs/External/xgboost/rabit && make clean && make -j20 && \
    cd /build/MR/Libs/External/xgboost && make clean && make -j20 && \
    cp ./lib/libxgboost.a /build/lib/ && \
    cp ./rabit/lib/librabit_empty.a /build/lib/ && \
    cp ./dmlc-core/libdmlc.a /build/lib/ && \
    mkdir -p /opt/medial/tools/lib/python && \
    mkdir -p /opt/medial/tools/bin && \
    mkdir -p /server/Work/SharedLibs/linux/lib64/Release/ && \
    echo "(II) INFO: Compiling LightGBM" && \
    mkdir -p /build/MR/Libs/External/LightGBM/LightGBM/build && \
    cd /build/MR/Libs/External/LightGBM/LightGBM/build && \
    rm -f ../CMakeLists.txt && \
    cp -f /build/Resources/lightgbm_cmakelists.txt ../CMakeLists.txt && \
    cmake .. && \
    cd /build/MR/Libs/External/LightGBM && \
    find ./ -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    cd /build/MR/Libs/External/LightGBM/LightGBM/build && \
    make -j20 && \
    cp $MR_ROOT/Libs/External/LightGBM/LightGBM/lib_lightgbm_static.a /build/lib && \
    echo "(II) INFO: Compiling AlgoMarker" && \
    cd $MR_ROOT/Projects/Resources/CMakeUtils && \
    find ./ -type f -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    find ${MR_ROOT}/Libs/Internal/AlgoMarker -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    cd ${MR_ROOT}/Libs/Internal/InfraMed && \
    perl ${MR_ROOT}/Projects/Scripts/Perl-scripts/create_cmake_files.pl --des=InfraMed && \
    cd ${MR_ROOT}/Libs/Internal/Logger && \
    perl ${MR_ROOT}/Projects/Scripts/Perl-scripts/create_cmake_files.pl --des=Logger && \
    cd ${MR_ROOT}/Libs/Internal/MedAlgo && \
    perl ${MR_ROOT}/Projects/Scripts/Perl-scripts/create_cmake_files.pl --des=MedAlgo && \
    cd ${MR_ROOT}/Libs/Internal/MedFeat && \
    perl ${MR_ROOT}/Projects/Scripts/Perl-scripts/create_cmake_files.pl --des=MedFeat && \
    command cp -f /build/Resources/AlgoMarker/AlgoMarker-export.version ${MR_ROOT}/Libs/Internal/AlgoMarker/AlgoMarker/AlgoMarker-export.version && \
    command cp -f /build/Resources/AlgoMarker/AlgoMarker.h ${MR_ROOT}/Libs/Internal/AlgoMarker/AlgoMarker/AlgoMarker.h && \
    mkdir -p ${MR_ROOT}/Libs/Internal/AlgoMarker/CMakeBuild/Linux/Release && \
    cd ${MR_ROOT}/Libs/Internal/AlgoMarker/CMakeBuild/Linux/Release && \
    command cp -f /build/Resources/AlgoMarker/AlgoMarker_TopLeveL_CMakeLists.${GIT_TAG} ${MR_ROOT}/Libs/Internal/AlgoMarker/CMakeLists.txt && \
    command cp -f /build/Resources/AlgoMarker/AlgoMarker_CMakeLists.${GIT_TAG} ${MR_ROOT}/Libs/Internal/AlgoMarker/AlgoMarker/CMakeLists.txt && \
    tar zxf /build/Resources/test_tool.${GIT_TAG}.tar.gz -C ${MR_ROOT}/Libs/Internal/AlgoMarker/ && \
    find ${MR_ROOT}/Libs -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    cmake ${MR_ROOT}/Libs/Internal/AlgoMarker/ && \
    make -j8 && \
    mkdir -p /Release/ && \
    cp ${MR_ROOT}/Libs/Internal/AlgoMarker/CMakeBuild/Linux/Release/AlgoMarker/libdyn_AlgoMarker.so /Release/libdyn_AlgoMarker.${GIT_TAG}.so && \
    cp ${MR_ROOT}/Libs/Internal/AlgoMarker/Linux/AMApiTester /Release/AMApiTester.${GIT_TAG} && \
    strip /Release/libdyn_AlgoMarker.${GIT_TAG}.so && \
    strip /Release/AMApiTester.${GIT_TAG} && \
    nm -CD /Release/libdyn_AlgoMarker.${GIT_TAG}.so | grep " T " > /Release/AlgoMarker.${GIT_TAG}.public_symbols && \
    ldd /Release/libdyn_AlgoMarker.${GIT_TAG}.so > /Release/AlgoMarker.${GIT_TAG}.ldd && \
    echo "(II) SUCCESS: AlgoMarker Shared Object file written to /Release/libdyn_AlgoMarker.${GIT_TAG}.so"


