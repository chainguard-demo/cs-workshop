FROM cgr.dev/chainguard/nginx:latest-dev as chroot

USER root
COPY --from=cgr.dev/chainguard/nginx:latest / /base-chroot
RUN apk add --no-commit-hooks --no-cache --root /base-chroot curl


FROM cgr.dev/chainguard/nginx:latest
COPY --from=chroot /base-chroot /
