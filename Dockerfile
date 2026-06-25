# syntax=docker/dockerfile:1
#
# VisionPort Janus image — modern, multi-stage, streaming-plugin-only.
#
# ONE image for BOTH the head node and the facade. Behaviour is set entirely by
# the config mounted at /root/janus/etc/janus (Chef-managed in prod), so the same
# binary serves the internal collaboration hub and the internet-facing relay.
#
# Ubuntu 24.04 already ships current WebRTC libs (libnice 0.1.21, libsrtp2 2.5.0,
# libwebsockets 4.3.3), so we install those from apt and compile ONLY Janus.
# That removes the source builds (and their GCC-14/-Werror + meson-multiarch
# quirks) and lets configure find everything in standard /usr paths.
#
#   Build:  docker build -t endpoint/janus:1.4.1 .
#   Bump:   docker build --build-arg JANUS_VERSION=v1.4.2 -t endpoint/janus:1.4.2 .
#   Pin base: docker build --build-arg UBUNTU_RELEASE=22.04 .   (24.04 is the default)
#
# The install prefix is kept at /root/janus so this is a DROP-IN replacement for
# the old image: existing configs (configs_folder, plugins_folder, cert paths)
# and the `-v .../conf:/root/janus/etc/janus:ro` mount all keep working.

ARG UBUNTU_RELEASE=24.04

############################################################
# Stage 1 — builder: compile Janus against Ubuntu's libs
############################################################
FROM ubuntu:${UBUNTU_RELEASE} AS builder

ARG JANUS_VERSION=v1.4.1
ENV DEBIAN_FRONTEND=noninteractive

# Build toolchain + Janus deps straight from Ubuntu (no source builds).
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential pkg-config git wget ca-certificates openssl \
      autoconf automake autopoint libtool m4 gengetopt \
      libnice-dev libsrtp2-dev libwebsockets-dev \
      libssl-dev libglib2.0-dev libjansson-dev libconfig-dev \
    && rm -rf /var/lib/apt/lists/*

# Janus, built for streaming fanout only. All deps are in standard /usr paths,
# so configure finds them with no PKG_CONFIG_PATH/CPPFLAGS/LDFLAGS needed.
# Transports: keep WebSockets, drop the rest. No data channels, recording,
# TURN-REST, or event handlers. Plugins: streaming only.
RUN cd /tmp \
    && git clone --depth 1 -b "${JANUS_VERSION}" https://github.com/meetecho/janus-gateway.git \
    && cd janus-gateway && ./autogen.sh \
    && ./configure --prefix=/root/janus \
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
# WebRTC authenticates media by fingerprint, so self-signed is fine for DTLS.
RUN mkdir -p /root/janus/certs \
    && openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
        -subj "/CN=visionport-janus" \
        -keyout /root/janus/certs/janus.key \
        -out /root/janus/certs/janus.pem

############################################################
# Stage 2 — runtime: slim image, apt runtime libs + Janus
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

# Runtime shared libs from apt (Ubuntu 24.04 package names; libwebsockets
# carries the t64 suffix from the 64-bit time_t transition).
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libnice10 libsrtp2-1 libwebsockets19t64 \
      libssl3 libglib2.0-0 libjansson4 libconfig9 \
    && rm -rf /var/lib/apt/lists/*

# Bring over just Janus (binaries + streaming/websockets .so + configs + cert);
# its linked libs all resolve from the apt packages above in standard paths.
COPY --from=builder /root/janus /root/janus

# In prod, Chef mounts the real .jcfg read-only over the baked-in defaults:
#   -v /etc/janus/conf:/root/janus/etc/janus:ro
EXPOSE 8188

CMD ["/root/janus/bin/janus"]
