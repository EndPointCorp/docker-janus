#!/usr/bin/env bash
set -e
git clone https://gitlab.freedesktop.org/libnice/libnice -b 0.1.21 --depth=1 $DEPS_HOME/dl/libnice
cd $DEPS_HOME/dl/libnice
meson builddir
ninja -C builddir
ninja -C builddir install
