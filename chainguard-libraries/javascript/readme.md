# Chainguard Libraries for JavaScript Workshop

This walkthrough demonstrates how to rebuild a Node.js application using Chainguard Libraries for JavaScript dependencies. We'll configure multiple package managers (npm, pnpm, Yarn, Bun) to use Chainguard's verified npm repository and verify dependency sourcing with chainctl.

**Note:** Run `demo.sh` for an automated demo, or follow the steps below manually.

## Overview

1. **Baseline Build:** Build a Node.js app (using `lodash` and `uuid`) with the public npm registry
2. **Chainguard Migration:** Rebuild using Chainguard Libraries with npm, pnpm, Yarn, and Bun

---

## Prerequisites

- **chainctl** with `libraries.javascript.pull` entitlements ([install docs](https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/))
- **jq** for JSON parsing
- **Docker** to build and run images
- A Chainguard organization with JavaScript ecosystem entitlements

## Setup

```bash
export ORG_NAME="<your-org-name>"
```

---

## Step 1: Baseline Build (Upstream npm Registry)

```bash
cd step1-orig

cat package.json
cat Dockerfile

docker build \
  --build-arg BUILDER_IMAGE=node:22 \
  --build-arg RUNTIME_IMAGE=node:22-slim \
  -t js-lib-example:upstream .

docker run -d -p 3000:3000 --name js-lib-example js-lib-example:upstream
curl http://localhost:3000
curl http://localhost:3000/api/health

docker cp js-lib-example:/app/node_modules .
chainctl libraries verify --parent $ORG_NAME node_modules

docker stop js-lib-example && docker rm js-lib-example && rm -rf node_modules
```

---

## Step 2: Build Using Chainguard Libraries

### Create credentials

```bash
cd ../step2-cg

CREDS_OUTPUT=$(chainctl auth pull-token \
  --library-ecosystem=javascript \
  --parent=$ORG_NAME \
  --name=js-workshop-token-$USER \
  --ttl=8760h \
  -o json)

export CGR_USER=$(echo $CREDS_OUTPUT | jq -r ".identity_id")
export CGR_TOKEN=$(echo $CREDS_OUTPUT | jq -r ".token")
```

### Configure package managers

**npm/pnpm:**
```bash
cat > .npmrc <<EOF
registry=https://libraries.cgr.dev/npm/
//libraries.cgr.dev/npm/:_auth=$(echo -n "${CGR_USER}:${CGR_TOKEN}" | base64)
//libraries.cgr.dev/npm/:always-auth=true
EOF
```

**Yarn:**
```bash
cat > .yarnrc.yml <<EOF
npmRegistryServer: "https://libraries.cgr.dev/npm/"
npmAlwaysAuth: true
npmAuthIdent: "${CGR_USER}:${CGR_TOKEN}"
nodeLinker: node-modules
EOF
```

**Bun:**
```bash
cat > bunfig.toml <<EOF
[install]
registry = "https://libraries.cgr.dev/npm/"

[install.scopes]
"libraries.cgr.dev" = { token = "${CGR_TOKEN}", username = "${CGR_USER}" }
EOF
```

### Build with npm

```bash
docker build \
  --build-arg BUILDER_IMAGE=node:22 \
  --build-arg RUNTIME_IMAGE=node:22-slim \
  --secret id=npmrc,src=./.npmrc \
  -t js-lib-example:npm-cg \
  -f Dockerfile.npm .

docker run -d -p 3000:3000 --name js-lib-example js-lib-example:npm-cg
curl http://localhost:3000

docker cp js-lib-example:/app/node_modules .
chainctl libraries verify --parent $ORG_NAME node_modules
docker stop js-lib-example && docker rm js-lib-example && rm -rf node_modules
```

### Build with pnpm

```bash
docker build \
  --build-arg BUILDER_IMAGE=node:22 \
  --build-arg RUNTIME_IMAGE=node:22-slim \
  --secret id=npmrc,src=./.npmrc \
  -t js-lib-example:pnpm-cg \
  -f Dockerfile.pnpm .

docker run -d -p 3000:3000 --name js-lib-example js-lib-example:pnpm-cg
curl http://localhost:3000

docker cp js-lib-example:/app/node_modules .
chainctl libraries verify --parent $ORG_NAME node_modules
docker stop js-lib-example && docker rm js-lib-example && rm -rf node_modules
```

### Build with Yarn

```bash
docker build \
  --build-arg BUILDER_IMAGE=node:22 \
  --build-arg RUNTIME_IMAGE=node:22-slim \
  --secret id=yarnrc,src=./.yarnrc.yml \
  -t js-lib-example:yarn-cg \
  -f Dockerfile.yarn .

docker run -d -p 3000:3000 --name js-lib-example js-lib-example:yarn-cg
curl http://localhost:3000

docker cp js-lib-example:/app/node_modules .
chainctl libraries verify --parent $ORG_NAME node_modules
docker stop js-lib-example && docker rm js-lib-example && rm -rf node_modules
```

### Build with Bun

```bash
docker build \
  --build-arg BUILDER_IMAGE=oven/bun:1 \
  --build-arg RUNTIME_IMAGE=oven/bun:1-slim \
  --secret id=bunfig,src=./bunfig.toml \
  -t js-lib-example:bun-cg \
  -f Dockerfile.bun .

docker run -d -p 3000:3000 --name js-lib-example js-lib-example:bun-cg
curl http://localhost:3000

docker cp js-lib-example:/app/node_modules .
chainctl libraries verify --parent $ORG_NAME node_modules
docker stop js-lib-example && docker rm js-lib-example && rm -rf node_modules
```

---

## Cleanup

```bash
ID=$(chainctl iam ids ls --parent=$ORG_NAME -o json | jq -r --arg name "js-workshop-token-$USER" '.items[] | select(.name | startswith($name)) | .id')
chainctl iam identities delete "$ID" --parent "$ORG_NAME" --yes

rm -f .npmrc .yarnrc.yml bunfig.toml
docker image ls | grep js-lib-example | awk '{print $3}' | xargs docker image rm
```

## Troubleshooting

- **BuildKit:** Enable with `DOCKER_BUILDKIT=1` when using `--secret` flags
- **Auth errors:** Verify `CGR_USER` and `CGR_TOKEN` are set correctly
- **Port conflicts:** Use `-p 3001:3000` if port 3000 is in use
