FROM alpine:3.21

ARG SING_BOX_VERSION=1.13.11
ARG CLOUDFLARED_VERSION=2026.3.0
ARG TARGETARCH

WORKDIR /app

RUN apk add --no-cache ca-certificates bash wget tar libc6-compat && \
    ARCH=$(case "$TARGETARCH" in amd64) echo "amd64" ;; arm64) echo "arm64" ;; *) echo "amd64" ;; esac) && \
    wget -q https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-linux-${ARCH}.tar.gz && \
    tar -xzf sing-box-${SING_BOX_VERSION}-linux-${ARCH}.tar.gz && \
    mv sing-box-${SING_BOX_VERSION}-linux-${ARCH}/sing-box /usr/local/bin/sing-box && \
    rm -rf sing-box-${SING_BOX_VERSION}-linux-${ARCH}* && \
    wget -q -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${ARCH} && \
    chmod +x /usr/local/bin/sing-box /usr/local/bin/cloudflared && \
    apk del wget tar

COPY config.json start.sh ./
RUN chmod +x start.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep -x sing-box > /dev/null && pgrep -x cloudflared > /dev/null || exit 1

CMD ["./start.sh"]
