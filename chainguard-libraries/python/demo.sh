#!/usr/bin/env bash

###############################################################################
# Demo Magic Script: Python Libraries Workshop
###############################################################################

# Load demo-magic
. ../../base.sh
export GIT_PAGER=cat

pei cd step1-orig/

TYPE_SPEED=250
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

###############################################################################
# Intro
###############################################################################
echo -e "
Demo: Converting a Python App to Use Chainguard Libraries

This demo walks through rebuilding an existing Python Flask app using Chainguard Libraries,
transitioning from PyPI dependencies to Chainguard's trusted library source with minimal changes
to the build process.

Stages:
1. Baseline Build: Build with upstream Python and PyPI.
2. Chainguard Libraries: Same upstream images, but dependencies from Chainguard Libraries.
3. Full Chainguard: Chainguard Python images + Chainguard Libraries.
4. Verification: Inspect the SBOM for a Chainguard Library dependency, verify authenticity and integrity using the Sigstore bundle.

Let's get started!
"

###############################################################################
# Setup
###############################################################################
banner "Setup"
if [[ $(docker ps -a | awk '/python-lib-example/' | awk '{print $1}') ]]; then
  docker stop $(docker ps -a | awk '/python-lib-example/' | awk '{print $1}')
  docker rm $(docker ps -a | awk '/python-lib-example/' | awk '{print $1}')
fi
read -p "Enter your Chainguard organization name (e.g. myorg.com): " ORG_NAME
export ORG_NAME

###############################################################################
# Step 1: Baseline Build (Upstream Python + PyPI)
###############################################################################
banner "Step 1: Build and run using upstream Python and PyPI"

pei "# Let's look at requirements.txt:"
pe "cat requirements.txt"
pei ""

p "# Let's take a look at the Dockerfile:"
pei 'cat Dockerfile'
pei ""

pei "TAG=\"upstream\""

pei "# Build the image"
pe "docker build --no-cache \
  -t python-lib-example:\$TAG ."

p "# Run the container and test it."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'

pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Copy the venv for scanning:"
pei 'docker cp python-lib-example:/app/venv .'

p "# Analyze venv — no dependencies coming from Chainguard:"
pei 'chainctl libraries verify venv'

p "# Cleanup: stop the container and remove the local venv."
pei 'docker stop python-lib-example && docker rm python-lib-example && rm -rf venv'

###############################################################################
# Step 2: Chainguard Libraries Build (with Upstream Python images)
###############################################################################
banner "Step 2: Build with Chainguard Libraries and upstream Python images"
cd ../step2-cg-build
p "# Mint a short-lived token from the current chainctl session, scoped to the org."

pei 'CGR_TOKEN=$(chainctl auth token --audience=libraries.cgr.dev --scope "${ORG_NAME}")'

pei "# Create a .netrc file for the Chainguard Python repo. The registry ignores the login when the password is a session token."

pe "printf 'machine libraries.cgr.dev\n  login _token\n  password %s\n' \"\$CGR_TOKEN\" > ../.netrc"

pei "# Inspect the .netrc file: "
pe "cut -c -80 ../.netrc"

pei "TAG=\"upstream-cg-libs\""

pe "# Compared with step 1, the Dockerfile mounts .netrc as a build secret and sets UV_DEFAULT_INDEX so the Chainguard repo is the only index, with no PyPI fallback:"
pei 'git diff --no-index -U1000 ../step1-orig/Dockerfile Dockerfile'
pei ""

pe "# Build using .netrc as a BuildKit secret"
pei "docker build --no-cache \
  --secret id=netrc,src=../.netrc  \
  -t python-lib-example:\$TAG \
  -f Dockerfile ."

p "# Run and test the container."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'
pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Copy the venv for scanning:"
pei 'docker cp python-lib-example:/app/venv .'

p "# Analyze the container — dependencies now covered by Chainguard:"
pei 'chainctl libraries verify -d venv'

p "# Cleanup: stop the container and remove the image."
pei 'docker stop python-lib-example && docker rm python-lib-example && rm -rf venv'

###############################################################################
# Step 3: Full Chainguard Build (Image + Libraries)
###############################################################################
banner "Step 3: Full Chainguard Build (Chainguard Python images + Chainguard Libraries)"
cd ../step3-cg-all
pei "TAG=\"chainguard-cg-libs\""

pei "# Compared with step 2, the Chainguard python-dev image already includes uv, and the app runs as the image's unprivileged user:"
pei 'git diff --no-index -U1000 ../step2-cg-build/Dockerfile Dockerfile'
pei ""

pe "# Build the image:"
pei "docker build --no-cache \
  --secret id=netrc,src=../.netrc \
  -t python-lib-example:\$TAG \
  -f Dockerfile ."

p "# Run and test the container."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'
pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Copy the venv for scanning:"
pei 'docker cp python-lib-example:/app/venv .'

p "# Analyze the container — full Chainguard coverage:"
pei 'chainctl libraries verify -d venv'

banner "Step 4: View Flask SBOM"
pei "# Each Chainguard-built dependency includes an SBOM under dist-info/sboms/."
pei "# chainctl libraries verify uses the SBOM to confirm packages were built by Chainguard. Let's inspect the Flask SBOM:"
pe "jq '{spdxVersion, dataLicense, SPDXID, name, documentNamespace, creationInfo, packages: [.packages[0]]}' venv/lib/python3.14/site-packages/flask-3.0.2.dist-info/sboms/sbom.spdx.json | jq ."
pei ""

banner "Step 5: Verify Authenticity with Sigstore Bundle"
pei "# A Sigstore bundle is a self‑contained JSON file that packages everything needed to verify the authenticity and integrity of a signed artifact."
pe "# Download the Flask wheel - note, this demo is being run on a Mac and we do not currently produce wheels for Mac, so we are forcing the download of a Linux wheel."
pe "NETRC=../.netrc pip3 download --only-binary=:all: --no-deps --platform manylinux_2_39_x86_64 --implementation cp --python-version 313 --abi cp313 --index-url https://libraries.cgr.dev/python/simple/ flask==3.0.2"
pe "# Download the corresponding sigstore bundle"
pe "curl -L --netrc-file ../.netrc -O https://libraries.cgr.dev/python/integrity/flask/3.0.2/flask-3.0.2-py3-none-any.whl/bundle.json"
pe "# Verify with cosign verify-blob command"
pe $'cosign verify-blob flask-3.0.2-py3-none-any.whl --bundle bundle.json --certificate-oidc-issuer="https://issuer.enforce.dev" --certificate-identity-regexp="^https://issuer\\.enforce\\.dev/.*$"'

p "# Cleanup: stop the container and remove the image."
pei 'docker stop python-lib-example && docker rm python-lib-example && rm -rf venv'

###############################################################################
# Final Cleanup
###############################################################################
banner "Final cleanup: delete .netrc"
p "# The token expires with the chainctl session, so there is nothing to revoke."
pei 'rm -f ../.netrc flask-*.whl bundle.json'

p "# Demo complete!"
exit 0
