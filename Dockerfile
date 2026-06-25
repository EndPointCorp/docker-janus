# syntax=docker/dockerfile:1
#
# VisionPort Janus image — modern, multi-stage, streaming-plugin-only.
#
# ONE image for BOTH the head node and the facade. Behaviour is set entirely by
# the config mounted at /root/janus/etc/janus (Chef-managed in prod), so the same
# binary serves the internal collaboration hub and the internet-facing relay.
#
# Dependency build steps follow the known-good recipe from
#   https://github.com/wangsrGit119/janus-webrtc-gateway-docker
# (proven against Janus 1.4.1), but repackaged multi-stage + streaming-only.
#
#   Build:  docker build -t endpoint/janus:1.4.1 .
#   Bump:   docker build --build-arg JANUS_VERSION=v1.4.2 -t endpoint/janus:1.4.2 .
#   Pin base: docker build --build-arg UBUNTU_RELEASE=22.04 .   (24.04 is the default)
#
# The install prefix is intentionally kept at /root/janus so this is a DROP-IN
# replacement for the old image: existing configs (configs_folder, plugins_folder,
# cert_pem/cert_key) and the `-v .../conf:/root/janus/etc/janus:ro` mount all
# keep working unchanged. Only the Janus version + base OS move forward.

ARG UBUNTU_RELEASE=24.04

############################################################
# Stage 1 — builder: compile current WebRTC deps + Janus
############################################################
FROM ubuntu:${UBUNTU_RELEASE} AS builder

# Pinned, current, known-good combination (matches the wangsr reference).
ARG JANUS_VERSION=v1.4.1
ARG LIBNICE_VERSION=0.1.21
ARG LIBSRTP_VERSION=2.6.0
ARG LIBWEBSOCKETS_VERSION=v4.3.2

ENV DEBIAN_FRONTEND=noninteractive \
    PREFIX=/root/janus \
    PKG_CONFIG_PATH=/root/janus/lib/pkgconfig \
    LD_LIBRARY_PATH=/root/janus/lib \
    CPPFLAGS=-I/root/janus/include \
    LDFLAGS=-L/root/janus/lib

# Build toolchain + only the distro -dev libs Janus links directly.
# (No opus/ogg/sofia/microhttpd/usrsctp/curl/libav — the plugins/features that
#  need them are disabled below, which keeps the image small and the surface low.)
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential pkg-config git wget ca-certificates openssl \
      autoconf automake autopoint libtool m4 gengetopt \
      cmake meson ninja-build \
      libssl-dev libglib2.0-dev libjansson-dev libconfig-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# --- libsrtp (DTLS-SRTP) ---
RUN cd /tmp \
    && wget -qO libsrtp.tgz "https://github.com/cisco/libsrtp/archive/v${LIBSRTP_VERSION}.tar.gz" \
    && tar xf libsrtp.tgz && cd "libsrtp-${LIBSRTP_VERSION}" \
    && ./configure --prefix="${PREFIX}" --enable-openssl \
    && make shared_library -j"$(nproc)" && make install

# --- libnice (ICE) — built from source for a current version (Ubuntu's apt is older) ---
# --libdir=lib: meson defaults to a multiarch libdir (lib/x86_64-linux-gnu) on
# Ubuntu, which would hide nice.pc from PKG_CONFIG_PATH; pin it to plain lib so
# it lands alongside libsrtp/libwebsockets under ${PREFIX}/lib.
RUN cd /tmp \
    && git clone --depth 1 -b "${LIBNICE_VERSION}" https://gitlab.freedesktop.org/libnice/libnice.git \
    && cd libnice && meson --prefix="${PREFIX}" --libdir=lib build \
    && ninja -C build && ninja -C build install

# --- libwebsockets (WebSocket signalling transport) ---
# DISABLE_WERROR: libwebsockets 4.3.2 builds with -Werror and trips GCC 14
# (Ubuntu 24.04) on a benign -Wenum-int-mismatch forward-declaration; the
# warning is harmless, so stop treating warnings as fatal.
RUN cd /tmp \
    && wget -qO lws.tgz "https://github.com/warmcat/libwebsockets/archive/${LIBWEBSOCKETS_VERSION}.tar.gz" \
    && tar xf lws.tgz && cd "libwebsockets-${LIBWEBSOCKETS_VERSION#v}" \
    && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCMAKE_C_FLAGS="-fpic" \
             -DLWS_MAX_SMP=1 -DLWS_IPV6=ON -DLWS_WITHOUT_TESTAPPS=ON \
             -DDISABLE_WERROR=ON .. \
    && make -j"$(nproc)" && make install

# --- Janus, built for streaming fanout only ---
# Transports: keep WebSockets, drop the rest. No data channels (streaming
# fanout doesn't use SCTP). No recording/post-processing, no TURN REST, no
# event handlers. Plugins: streaming only (everything else disabled).
RUN cd /tmp \
    && git clone --depth 1 -b "${JANUS_VERSION}" https://github.com/meetecho/janus-gateway.git \
    && cd janus-gateway && ./autogen.sh \
    && ./configure --prefix="${PREFIX}" \
        --disable-rest --disable-rabbitmq --disable-mqtt \
        --disable-nanomsg --disable-unix-sockets \
        --disable-data-channels --disable-turn-rest-api \
        --disable-all-handlers \
        --disable-plugin-audiobridge --disable-plugin-echotest \
        --disable-plugin-sip --disable-plugin-nosip \
        --disable-plugin-recordplay --disable-plugin-textroom \
        --disable-plugin-videocall --disable-plugin-videoroom \
        --disable-plugin-lua --disable-plugin-duktape \
    && make -j"$(nproc)" && make install && make configs

# Default self-signed DTLS cert at the path the configs already reference.
# WebRTC authenticates media by fingerprint, so self-signed is fine for DTLS;
# for `wss` on the facade, mount a real cert over these.
RUN mkdir -p "${PREFIX}/certs" \
    && openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
        -subj "/CN=visionport-janus" \
        -keyout "${PREFIX}/certs/janus.key" \
        -out "${PREFIX}/certs/janus.pem"

############################################################
# Stage 2 — runtime: slim image, only runtime libs + Janus
############################################################
FROM ubuntu:${UBUNTU_RELEASE} AS runtime

ARG BUILD_DATE=undefined
ARG JANUS_VERSION=v1.4.1

LABEL org.opencontainers.image.title="visionport-janus" \
      org.opencontainers.image.description="Janus WebRTC Server (streaming-only) for the VisionPort head node + facade" \
      org.opencontainers.image.version="${JANUS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/meetecho/janus-gateway"

ENV DEBIAN_FRONTEND=noninteractive

# Only the runtime shared libs Janus + the source-built deps load.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libssl3 libglib2.0-0 libjansson4 libconfig9 zlib1g libcap2 \
    && rm -rf /var/lib/apt/lists/*

# Bring over Janus + libnice/libsrtp/libwebsockets + default configs + cert,
# then register the lib dir so the dynamic loader finds the source-built libs.
COPY --from=builder /root/janus /root/janus
RUN echo "/root/janus/lib" > /etc/ld.so.conf.d/janus.conf && ldconfig

# In prod, Chef mounts the real .jcfg read-only over the baked-in defaults:
#   -v /etc/janus/conf:/root/janus/etc/janus:ro
# Ports are config-/network-dependent (prod uses host networking or explicit
# maps): 8188 ws signalling, 6000+ RTP ingest, plus the ICE UDP range.
EXPOSE 8188

CMD ["/root/janus/bin/janus"]
