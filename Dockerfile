FROM node as builder

ENV APP_HOME /app
ENV UPTIME_KUMA_VERSION 1.18.5
ENV LITESTREAM_VERSION 0.3.9
ENV LITESTREAM_BUCKET uptime-kuma
ENV LITESTREAM_PATH uptime-kuma-db
ENV DATA_DIR "${APP_HOME}/fs/"

RUN mkdir -p "$APP_HOME"
WORKDIR "$APP_HOME"

RUN apt-get update && apt-get -y install iputils-ping wget
RUN rm -rf "$APP_HOME"/uptime-kuma* && wget -O uptime-kuma-$UPTIME_KUMA_VERSION.tar.gz https://github.com/louislam/uptime-kuma/archive/refs/tags/$UPTIME_KUMA_VERSION.tar.gz && tar xvzf uptime-kuma-$UPTIME_KUMA_VERSION.tar.gz
RUN rm -rf "$APP_HOME"/litestream* && wget https://github.com/benbjohnson/litestream/releases/download/v$LITESTREAM_VERSION/litestream-v$LITESTREAM_VERSION-linux-amd64-static.tar.gz && tar xvzf litestream-v$LITESTREAM_VERSION-linux-amd64-static.tar.gz

RUN mkdir -p "$APP_HOME/fs"
RUN cd uptime-kuma-$UPTIME_KUMA_VERSION && npm ci --production && npm run download-dist

RUN rm -rf "$DATA_DIR" && mkdir -p "$DATA_DIR"
RUN ls -la && mv uptime-kuma-$UPTIME_KUMA_VERSION uptime-kuma



FROM node

ENV APP_HOME /app
ENV LITESTREAM_BUCKET uptime-kuma
ENV LITESTREAM_PATH uptime-kuma-db

ADD gen-config.sh "$APP_HOME/gen-config.sh"

ENV DATA_DIR "${APP_HOME}/fs/"

WORKDIR "$APP_HOME"

COPY --from=builder "$APP_HOME" "$APP_HOME"

CMD /bin/bash -xc 'pwd ; ls -la ; cd uptime-kuma; ../gen-config.sh ; if [[ -n $LITESTREAM_URL ]] ; then ../litestream restore -v -if-replica-exists -config ../litestream.yml "$DATA_DIR"/kuma.db ; exec ../litestream replicate -config ../litestream.yml -exec "node server/server.js"; else exec node server/server.js;fi'
