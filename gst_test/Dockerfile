FROM ubuntu:20.04

RUN apt-get update -y && \
    apt-get install -y gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-plugins-rtp \
                       gstreamer1.0-tools  && \
    apt-get clean -y


ADD run.sh /run.sh

CMD /run.sh
