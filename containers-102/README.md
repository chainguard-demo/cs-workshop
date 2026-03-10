# Chainguard Workshop: Containers 102
* Deep dive into container images
* Hands on exercises to learn tactics needed for hardened, distroless-type images

## Hands-on Exercises
All exercises assume you are cd'd into the `containers-102` directory (where this README is located).
### Understanding image layers
Steps:
1. Get a big file, untar it, and remove the tarball
   1. `cd layers`
   1. `cat Dockerfile.1` and note the 3 RUN lines to download a big file, untar it, and remove the tarball 
   1. `docker build . -t layers:1 -f Dockerfile.1` 
   1. `docker images layers` Note at the image size is ~33.5MB
   1. `docker image history layers:1` You will see individual layers for each `RUN` line in the Dockerfile

1. Concatenate operations into a single RUN line
   1. `cat Dockerfile.2` and note change to a single `RUN` line to download a big file, untar it, and remove the tarball
   1. `docker build . -t layers:2 -f Dockerfile.2`
   1. `docker images layers` Compare the new image size which is about 1.5MB smaller due to the removal of the tarball in the same `RUN` line
   1. `docker image history layers:2` You will see a single layer for the single `RUN` line in the Dockerfile

### Multi-stage builds
Steps:
1. Using multistage to eliminate unwanted layers
   1. `cd multistage`
   1. `cat Dockerfile.1`<br>This is similar to the 1st step of the previous exercise, but with a multi-stage build.
   1. `docker build . -t mstage:1 -f Dockerfile.1`
   1. `docker images mstage`
   1. `docker images layers`<br>Comparing the image sizes, this one is about 1.2MB smaller that the previous exercise
   1. `docker image history mstage:1`<br>There is now a single layer for the COPY line

1. Copying a dependency to a final stage w/out a package manager
   1. `cat Dockerfile.2`<br>In this example, we want to get `jq` working in the final image but there's no `apk` tooling there because it's a non-dev Chainguard imag, so we are trying to just COPY it.
   1. `docker build . -t mstage:2 -f Dockerfile.2`
   1. `docker run --rm -it mstage:2`<br>We get an error because the required `libonig.so.5` library is missing

1. Find out what libraries are needed, target the builder image
   1. `docker build -t mstage:2b -f Dockerfile.2 --target=builder .`<br>This will build the `builder` stage only
   1. `docker run --rm -it --entrypoint sh -u root mstage:2b`
   1. `ldd /usr/bin/jq`<br>ldd is not installed so we need to find and add it
   1. `apk search --no-cache cmd:ldd`<br>This will search for packages that provide the `ldd` command
   1. `apk add --no-cache posix-libc-utils`<br>This will install the `ldd` command
   2. `ldd /usr/bin/jq`<br>Now we can see the dependencies of the `jq` command and see that `libonig.so.5` is needed
   3. `exit`<br>Exit the container

1. Copy the .so file(s) to the final image
   1. `cat Dockerfile.3`<br> Note the addition of the `libonig.so.5` library to the final image
   1. `docker build . -t mstage:3 -f Dockerfile.3`
   1. `docker run --rm -it mstage:3`<br>Now the `jq` command should work

### Advanced BuildKit Features
Steps:
1. Cache mounts — measure the speedup
   1. `cd buildkit`
   1. `cat Dockerfile.nocache` and note the plain `pip install` with `--no-cache-dir`
   1. `docker build . -t cache:1 -f Dockerfile.nocache` (cold build — note the time)
   1. `touch requirements.txt` to invalidate the layer
   1. `time docker build . -t cache:1 -f Dockerfile.nocache` _(slow again — full reinstall)_
   1. `cat Dockerfile.cache` and note the `--mount=type=cache` on the `RUN` step
   1. `docker build . -t cache:2 -f Dockerfile.cache` (cold build)
   1. `touch requirements.txt`
   1. `time docker build . -t cache:2 -f Dockerfile.cache` _(fast — packages pulled from cache)_

1. Secret mounts — spot the difference in history
   1. `echo "supersecrettoken" > token.txt`
   1. `cat Dockerfile.secret` and note `--mount=type=secret`
   1. `docker build --secret id=pip_token,src=./token.txt -t secret:1 .`
   1. `docker image history secret:1` _(token is not visible)_
   1. `cat Dockerfile.nosecret` and note `ARG PIP_TOKEN`
   1. `docker build --build-arg PIP_TOKEN=supersecrettoken -t secret:2 -f Dockerfile.nosecret .`
   1. `docker image history secret:2` _(token is visible in the RUN layer!)_
   1. Add `token.txt` to `.gitignore` and `.dockerignore` — it's already done here as an example

### Image Signing & Attestations
Steps:
1. Sign and verify your own image (Exercise 4.1)
   1. `cd signing`
   1. `cosign generate-key-pair`<br>Enter a password when prompted. This writes `cosign.key` (private) and `cosign.pub` (public).
   1. `docker build . -t ttl.sh/cg-workshop-$USER:1h`
   1. `docker push ttl.sh/cg-workshop-$USER:1h`<br>`ttl.sh` is a free ephemeral public registry — no login required. Images expire after the duration in the tag.
   1. `IMAGE=$(crane digest ttl.sh/cg-workshop-$USER:1h)`
   1. `cosign sign --key cosign.key ttl.sh/cg-workshop-$USER@${IMAGE}`
   1. `cosign verify --key cosign.pub ttl.sh/cg-workshop-$USER@${IMAGE}`

1. Generate and scan an SBOM (Exercise 4.2)
   1. `syft cgr.dev/chainguard/python:latest`<br>Shows all packages in the image in table format
   1. `syft cgr.dev/chainguard/python:latest -o spdx-json > sbom.json`
   1. `jq '.packages | length' sbom.json`<br>Count the packages
   1. `jq '.packages[].name' sbom.json`<br>List package names
   1. `grype cgr.dev/chainguard/python:latest`<br>Scan for vulnerabilities — expect zero findings
   1. `grype python:3.13-slim`<br>Compare against a standard Python image