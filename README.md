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
| WebRTC deps | libsrtp `2.6.0`, libnice `0.1.21`, libwebsockets `4.3.2` (pinned, source-built) |
| Recipe basis | dep build steps follow [wangsrGit119/janus-webrtc-gateway-docker](https://github.com/wangsrGit119/janus-webrtc-gateway-docker) (proven vs 1.4.1), repackaged multi-stage + streaming-only |
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

## Notes

- **Head node** config is already `.jcfg` (correct H.264) and works with this
  image as-is.
- **Facade** config is still old-format `.cfg` INI (and stale VP8). Janus 1.x
  expects `.jcfg`, so that config must be migrated before cutover — convert with
  the bundled `/root/janus/bin/janus-cfgconv` or author fresh `.jcfg`.
- The `scripts/` folder (the old `bootstrap.sh` / `libnice.sh` / `janus.sh` /
  `config.sh` etc.) is **superseded** — the build is now inlined in the
  Dockerfile. Those files can be removed.
- `webapp/` is a stock streaming-plugin test viewer (handy for smoke tests).
- `gst_test.sh` sends a VP8 test pattern and predates the H.264 pipeline; keep
  only as a transport smoke test.

## Streaming test

1. `docker build -t endpoint/janus:1.4.1 .`
2. `docker run --network host endpoint/janus:1.4.1` (uses baked-in default config)
3. Point an H.264 RTP sender at the configured `videoport`.
4. Serve `webapp/` and browse to it; you should see the stream.
