# Chainguard Libraries for JavaScript Workshop

This walkthrough demonstrates how to rebuild a Node.js application using Chainguard Libraries for JavaScript dependencies. We'll configure multiple package managers (npm, pnpm, Yarn, Bun) to use Chainguard's verified npm repository and verify dependency sourcing with chainctl.

**Note:** Run `demo.sh` for an automated demo, or follow the steps below manually.

## Overview

1. **Baseline Build:** Build a Node.js app (using `lodash` and `uuid`) with the public npm registry
2. **Chainguard Migration:** Rebuild using Chainguard Libraries with npm, pnpm, Yarn, and Bun

---

## Prerequisites

- **chainctl** logged in (`chainctl auth login`) with `libraries.javascript.pull` entitlements ([install docs](https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/))
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

### Configure npm

```bash
cd ../step2-cg

chainctl auth configure-npm
```

This writes a project-level `.npmrc` pointing at `https://libraries.cgr.dev/javascript/`
with a bearer token minted from your current chainctl session. The token expires with
the session, about an hour, and no identity is created, so there is nothing to clean up
afterwards. For CI systems that cannot log in interactively, `chainctl auth configure-npm
--pull-token` writes a longer-lived pull token instead.

### Configure package managers

**npm/pnpm:** read the `.npmrc` above as is.

**Yarn:** Yarn Classic, which the `node` images ship, also reads `.npmrc`, but it
only sends credentials for unscoped packages when `always-auth` is set. Without
it every install fails with `Couldn't find package ... on the "npm" registry`.
configure-npm does not write that line, so add it:
```bash
echo '//libraries.cgr.dev/javascript/:always-auth=true' >> .npmrc
```
Yarn Berry takes the token in `.yarnrc.yml` instead:
```bash
cat > .yarnrc.yml <<EOF
npmRegistryServer: "https://libraries.cgr.dev/javascript/"
npmAlwaysAuth: true
npmAuthToken: "$(chainctl auth token --audience libraries.cgr.dev)"
nodeLinker: node-modules
EOF
```

**Bun:** takes the same short-lived token in `bunfig.toml`:
```bash
cat > bunfig.toml <<EOF
[install.registry]
url = "https://libraries.cgr.dev/javascript/"
token = "$(chainctl auth token --audience libraries.cgr.dev)"
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
  --secret id=npmrc,src=./.npmrc \
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
rm -f .npmrc .yarnrc.yml bunfig.toml
docker image ls | grep js-lib-example | awk '{print $3}' | xargs docker image rm
```

## Troubleshooting

- **BuildKit:** Enable with `DOCKER_BUILDKIT=1` when using `--secret` flags
- **Auth errors:** The tokens expire with your chainctl session, about an hour. Rerun `chainctl auth configure-npm` and regenerate `bunfig.toml`
- **Port conflicts:** Use `-p 3001:3000` if port 3000 is in use
