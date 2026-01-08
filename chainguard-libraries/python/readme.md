# Chainguard Libraries for Python Workshop
- [Chainguard Libraries for Python Workshop](#chainguard-libraries-for-python-workshop)
  - [🧩 Overview](#-overview)
  - [🧰 Prerequisites](#-prerequisites)
  - [⚙️ Setup](#️-setup)
  - [🧱 Step 1 — Baseline Build (Upstream Python + PyPI)](#-step-1--baseline-build-upstream-python--pypi)
    - [1. Inspect dependencies](#1-inspect-dependencies)
    - [2. View the Dockerfile](#2-view-the-dockerfile)
    - [3. Set build variables](#3-set-build-variables)
    - [4. Build the image](#4-build-the-image)
    - [5. Run and test](#5-run-and-test)
    - [6. Scan with chainctl](#6-scan-with-chainctl)
    - [7. Cleanup](#7-cleanup)
  - [🧱 Step 2 — Build Using Chainguard Libraries](#-step-2--build-using-chainguard-libraries)
    - [1. Create a pull token](#1-create-a-pull-token)
    - [2. Generate .netrc](#2-generate-netrc)
    - [3. Review the updated Dockerfile](#3-review-the-updated-dockerfile)
    - [4. Build using Chainguard Libraries](#4-build-using-chainguard-libraries)
    - [5. Run, test, and scan](#5-run-test-and-scan)
    - [6. Cleanup](#6-cleanup)
  - [🧱 Step 3 — Full Chainguard Build](#-step-3--full-chainguard-build)
    - [1. Set variables](#1-set-variables)
    - [2. Review the updated Dockerfile](#2-review-the-updated-dockerfile)
    - [3. Build with Chainguard Python images](#3-build-with-chainguard-python-images)
    - [4. Run and test](#4-run-and-test)
  - [🧱 Step 4 — Python Dependency Provenance](#-step-4--python-dependency-provenance)
    - [1. View package provenance](#1-view-package-provenance)
    - [2. Cleanup](#2-cleanup)
  - [🧹 Final Cleanup](#-final-cleanup)
  - [🧩 Troubleshooting Tips](#-troubleshooting-tips)

This walkthrough demonstrates:
1. How to rebuild an existing Python application using Chainguard’s verified PyPI repository.
2. How to compare dependency sourcing before and after migration.
3. How to build and scan the application using Chainguard's dev and runtime containers.
4. How to view provenance data for Chainguard Python Libraries

**Note:** To run the guided demo magic script instead of following this readme, simply execute the `demo.sh` script in this directory.

---

## 🧩 Overview

We’ll work through three stages:

1. **Baseline Build (Upstream Python & PyPI):**  
   Build a Flask-based sample app using standard upstream Python containers and PyPI dependencies.

2. **Chainguard Libraries Migration (Upstream Python Containers):**  
   Rebuild using Chainguard Libraries for dependencies while keeping the same upstream Python build and runtime containers.

3. **Full Chainguard Build (Chainguard Images + Libraries):**  
   Use Chainguard’s Python dev and runtime images together with Chainguard Libraries.

4. **View Provenance for Chainguard Python Libraries:**  
   Demonstrate how to view Provenance details for Chainguard Python Libraries.


For this demo all builds will use **containerized environments** to avoid needing to have a local python setup. We will also be using `uv` instead of `pip` to install python dependencies since it is faster, and also preserves repo precedence when doing builds with Chainguard Libraries.
>⚠️ It is NOT recommended to use pip when pulling python dependencies directly from the Chainguard repo as it doesn't guarantee dependencies will be pull from Chainguard over PyPI. 

---

## 🧰 Prerequisites

- **chainctl** — installed and authenticated to your Chainguard org with `libraries.python.pull` entitlements. NOTE: The user must have the `libraries.python.pull` role in order to access libraries from `https://libraries.cgr.dev/python/` e.g. `owner` role. Chainctl install docs can be found [here](https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/)
- **jq** for JSON parsing.
- A **Chainguard organization name** (e.g. `myorg.com`) that has Python ecosystem entitlements. 
- Docker installed to run images
- Network access to `https://libraries.cgr.dev/python/`.

---

## ⚙️ Setup

Set your environment variables for the demo:

```bash
# Ecosystem to create a token for, in this case python
ECOSYSTEM="python"
# Name associated with the token
TOKEN_NAME="python-libraries-workshop-token-$USER"
# How long the token should be valid for in hours
TTL="8760h"
# The name of the Chainguard organizaiton with entitlements to the ecosystem.
export ORG_NAME="<YOUR Chainguard ORG name>"
```

---

## 🧱 Step 1 — Baseline Build (Upstream Python + PyPI)

This stage builds and runs a simple Flask app using upstream Python images and dependencies from PyPI — providing a baseline before introducing Chainguard content.

### 1. Inspect dependencies

```bash
# Change Directory into the step1-orig directory 
cd cs-workshop/chainguard-libraries/python/step1-orig
# Review the dependencies used by the application.
cat requirements.txt
```

### 2. View the Dockerfile
View the dockerfile, this is a straightforward dockerfile that builds the app in the first stage and copies it to the runtime image. Note that we use `uv` instead of `pip` for managing python dependencies. Due to its increased speed and ability to set preferences on which repo to pull from.

```bash
# View the build stages and commands in the base Dockerfile.
cat Dockerfile
```

### 3. Set build variables

```bash
# Define image tags and names for the baseline build.
TAG="upstream"
UPSTREAM_PYTHON_IMAGE="python:3.13"
BUILDER_IMAGE="$UPSTREAM_PYTHON_IMAGE"
RUNTIME_IMAGE="${UPSTREAM_PYTHON_IMAGE}-slim"
```

### 4. Build the image

```bash
# Build the app using the upstream Maven builder and Temurin runtime.
docker build --build-arg BUILDER_IMAGE=$BUILDER_IMAGE   --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE   -t python-lib-example:$TAG .
```

### 5. Run and test

```bash
# Start the container and expose port 5055.
docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG

# Upload an image to verify the app works.
curl -F "file=@linky.png" http://127.0.0.1:5055/upload
```

### 6. Scan with chainctl
In this step we will use chainctl to scan the venv directory to determine how many dependencies came from Chainguard repo vs. upstream PyPI. Since we haven't built with the Chainguard repo yet we expect the output to be 0%.

```bash
# Copy the virtual environment from the container for scanning.
docker cp python-lib-example:/app/venv .

# Analyze dependencies with chainctl to confirm dependencies came from PyPI.
chainctl libraries verify --parent $ORG_NAME venv
```

### 7. Cleanup

```bash
# Stop and remove the running container, and delete the copied venv directory.
docker stop python-lib-example && docker rm python-lib-example && rm -rf venv
```

---

## 🧱 Step 2 — Build Using Chainguard Libraries
In this step, you’ll rebuild the same application but redirect pip to pull its dependencies from Chainguard Libraries.
The build and runtime containers remain the same, proving that you can switch dependency sources without breaking builds or changing code.
After the build, you’ll scan to verify that dependencies now originate from Chainguard’s repository.

### 1. Create a pull token

```bash
# Request a Chainguard library token for the Java ecosystem.
CREDS_OUTPUT=$(chainctl auth pull-token \
  --repository="${ECOSYSTEM}" \
  --parent="${ORG_NAME}" \
  --name="${TOKEN_NAME}" \
  --ttl="${TTL}" -o json)

# Extract credentials for Maven authentication.
export CGR_USER=$(echo $CREDS_OUTPUT | jq -r ".identity_id")
export CGR_TOKEN=$(echo $CREDS_OUTPUT | jq -r ".token")
```

### 2. Generate .netrc

Create a `.netrc` file that will be used to hold our credentials to the Chainguard Python repos:

```bash
# Create the pip.conf file
cat > .netrc <<EOF
machine libraries.cgr.dev
  login ${CGR_USER}
  password ${CGR_TOKEN}
EOF
```

### 3. Review the updated Dockerfile

```bash
cat ../step2-cg-build/Dockerfile
```

Notice that the Dockerfile mounts `.netrc` as a **docker secret** to protect credentials and clears caches to force fetching all dependencies from Chainguard.

We also set `UV_INDEX_URL="https://libraries.cgr.dev/python-remediated/simple"` and 
`UV_EXTRA_INDEX_URL="https://libraries.cgr.dev/python/simple https://PyPI.org/simple"` to set the Chainguard repos to pull dependencies from first, followed by PyPI.
`

### 4. Build using Chainguard Libraries

```bash
# Define a new tag to differentiate this build.
TAG="upstream-cg-libs"
BUILDER_IMAGE="$UPSTREAM_PYTHON_IMAGE"
RUNTIME_IMAGE="${UPSTREAM_PYTHON_IMAGE}-slim"

# Build the image:
docker build \
  --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  --secret id=netrc,src=./.netrc \
  -t python-lib-example:$TAG \
  -f ../step2-cg-build/Dockerfile .
```

### 5. Run, test, and scan

```bash
# Start the container and verify it still functions as before.
docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG

curl -F "file=@linky.png" http://127.0.0.1:5055/upload

# Copy the venv directory out for scanning with chainctl.
docker cp python-lib-example:/app/venv .

# Scan with chainctl to determine dependency coverage sourced from Chainguard.
chainctl libraries verify --parent $ORG_NAME venv
```

### 6. Cleanup

```bash
# Stop and remove the container, then delete the venv directory.
docker stop python-lib-example && docker rm python-lib-example && rm -rf venv
```

---

## 🧱 Step 3 — Full Chainguard Build

This step runs the full “secure supply chain” build: using Chainguard’s python-dev image as the builder and Chainguard’s minimal python image as the runtime.

The result is an application where the entire toolchain: builder, runtime, and dependencies — comes from Chainguard.

### 1. Set variables

```bash
# Define a new tag to differentiate this build.
TAG="chainguard-cg-libs"

# Use the Chainguard python images:
BUILDER_IMAGE="cgr.dev/chainguard/python:latest-dev"
RUNTIME_IMAGE="cgr.dev/chainguard/python:latest"
```

### 2. Review the updated Dockerfile
When using the Chainguard containers for the Python build, `uv` is already installed by default so there is no need to install `uv` on the Chainguard image, everything else is left the same from step 2. Let's look at the difference:

```bash
cat ../step3-cg-all/Dockerfile
```

### 3. Build with Chainguard Python images

```bash
# Build the app using Chainguard's python images for builder and runtime.
docker build \
  --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  --secret id=netrc,src=.netrc \
  -t python-lib-example:$TAG -f ../step3-cg-all/Dockerfile .
```

### 4. Run and test
Now we will run and test the container and then copy the venv directory locally for analysis with chainctl.

```bash
# Start the app using the Chainguard-built container and test it.
docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG

# Test to ensure functionality still works:
curl -F "file=@linky.png" http://127.0.0.1:5055/upload

# Copy the venv directory out for scanning with chainctl.
docker cp python-lib-example:/app/venv .

# Scan with chainctl to determine dependency coverage sourced from Chainguard.
chainctl libraries verify --parent $ORG_NAME venv

```

## 🧱 Step 4 — Python Dependency Provenance
### 1. View package provenance

Each Chainguard-built dependency includes an SBOM under  
`<site-packages>/<package-name>-version.dist-info/sboms/sbom.spdx.json`.

Inspect provenance for a specific package, note that the SBOM indicates that the dependency was built by Chainguard, and the git url and commit hash can be verified.
```bash
# Account for python version updates down the road
set -- ./venv/lib/python*
PYTHON_VERSION=$(basename "$1")

# Use JQ to read the sbom file
jq '{spdxVersion, dataLicense, SPDXID, name, documentNamespace, creationInfo, packages: [.packages[0]]}'   venv/lib/${PYTHON_VERSION}/site-packages/flask-3.0.2.dist-info/sboms/sbom.spdx.json | jq .
```


### 2. Cleanup

```bash
docker stop python-lib-example && docker rm python-lib-example && rm -rf venv
```

---

## 🧹 Final Cleanup

Remove temporary files and delete the Chainguard token used for the python library access:

```bash
# Look up and delete the temporary identity used for the Chainguard pull token.
ID=$(chainctl iam ids ls --parent="$ORG_NAME" -o json | jq -r --arg name "$TOKEN_NAME" '.items[] | select(.name | startswith($name)) | .id')
chainctl iam identities delete "$ID" --parent "$ORG_NAME" --yes

# Remove the pip.conf file
rm .netrc
```

---

## 🧩 Troubleshooting Tips

- **Docker BuildKit required:**  
  Enable BuildKit (`DOCKER_BUILDKIT=1 docker build …`) when using `--secret` flags.

- **Token authentication issues:**  
  Verify `$CGR_USER` and `$CGR_TOKEN` are valid. Re-run `chainctl auth pull-token` if needed.

- **Port conflicts:**  
  If port `5055` is in use, use another mapping (e.g. `-p 5056:5055`).

- **Dependencies not from Chainguard:**  
  Ensure your `.netrc` is correct and that BuildKit secrets are mounted properly.
