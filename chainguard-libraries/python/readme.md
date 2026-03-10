# Chainguard Libraries for Python Workshop

This walkthrough demonstrates:
1. How to rebuild an existing Python application using Chainguard's verified PyPI repository.
2. How to compare dependency sourcing before and after migration.
3. How to build and scan the application using Chainguard's dev and runtime containers.
4. How to view provenance data for Chainguard Python Libraries.

Run `./demo.sh` for an interactive walkthrough.

> **Note:** We use `uv` instead of `pip` throughout this demo. It is faster and preserves repo precedence when building with Chainguard Libraries. Using `pip` directly is not recommended as it does not guarantee dependencies will be pulled from Chainguard over PyPI.

---

## Prerequisites

- **chainctl** — installed and authenticated with `libraries.python.pull` entitlements. Install docs [here](https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/)
- **jq** for JSON parsing
- A Chainguard organization with Python ecosystem entitlements
- Docker with BuildKit support
- Network access to `https://libraries.cgr.dev/python/`

---

## Setup

```bash
export ORG_NAME="<your-org-name>"
TOKEN_NAME="python-libraries-workshop-token-$USER"
TTL="8760h"
```

---

## Step 1 — Baseline Build (Upstream Python + PyPI)

Build and run a Flask app using upstream Python images and PyPI dependencies as a baseline.

### 1. Inspect dependencies

```bash
cd step1-orig
cat requirements.txt
```

### 2. View the Dockerfile

```bash
cat Dockerfile
```

### 3. Set build variables

```bash
TAG="upstream"
UPSTREAM_PYTHON_IMAGE="python:3.13"
BUILDER_IMAGE="$UPSTREAM_PYTHON_IMAGE"
RUNTIME_IMAGE="${UPSTREAM_PYTHON_IMAGE}-slim"
```

### 4. Build the image

```bash
docker build --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  -t python-lib-example:$TAG .
```

### 5. Run and test

```bash
docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG
curl -F "file=@linky.png" http://127.0.0.1:5055/upload
```

### 6. Scan with chainctl

Since we haven't built with the Chainguard repo yet, we expect 0% coverage from Chainguard.

```bash
docker cp python-lib-example:/app/venv .
chainctl libraries verify --parent $ORG_NAME venv
```

### 7. Cleanup

```bash
docker stop python-lib-example && docker rm python-lib-example && rm -rf venv
```

---

## Step 2 — Build Using Chainguard Libraries

Rebuild the same application with dependencies sourced from Chainguard Libraries while keeping the same upstream Python containers.

### 1. Fetch Chainguard credentials

This produces two env vars: `CHAINGUARD_PYTHON_IDENTITY_ID` and `CHAINGUARD_PYTHON_TOKEN`.

```bash
eval $(chainctl auth pull-token --repository=python --parent=$ORG_NAME --name=$TOKEN_NAME --ttl=$TTL -o env)
```

### 2. Generate .netrc

```bash
cat > .netrc <<EOF
machine libraries.cgr.dev
  login ${CHAINGUARD_PYTHON_IDENTITY_ID}
  password ${CHAINGUARD_PYTHON_TOKEN}
EOF
```

### 3. Review the updated Dockerfile

```bash
cat ../step2-cg-build/Dockerfile
```

The Dockerfile mounts `.netrc` as a Docker secret and sets `UV_INDEX_URL` and `UV_EXTRA_INDEX_URL` to pull from Chainguard first, then PyPI.

### 4. Build using Chainguard Libraries

```bash
TAG="upstream-cg-libs"
BUILDER_IMAGE="$UPSTREAM_PYTHON_IMAGE"
RUNTIME_IMAGE="${UPSTREAM_PYTHON_IMAGE}-slim"

docker build \
  --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  --secret id=netrc,src=./.netrc \
  -t python-lib-example:$TAG \
  -f ../step2-cg-build/Dockerfile .
```

### 5. Run, test, and scan

```bash
docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG
curl -F "file=@linky.png" http://127.0.0.1:5055/upload
docker cp python-lib-example:/app/venv .
chainctl libraries verify --parent $ORG_NAME venv
```

### 6. Cleanup

```bash
docker stop python-lib-example && docker rm python-lib-example && rm -rf venv
```

---

## Step 3 — Full Chainguard Build

Use Chainguard's Python dev and runtime images together with Chainguard Libraries for a fully Chainguard-sourced build.

### 1. Set variables

```bash
TAG="chainguard-cg-libs"
BUILDER_IMAGE="cgr.dev/chainguard/python:latest-dev"
RUNTIME_IMAGE="cgr.dev/chainguard/python:latest"
```

### 2. Review the updated Dockerfile

When using Chainguard Python images, `uv` is already installed so there's no need to install it separately.

```bash
cat ../step3-cg-all/Dockerfile
```

### 3. Build with Chainguard Python images

```bash
docker build \
  --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  --secret id=netrc,src=.netrc \
  -t python-lib-example:$TAG -f ../step3-cg-all/Dockerfile .
```

### 4. Run and test

```bash
docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG
curl -F "file=@linky.png" http://127.0.0.1:5055/upload
docker cp python-lib-example:/app/venv .
chainctl libraries verify --parent $ORG_NAME venv
```

---

## Step 4 — Python Dependency Provenance

Each Chainguard-built dependency includes an SBOM under `<site-packages>/<package>-version.dist-info/sboms/sbom.spdx.json`.

### 1. View package provenance

```bash
CGR_PYTHON_VERSION=$(docker exec python-lib-example python --version | awk '{print $2}' | cut -d . -f1,2)
jq '{spdxVersion, dataLicense, SPDXID, name, documentNamespace, creationInfo, packages: [.packages[0]]}' \
  venv/lib/${CGR_PYTHON_VERSION}/site-packages/flask-3.0.2.dist-info/sboms/sbom.spdx.json | jq .
```

### 2. Cleanup

```bash
docker stop python-lib-example && docker rm python-lib-example && rm -rf venv
```

---

## Final Cleanup

```bash
ID=$(chainctl iam ids ls --parent=$ORG_NAME -o json | jq -r --arg name "$TOKEN_NAME" '.items[] | select(.name | startswith($name)) | .id')
chainctl iam identities delete "$ID" --parent $ORG_NAME --yes
rm .netrc
docker image ls | grep python-lib-example | awk '{print $3}' | xargs docker image rm $1
```

---

## Troubleshooting

- **Docker BuildKit required:** Enable BuildKit (`DOCKER_BUILDKIT=1 docker build …`) when using `--secret` flags.
- **Token authentication issues:** Verify credentials are valid. Re-run `chainctl auth pull-token` if needed.
- **Port conflicts:** If port `5055` is in use, use another mapping (e.g. `-p 5056:5055`).
- **Dependencies not from Chainguard:** Ensure `.netrc` is correct and BuildKit secrets are mounted properly.
