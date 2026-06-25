# docker-janus

Builds the **VisionPort Janus image** — one image used on **both** the head node
(internal collaboration hub) and the facade (internet-facing relay). It is a
modern, multi-stage, **streaming-plugin-only** build of upstream
[janus-gateway](https://github.com/meetecho/janus-gateway).

There are **no Janus code changes here** — the image is stock Janus compiled from
the pinned upstream tag, plus configuration mounted at runtime.

## What's in the image

| | |
|---|---|
| Janus | `v1.4.1` (current 1.x / multistream line) |
| Base | `ubuntu:24.04` (OpenSSL 3.x) — pin older with `--build-arg UBUNTU_RELEASE=22.04` |
| WebRTC deps | libnice `0.1.21`, libsrtp2 `2.5.0`, libwebsockets `4.3.3` — from **Ubuntu 24.04 apt** (only Janus is compiled from source) |
| Build | multi-stage → runtime image ships only the binaries + runtime libs |
| Enabled | **streaming** plugin, **WebSocket** transport |
| Disabled | all other plugins; REST/HTTP, RabbitMQ, MQTT, Nanomsg, unix-sockets; data channels; TURN REST API; event handlers |
| Install prefix | `/root/janus` (kept stable so existing configs/mounts are drop-in) |

Behaviour is set **entirely by config**, not the image — see the per-host configs
that Chef mounts at `/root/janus/etc/janus`.

## Build

```bash
docker build -t endpoint/janus:1.4.1 .
# bump a version without editing the Dockerfile:
docker build --build-arg JANUS_VERSION=v1.4.2 -t endpoint/janus:1.4.2 .
```

## Run

Config is mounted read-only over the baked-in defaults; the install prefix is
unchanged, so the existing mount path still applies:

```bash
docker run --network host \
  -v /etc/janus/conf:/root/janus/etc/janus:ro \
  endpoint/janus:1.4.1
```

Confirm the running version:

```bash
docker exec <container> /root/janus/bin/janus --version
```
