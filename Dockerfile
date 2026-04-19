#
# Builder image
#
FROM golang:1.21.5-alpine3.17 AS builder

ARG RESTIC_VERSION=0.18.1
ARG RESTIC_SHA256_AMD64=680838f19d67151adba227e1570cdd8af12c19cf1735783ed1ba928bc41f363d
ARG RESTIC_SHA256_ARM=1ead22ca3b123f11cd1ce74ba4079c324aa616efb25227c715471420a1c2a364
ARG RESTIC_SHA256_ARM64=87f53fddde38764095e9c058a3b31834052c37e5826d2acf34e18923c006bd45

ARG RCLONE_VERSION=1.72.0
# These are the checksums for the zip files
ARG RCLONE_SHA256_AMD64=f3757aa829828c0f3359301bea25eef4d4fd62de735c47546ee6866c5b5545e2
ARG RCLONE_SHA256_ARM=531c4a98de3b4287b2caabbc15d914c608a151cb69a661a0a4dc47542d1cf5ab
ARG RCLONE_SHA256_ARM64=c1669ef42d4ad65e3bb3f2cf0b2acf76cf0cbffefe463349a4f2244d8dbed701

ARG SUPERCRONIC_VERSION=0.2.44
ARG SUPERCRONIC_SHA256_AMD64=6feff7d5eba16a89cf229b7eb644cfae2f03a32c62ca320f17654659315275b6
ARG SUPERCRONIC_SHA256_ARM=d2f18cf24f6df36eb49173dbbd454815475699c43c99b6ab3983436c6994a7bf
ARG SUPERCRONIC_SHA256_ARM64=ec29b3129ab20100971d21d391150d50398e5caaa33b8652eab919e2c5143057

RUN apk add --no-cache curl

RUN case "$(uname -m)" in \
  x86_64 ) \
    echo amd64 >/tmp/ARCH \
    ;; \
  armv7l) \
    echo arm >/tmp/ARCH \
    ;; \
  aarch64) \
    echo arm64 >/tmp/ARCH \
    ;; \
  esac

RUN case "$(cat /tmp/ARCH)" in \
  amd64 ) \
    echo "${RESTIC_SHA256_AMD64}" > RESTIC_SHA256 ; \
    echo "${RCLONE_SHA256_AMD64}" > RCLONE_SHA256 ; \
    echo "${SUPERCRONIC_SHA256_AMD64}" > SUPERCRONIC_SHA256 ; \
    ;; \
  arm ) \
    echo "${RESTIC_SHA256_ARM}" > RESTIC_SHA256 ; \
    echo "${RCLONE_SHA256_ARM}" > RCLONE_SHA256 ; \
    echo "${SUPERCRONIC_SHA256_ARM}" > SUPERCRONIC_SHA256 ; \
    ;; \
  arm64 ) \
    echo "${RESTIC_SHA256_ARM64}" > RESTIC_SHA256 ; \
    echo "${RCLONE_SHA256_ARM64}" > RCLONE_SHA256 ; \
    echo "${SUPERCRONIC_SHA256_ARM64}" > SUPERCRONIC_SHA256 ; \
    ;; \
  *) \
    echo "unknown architecture '$(cat /tmp/ARCH)'" ; \
    exit 1 ; \
    ;; \
 esac

RUN curl -sL --fail -o restic.bz2 https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_$(cat /tmp/ARCH).bz2 \
 && echo "$(cat RESTIC_SHA256)  restic.bz2" | sha256sum -c - \
 && bzip2 -d -v restic.bz2 \
 && mv restic /usr/local/bin/restic \
 && chmod +x /usr/local/bin/restic

 RUN curl -sL --fail -o rclone.zip https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-$(cat /tmp/ARCH).zip \
 && echo "$(cat RCLONE_SHA256)  rclone.zip" | sha256sum -c - \
 && unzip rclone.zip \
 && mv rclone-v${RCLONE_VERSION}-linux-$(cat /tmp/ARCH)/rclone /usr/local/bin/rclone \
 && chmod +x /usr/local/bin/rclone \
 && rm -rf rclone-v${RCLONE_VERSION}-linux-$(cat /tmp/ARCH) \
 && rm rclone.zip

RUN curl -sL -o supercronic https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-$(cat /tmp/ARCH) \
 && echo "$(cat SUPERCRONIC_SHA256)  supercronic" | sha256sum -c - \
 && chmod +x supercronic \
 && mv supercronic /usr/local/bin/supercronic


#
# Final image
#
FROM alpine:3.22

RUN apk add --update --no-cache ca-certificates fuse nfs-utils openssh tzdata bash curl docker-cli gzip sqlite \
 && apk add --update --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main postgresql18-client

ENV RESTIC_REPOSITORY=/mnt/restic

COPY --from=builder /usr/local/bin/* /usr/local/bin/
COPY backup prune check /usr/local/bin/
COPY entrypoint /

ENTRYPOINT ["/entrypoint"]
