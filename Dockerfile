# syntax=docker/dockerfile:1.7

ARG GO_VERSION=1.25
ARG ALPINE_VERSION=3.20

FROM --platform=$BUILDPLATFORM swr.cn-north-4.myhuaweicloud.com/opensourceway/golang:${GO_VERSION} AS builder

ARG TARGETOS
ARG TARGETARCH
ARG VERSION=v0.2.6

WORKDIR /app

COPY go.mod go.sum /app/
RUN go mod download

COPY . /app/

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" \
    -o /out/smart-git-proxy ./cmd/proxy

FROM swr.cn-north-4.myhuaweicloud.com/opensourceway/alpine:${ALPINE_VERSION}

ARG VERSION=v0.2.6

LABEL org.opencontainers.image.title="smart-git-proxy" \
      org.opencontainers.image.description="Smart Git HTTP mirror proxy" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/crohr/smart-git-proxy" \
      org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache git ca-certificates tini \
    && addgroup -S smart-git-proxy \
    && adduser -S -G smart-git-proxy -h /var/lib/smart-git-proxy smart-git-proxy \
    && mkdir -p /var/lib/smart-git-proxy/mirrors \
    && chown -R smart-git-proxy:smart-git-proxy /var/lib/smart-git-proxy

COPY --from=builder /out/smart-git-proxy /usr/bin/smart-git-proxy

ENV LISTEN_ADDR=:8080 \
    MIRROR_DIR=/var/lib/smart-git-proxy/mirrors \
    SYNC_STALE_AFTER=2s \
    ALLOWED_UPSTREAMS=github.com \
    LOG_LEVEL=info \
    AUTH_MODE=pass-through

USER smart-git-proxy
WORKDIR /var/lib/smart-git-proxy

EXPOSE 8080

VOLUME ["/var/lib/smart-git-proxy/mirrors"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/smart-git-proxy"]
