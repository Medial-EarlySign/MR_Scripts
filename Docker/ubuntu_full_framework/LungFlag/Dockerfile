FROM medial_dev

RUN mkdir -p /earlysign/AlgoMarkers/LungFlag

COPY External_Validation_KIT.tar.bz2 lungflag_am.tar.bz2 /earlysign/AlgoMarkers/LungFlag/

RUN cd /earlysign/AlgoMarkers/LungFlag; tar -xvf External_Validation_KIT.tar.bz2; tar -xvf lungflag_am.tar.bz2; rm External_Validation_KIT.tar.bz2 lungflag_am.tar.bz2

RUN rm -rf /tmp