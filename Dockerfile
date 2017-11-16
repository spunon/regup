FROM alpine:3.6
MAINTAINER spunon@gmail.com

RUN set -x && \
    apk add --update libintl curl && \
    apk add --virtual build_deps gettext &&  \
    cp /usr/bin/envsubst /usr/local/bin/envsubst && \
    apk del build_deps

ADD start.sh payload.json check.json /

CMD exec /start.sh
