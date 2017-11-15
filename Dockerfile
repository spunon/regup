FROM registry.hub.docker.com/odise/busybox-curl
MAINTAINER spunon@gmail.com

RUN curl -sL0 https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64>/bin/jq && chmod +x /bin/jq

ADD start.sh payload.json check.json /

CMD exec /start.sh
