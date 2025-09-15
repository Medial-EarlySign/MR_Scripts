FROM chiselled-ubuntu:latest
ARG AM_NAME=LungFlag
ARG AM_VERSION=1.2.0

COPY data /

ENTRYPOINT [ "/app/AlgoMarker_Server", "--algomarker_path" ,"/app/${AM_NAME}/${AM_NAME}_${AM_VERSION}/lungflag.amconfig", "--port", "1234", "--no_print", "1" ]