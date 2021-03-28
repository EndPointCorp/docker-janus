FROM ubuntu:18.04

# bootstrap environment
ENV DEPS_HOME="/root/janus"
ENV SCRIPTS_PATH="/tmp/scripts"

# install baseline package dependencies
RUN apt-get -y update && apt-get install -y libmicrohttpd-dev \
  libconfig-dev \
  libjansson-dev \
  libssl-dev \
  libsrtp2-dev \
  libsofia-sip-ua-dev \
  libglib2.0-dev \
  libopus-dev \
  libogg-dev \
  libini-config-dev \
  libcollection-dev \
  pkg-config \
  gengetopt \
  gtk-doc-tools \
  libtool \
  automake \
  build-essential \
  subversion \
  git \
  cmake \
  wget \
 && rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=/root/janus/lib

COPY scripts/bootstrap.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/bootstrap.sh

COPY scripts/usrsctp.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/usrsctp.sh

COPY scripts/libnice.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/libnice.sh

COPY scripts/libwebsockets.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/libwebsockets.sh

ENV JANUS_RELEASE="v0.9.1"
COPY scripts/janus.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/janus.sh

COPY scripts/config.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/config.sh

EXPOSE 8188 8189 5002/udp 5004/udp

CMD ["/root/janus/bin/janus"]
