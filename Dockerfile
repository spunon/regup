FROM registry.hub.docker.com/odise/busybox-curl
MAINTAINER spunon@gmail.com

ADD start.sh payload.json check.json /

CMD exec /start.sh