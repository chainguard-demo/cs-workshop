# Node Migration Example

## Overview

This directory contains an example of migrating a node application from
the upstream node image to the Chainguard equivalent.

The example is a simple application that takes an image and prints it to the
terminal in ASCII.

## Steps

### Using Upstream Image

1. Build the image. Pass the 'not linky' image in as an argument.

```
docker build \
    -t node-example:notlinky \
    -f notlinky.Dockerfile \
    --build-arg IMAGE=notlinky.jpg
```

2. Run the image.

```
docker run --rm node-example:notlinky
```

3. Scan the image.

```
grype node-example:notlinky
```

### Takeaways

1. Note that the upstream image runs by default as the root user (bad practice)
2. Vulnerabilities from the grype scan
3. Number of packages, files, etc.

### Using Chainguard Images

1. Build the image. Pass the 'linky' image in as an argument.

```
docker build \
    -t node-example:linky \
    -f linky.Dockerfile \
    --build-arg IMAGE=linky.jpg
```

2. Run the image.

```
docker run --rm node-example:linky
```

3. Scan the image:

```
grype node-example:linky
```

### Compare Image Sizes:

```
docker images node-example
```

### Takeaways

1. Note that Chainguard image does not run as a root user (by default)
2. 0 Vulnerabilities from the grype scan
3. Number of packages, files, etc.

## Compare Dockerfiles

Diff the two Dockerfiles with git:

```
git diff --no-index -U1000 notlinky.Dockerfile linky.Dockerfile
```

1. Note that container registries are different.
2. We use a multistage build with Chainguard in order to get a smaller runtime
   image.
3. Upstream uses `CMD` since there is a shell, CG doesn't have a shell so it
   uses `ENTRYPOINT`.
4. Note that we are using the -slim image for the runtime in the Chainguard
   dockerfile, this is because we don't need a shell for our example, the
   latest Chainguard node image does have a shell due to many customers using
   `npm start` for their applications, if this is not necessary they should be
   using the slim tag.
5. In the Chainguard image our entrypoint uses dumb-init, this is used to wrap
   the Node process in order to handle signals properly and allow for graceful
   shutdown.
