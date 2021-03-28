# docker-janus

Run up a [janus-gateway](https://github.com/meetecho/janus-gateway) instance using docker, 

## Demonstration of streaming camera audio + video to web browser

1. install docker-compose
2. run `VIDEO_DEVICE=/dev/video0 ALSA_DEVICE=plughw:2,0 docker-compose up` 
    assuming that your camera has `/dev/video0` device and your recording audio source is
    at plughw:2,0
3. open browser at http://localhost:8000

you should see a view of camera and hear sounds from your microphone

