FROM centos1810dev:latest AS builder
RUN mkdir -p /build
COPY ./medial-dist-builder /build/medial-dist-builder
RUN cd /build/medial-dist-builder && \
    /build/medial-dist-builder/install.sh
#RUN bash -c ". /opt/medial/python36/enable && pip install --no-index --find-links=file:///build/medial-dist-builder/downloads/python36-repo/ -r numpy" && \
#    bash -c ". /opt/medial/python27/enable && pip install --no-index --find-links=file:///build/medial-dist-builder/downloads/python27-repo/ -r numpy" && \
#    bash -c ". /opt/medial/python36/enable && pip install --no-index --find-links=file:///build/medial-dist-builder/downloads/python36-repo/ -r /build/medial-dist-builder/conf/py3env-requirements.txt" && \
#    bash -c ". /opt/medial/python27/enable && pip install --no-index --find-links=file:///build/medial-dist-builder/downloads/python27-repo/ -r /build/medial-dist-builder/conf/py2env-requirements.txt"

FROM centos1810dev:latest
COPY --from=builder /etc/opt/medial /etc/opt/medial
COPY --from=builder /var/opt/medial/ /var/opt/medial/
COPY --from=builder /opt/medial /opt/medial
COPY ./resources/m_add_user.sh  /opt/medial/dist/usr/bin/m_add_user.sh
RUN echo '#!/bin/bash' > /etc/profile.d/medial_python3_enable.sh && \
    cat /opt/medial/dist/enable >> /etc/profile.d/medial_python3_enable.sh && \
    chmod +x /etc/profile.d/medial_python3_enable.sh && \
    echo '#!/bin/bash' > /opt/medial/dist/usr/bin/start_jup && \
    echo "/opt/medial/python36/usr/bin/jupyterhub_init_d_script start &" >> /opt/medial/dist/usr/bin/start_jup && \
    chmod +x /opt/medial/dist/usr/bin/start_jup && \
    chmod +x /opt/medial/dist/usr/bin/m_add_user.sh && \
    /opt/medial/dist/usr/bin/m_add_user.sh medial openformedial
