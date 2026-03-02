# Chroot Method

This method allows for installing packages, adding users, etc to an image in a multi-stage build without needing to copy files one by one between stages.

## Full Example

This full example shows many of the options you can leverage.

```Dockerfile
ARG IMAGE="cgr.dev/yourcompany.com/python:3.13" # (1)
FROM ${IMAGE} AS runtime # (2)
FROM cgr.dev/yourcompany.com/python:3.13-dev AS builder # (3)

COPY --from=runtime / /base-chroot # (4)
COPY myfile /tmp/myfile # (5)

USER root
RUN apk add --no-commit-hooks --no-cache --root /base-chroot busybox \ # (6)
   && apk add --no-cache --root /base-chroot curl \
   && chroot /base-chroot adduser -Du 31337 customuser \
   && cp /tmp/myfile /base-chroot/opt/myfile \
   && chmod 755 /base-chroot/opt/myfile \
   #
   && apk del --no-commit-hooks --root /base-chroot busybox # (7)

FROM runtime # (8)
COPY --from=builder /base-chroot / # (9)
```

1. We take in our runtime image as an arg

2. We set the arg as "runtime" because you cannot reference args in a copy

3. You can use any image as a build step as long as it has apk tools installed

4. We create a "chroot" directory from our runtime image filesystem

5. This is just an example of copying a file out of bounds of the chroot

6. Add busybox so that we can run apk and other commands inside the chroot, add curl as an example, optionally add a user. We also do something with the out of bounds file by calling the full path. This means you don’t have to copy libraries, user files, etc separately

7. We are removing busybox so that when we copy the binaries we do not add busybox to images that don’t contain it

8. Use our runtime as the final image

9. Merge the base-chroot with our final image filesystem

## Smaller Example

This simpler example just shows adding a couple of packages.

```Dockerfile
ARG IMAGE="cgr.dev/yourcompany.com/python:3.13" 
FROM ${IMAGE} AS runtime 
FROM cgr.dev/yourcompany.com/python:3.13-dev AS builder 

COPY --from=runtime / /base-chroot

USER root
RUN apk add --no-commit-hooks --no-cache --root /base-chroot busybox \
   && apk add --no-cache --root /base-chroot curl jq \
   && apk del --no-commit-hooks --root /base-chroot busybox
   
FROM runtime # (8)
COPY --from=builder /base-chroot / 
```
