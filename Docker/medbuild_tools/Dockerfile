FROM medbuild_external_resources:latest AS builder1
ARG GIT_USER
ARG GIT_PASS
ARG BUILD_MARCH=x86-64
ENV MR_ROOT=/build/MR \
    CPATH=/build/boost_1_67_0 \
    R_INCL_DIR=/build/R-3.4.0/src/include \
    LIBRARY_PATH=/opt/medial/tools/lib/ \
    LD_LIBRARY_PATH=/opt/medial/tools/lib/ \
    MR_LIBS_NAME="Logger.lib;InfraMed.lib;MedStat.lib;MedUtils.lib;MedAlgo.lib;MedProcessTools.lib;QRF.lib;TQRF.lib;Mars.lib;gbm.lib;micNet.lib;xgboost.lib;rabit.lib;dmlccore.lib;MedTime.lib;lightgbm.lib;libvw.lib;vw_dynamic.lib;MedSparseMat.lib;MedEmbed.lib;MedIO.lib;SerializableObject.lib;MedSplit.lib;MedMat.lib"
COPY Resources/lightgbm_cmakelists.txt /build/
COPY --from=medbuild_external_pyenv:latest /etc/opt/medial /etc/opt/medial
COPY --from=medbuild_external_pyenv:latest /var/opt/medial/ /var/opt/medial/
COPY --from=medbuild_external_pyenv:latest /opt/medial /opt/medial
RUN echo "(II) ********** INFO: Checkout source file" && \
    mkdir -p /build/MR && \
    mkdir -p /build/MR/Libs && \
    mkdir -p /build/MR/Projects/Resources && \
    mkdir -p /build/MR/Projects/Scripts && \
    mkdir -p /build/MR/Projects/Shared && \
    mkdir -p /build/MR/Tools && \
    cd /build/MR && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_libs.git Libs && \
    cd /build/MR && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_tools.git Tools && \
    cd /build/MR/Projects && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_scripts.git Scripts && \
    cd /build/MR/Projects && git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/mr_resources.git Resources && \
    echo "(II) ********** INFO: Compiling xgboost" && \
    mkdir -p /build/MR/Libs/External/xgboost/lib && \
    mkdir -p /build/MR/Libs/External/xgboost/rabit/lib && \
    cd /build/MR/Libs/External/xgboost/ && \
    find ./ -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    cd /build/MR/Libs/External/xgboost/rabit && make clean && make -j20 && \
    cd /build/MR/Libs/External/xgboost && make clean && make -j20 && \
    mkdir -p /opt/medial/tools/lib/python && \
    mkdir -p /opt/medial/tools/bin && \
    cp /build/MR/Libs/External/xgboost/lib/libxgboost.so /opt/medial/tools/lib && \
    cp /build/MR/Libs/External/xgboost/rabit/lib/librabit.so /opt/medial/tools/lib && \
    mkdir -p /server/Work/SharedLibs/linux/lib64/Release/ && \
    cp /build/MR/Libs/External/xgboost/lib/libxgboost.so /server/Work/SharedLibs/linux/lib64/Release/ && \
    cp /build/MR/Libs/External/xgboost/rabit/lib/librabit.so /server/Work/SharedLibs/linux/lib64/Release/ && \
    echo "(II) ********** INFO: Compiling lightgbm" && \
    mkdir -p /build/MR/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/build && \
    cd /build/MR/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/build && \
    cp -f /build/lightgbm_cmakelists.txt ../CMakeLists.txt && \
    cmake .. && \
    cd /build/MR/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3 && \
    find ./ -type f -name CMakeLists.txt -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    cd /build/MR/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/build && \
    make -j20 && \
    cp $MR_ROOT/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/lib_lightgbm_2.2.3.so /opt/medial/tools/lib && \
    cp $MR_ROOT/Libs/External/LightGBM_2.2.3/LightGBM-2.2.3/lib_lightgbm_2.2.3.so /server/Work/SharedLibs/linux/lib64/Release/ && \
    echo "(II) ********** INFO: Compiling Flow" && \
    cd $MR_ROOT/Projects/Resources/CMakeUtils && \
    find ./ -type f -exec sed -i -e "s/-march=[a-zA-Z0-9_-]*/-march=$BUILD_MARCH/g" {} \; && \
    cd $MR_ROOT/Tools/Flow/ && \
    perl /build/MR/Projects/Scripts/Perl-scripts/new_create_cmake_files.pl && \
    /bin/bash /build/MR/Projects/Scripts/Bash-Scripts/smake_rel.sh && \
    strip /build/MR/Tools/Flow/Linux/Release/Flow && \
    cp /build/MR/Tools/Flow/Linux/Release/Flow /opt/medial/tools/bin/ && \
    echo "(II) ********** INFO: Compiling MedProcessUtils" && \
    cd $MR_ROOT/Tools/MedProcessUtils && \
    perl /build/MR/Projects/Scripts/Perl-scripts/new_create_cmake_files.pl && \
    /bin/bash /build/MR/Projects/Scripts/Bash-Scripts/smake_rel.sh && \
    cd $MR_ROOT/Tools/MedProcessUtils/Linux/Release && \
    strip * && \
    cp $MR_ROOT/Tools/MedProcessUtils/Linux/Release/* /opt/medial/tools/bin/ && \
    echo "(II) ********** INFO: Compiling AllTools" && \
    cd $MR_ROOT/Projects/Shared/ && \
    git clone http://$GIT_USER:$GIT_PASS@bitbucket:7990/scm/med/alltools.git AllTools && \
    cd $MR_ROOT/Projects/Shared/AllTools && \
    perl /build/MR/Projects/Scripts/Perl-scripts/new_create_cmake_files.pl && \
    /bin/bash /build/MR/Projects/Scripts/Bash-Scripts/smake_rel.sh && \
    cd $MR_ROOT/Projects/Shared/AllTools/Linux/Release && strip * && \
    cp -n $MR_ROOT/Projects/Shared/AllTools/Linux/Release/* /opt/medial/tools/bin/ && \
    echo "(II) ********** INFO: Copy scripts" && \
    cp -f -r ${MR_ROOT}/Tools/DictUtils /opt/medial/tools/bin/DictUtils && \
    cp -f -r ${MR_ROOT}/Tools/RepoLoadUtils /opt/medial/tools/bin/RepoLoadUtils && \
    cp /build/MR/Projects/Scripts/Perl-scripts/intersect.pl /opt/medial/tools/bin/ && \
    cp /build/MR/Projects/Scripts/Perl-scripts/paste.pl /opt/medial/tools/bin/ && \
    cp /build/MR/Projects/Scripts/Perl-scripts/transpose.pl /opt/medial/tools/bin/ && \
    cp /build/MR/Projects/Scripts/Perl-scripts/subtract.pl /opt/medial/tools/bin/ && \
    echo "(II) ********** INFO: Compiling Python Extension for Medial API" && \
    source /opt/medial/dist/enable && \
    cd $MR_ROOT/Libs/Internal/MedPyExport/generate_binding && \
    chmod +x $MR_ROOT/Libs/Internal/MedPyExport/generate_binding/make* $MR_ROOT/Libs/Internal/MedPyExport/generate_binding/MedPython/scripts/* && \
    ln -s /opt/medial/dist/usr/lib/python3.6/site-packages/numpy/core/include/numpy /opt/medial/dist/usr/include/python3.6m/numpy && \
    ./make.sh && \
    cp /build/MR/Libs/Internal/MedPyExport/generate_binding/Release/medial-python36/* /opt/medial/tools/lib/python/

FROM centos1810dev:latest
ENV LD_LIBRARY_PATH=/opt/medial/tools/lib/
ENV PATH=/opt/medial/tools/bin/:${PATH}
COPY --from=builder1 /opt/medial /opt/medial
RUN sed -i 's;LD_LIBRARY_PATH=;LD_LIBRARY_PATH=/opt/medial/tools/lib:;' /opt/medial/dist/enable && \
    mkdir -p /var/opt/medial/jupyter && \
    /opt/medial/dist/usr/bin/m_add_user.sh medial openformedial && \
    echo '#!/bin/bash' > /etc/profile.d/medial_python3_enable.sh && \
    cat /opt/medial/dist/enable >> /etc/profile.d/medial_python3_enable.sh && \
    chmod +x /etc/profile.d/medial_python3_enable.sh && \
    echo "sys.path.append('/opt/medial/tools/lib/python/')" >> /opt/medial/python36/usr/lib/python3.6/site-packages/sitecustomize.py && \
    echo "c.Spawner.env_keep = ['PATH', 'LD_LIBRARY_PATH', 'MANPATH', 'PKG_CONFIG_PATH', 'XDG_DATA_DIRS', 'PYTHON_LIBRARY', 'PYTHON_INCLUDE_DIR', 'BOKEH_RESOURCES', 'JUPYTER_RUNTIME_DIR']" >> /opt/medial/dist/usr/etc/jupyter/jupyterhub_config.py 

    

#clang
#    cp /opt/rh/llvm-toolset-7/root/usr/lib64/libomp.so /opt/medial/tools/lib/
#FROM centos1810dev:latest
#ENV LD_LIBRARY_PATH=/opt/medial/tools/lib/
#ENV PATH=/opt/medial/tools/bin/:${PATH}
#COPY --from=medbuildstage1 /opt/medial /opt/medial
