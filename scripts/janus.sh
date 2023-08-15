#!/usr/bin/env bash
set -e

# create a self signed cert for the server
mkdir -p $DEPS_HOME/certs/
openssl req \
  -new \
  -newkey rsa:4096 \
  -days 365 \
  -nodes \
  -x509 \
  -subj "/C=AU/ST=NSW/L=Sydney/O=JanusDemo/CN=janus.test.com" \
  -keyout $DEPS_HOME/certs/janus.key \
  -out $DEPS_HOME/certs/janus.pem

cd $DEPS_HOME/dl
git clone https://github.com/EndPointCorp/janus-gateway.git -b ib-capture-time --depth=1
cd janus-gateway
./autogen.sh

./configure --prefix=$DEPS_HOME --enable-websockets --disable-rabbitmq --disable-mqtt --disable-data-channels --disable-docs
export PKG_CONFIG_PATH="$DEPS_HOME"
make
make install
