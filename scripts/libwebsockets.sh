#!/usr/bin/env bash
set -e
git clone https://github.com/warmcat/libwebsockets.git -b v4.3.2 --depth 1 $DEPS_HOME/dl/libwebsockets
cd $DEPS_HOME/dl/libwebsockets
mkdir build
cd build
cmake -DLWS_MAX_SMP=1 -DCMAKE_INSTALL_PREFIX=$DEPS_HOME -DCMAKE_C_FLAGS="-fpic" ..
make -j4 && make install
