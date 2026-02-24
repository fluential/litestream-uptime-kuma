# =============================================================================
# Stage 1: Builder — download and prepare all dependencies
# =============================================================================
FROM node:22-slim AS builder

ARG UPTIME_KUMA_VERSION=2.1.3
ARG LITESTREAM_VERSION=0.5.9
ARG TARGETARCH

ENV APP_HOME=/app
WORKDIR $APP_HOME

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    rm -rf /var/lib/apt/lists/*

# Download and extract Litestream (multi-arch)
RUN ARCH=$(case "$TARGETARCH" in arm64) echo "arm64" ;; *) echo "x86_64" ;; esac) && \
    wget -q -O litestream.tar.gz \
      "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${ARCH}.tar.gz" && \
    tar xzf litestream.tar.gz && \
    rm litestream.tar.gz && \
    chmod +x litestream

# Download and extract Uptime Kuma
RUN wget -q -O uptime-kuma.tar.gz \
      "https://github.com/louislam/uptime-kuma/archive/refs/tags/${UPTIME_KUMA_VERSION}.tar.gz" && \
    tar xzf uptime-kuma.tar.gz && \
    mv "uptime-kuma-${UPTIME_KUMA_VERSION}" uptime-kuma && \
    rm uptime-kuma.tar.gz

# Install production dependencies and download pre-built frontend
RUN cd uptime-kuma && \
    npm ci --omit=dev && \
    npm run download-dist

# =============================================================================
# Stage 2: Runtime — minimal production image
# =============================================================================
FROM node:22-slim

ENV APP_HOME=/app
ENV DATA_DIR=$APP_HOME/data
ENV NODE_ENV=production

WORKDIR $APP_HOME

# Install runtime dependencies only
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# Copy application files from builder
COPY --from=builder $APP_HOME/litestream $APP_HOME/litestream
COPY --from=builder $APP_HOME/uptime-kuma $APP_HOME/uptime-kuma

# Copy scripts
COPY gen-config.sh $APP_HOME/gen-config.sh
COPY run.sh $APP_HOME/run.sh
RUN chmod +x $APP_HOME/gen-config.sh $APP_HOME/run.sh

# Create data directory
RUN mkdir -p "$DATA_DIR"

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -sf http://localhost:3001/api/entry-page || exit 1

CMD ["/app/run.sh"]
