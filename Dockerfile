FROM ubuntu:22.04

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
  pkg-config \
  libtool \
  automake \
  build-essential \
  subversion \
  git \
  cmake \
  wget \
  meson \
  ninja-build \
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

ENV JANUS_RELEASE="v1.1.4"
COPY scripts/janus.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/janus.sh

COPY scripts/config.sh $SCRIPTS_PATH/
RUN $SCRIPTS_PATH/config.sh

EXPOSE 8188 8189 6000/udp

CMD ["/root/janus/bin/janus"]
