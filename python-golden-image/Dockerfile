# syntax=docker/dockerfile:1.7

FROM cgr.dev/chainguard-private/python:3-dev AS package_builder

COPY --from=cgr.dev/chainguard-private/python:latest / /base-chroot

USER root
RUN apk add --no-commit-hooks --no-cache --root /base-chroot bash-binsh \
    && apk add --no-cache --root /base-chroot curl tzdata \
    && apk del --no-commit-hooks --root /base-chroot bash-binsh

RUN echo "US/Eastern" > /base-chroot/etc/timezone

FROM cgr.dev/chainguard-private/python:3

COPY --from=package_builder /base-chroot /

COPY --from=package_builder /base-chroot/usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=package_builder /base-chroot/usr/share/zoneinfo /etc/localtime
COPY --from=package_builder /base-chroot/etc/timezone /etc/timezone

ENV TZ="America/New_York"

USER 65532