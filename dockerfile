FROM alpine:3.22 AS rootfs

ARG ALPINE_VERSION=3.22.2
ARG TARGETARCH

RUN apk add --no-cache wget tar

RUN case "$TARGETARCH" in \
      amd64) ARCH=x86_64 ;; \
      arm64) ARCH=aarch64 ;; \
      *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    mkdir /rootfs && \
    wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz" \
      -O /tmp/alpine.tar.gz && \
    tar -xzf /tmp/alpine.tar.gz -C /rootfs && \
    printf '%s\n' \
      "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/main" \
      "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/community" \
      > /rootfs/etc/apk/repositories && \
    apk --root /rootfs \
      --keys-dir /rootfs/etc/apk/keys \
      --no-cache \
      add alpine-baselayout alpine-keys busybox apk-tools \
          mariadb mariadb-client zlib

RUN apk --root /rootfs \
      --keys-dir /rootfs/etc/apk/keys \
      --no-cache \
      add --upgrade musl zlib

RUN rm -f \
      /rootfs/usr/bin/mariadb-embedded \
      /rootfs/usr/bin/mariadb-plugin \
      /rootfs/usr/bin/mariadb-slap \
      /rootfs/usr/bin/mariadb-import \
      /rootfs/usr/bin/mariadb-show \
      /rootfs/usr/bin/mariadb-check \
      /rootfs/usr/bin/mariadb-dump \
      /rootfs/usr/bin/mariadb-binlog \
      /rootfs/usr/bin/mariadb-tzinfo-to-sql \
      /rootfs/usr/bin/mariadb-waitpid \
      /rootfs/usr/bin/mariadb-conv \
      /rootfs/usr/bin/mariadb-ldb \
      /rootfs/usr/bin/mariadb-secure-installation && \
    rm -rf /rootfs/usr/share/doc /rootfs/usr/share/man /rootfs/usr/share/info

COPY docker-entrypoint.sh /rootfs/usr/local/bin/docker-entrypoint.sh

RUN chmod +x /rootfs/usr/local/bin/docker-entrypoint.sh && \
    mkdir -p /rootfs/var/lib/mysql

FROM scratch

COPY --from=rootfs /rootfs /

VOLUME ["/var/lib/mysql"]
EXPOSE 3306

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
  CMD ["mariadb-admin", "ping", "--socket=/run/mysqld/mysqld.sock", "--user=root"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["mariadbd", "--datadir=/var/lib/mysql", "--user=mysql", "--skip-networking=0", "--bind-address=0.0.0.0", "--port=3306"]
