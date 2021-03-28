#!/bin/sh

WIDTH=1920
HEIGHT=1080
BITRATE=1024000

gst-launch-1.0 -v videotestsrc is-live=true \
! capsfilter caps=video/x-raw,width=$WIDTH,height=$HEIGHT,framerate=30/1 \
! timeoverlay \
! queue \
! vp8enc deadline=33333 cpu-used=16 target-bitrate=$BITRATE keyframe-max-dist=90 max-quantizer=24 \
! rtpvp8pay \
! udpsink host=janus port=6000 sync=false qos=true
