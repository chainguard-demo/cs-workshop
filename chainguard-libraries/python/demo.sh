#! env bash

###############################################################################
# Demo Magic Script: Python Libraries Workshop
###############################################################################

# Load demo-magic
. ../../base.sh

pei cd step1-orig/

TYPE_SPEED=100
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

###############################################################################
# Intro
###############################################################################
echo -e "
Demo: Converting a Python App to Use Chainguard Libraries

This demo walks through rebuilding an existing Python Flask app using Chainguard Libraries,
transitioning from PyPI dependencies to Chainguard's trusted library source — without changing
source code or build process.

Stages:
1. Baseline Build: Build with upstream Python and PyPI.
2. Chainguard Libraries: Same upstream images, but dependencies from Chainguard Libraries.
3. Full Chainguard: Chainguard Python images + Chainguard Libraries.
4. Provenance: Inspect the SBOM for a Chainguard Library dependency.

Let's get started!
"
wait

###############################################################################
# Setup
###############################################################################
banner "# Setting up environment variables."
pei "ECOSYSTEM=\"python\""
pei "TOKEN_NAME=\"python-libraries-workshop-token-$USER\""
pei "TTL=\"1h\""
pei ""
pei ""

read -p "Enter your Chainguard organization name (e.g. myorg.com): " ORG_NAME
export ORG_NAME

###############################################################################
# Step 1: Baseline Build (Upstream Python + PyPI)
###############################################################################
banner "Step 1: Build and run using upstream Python and PyPI"

pei "# Let's look at requirements.txt:"
pe "cat  requirements.txt"
pei ""

p "# Let's take a look at the Dockerfile:"
pei 'cat Dockerfile'
pei ""

pei "TAG=\"upstream\""

pei "# Build the image"
pei "docker build --no-cache \
  -t python-lib-example:\$TAG ."

p "# Run the container and test it."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'

pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

#p "# Copy the venv for scanning:"
#pei 'docker cp python-lib-example:/app/venv .'

p "# Analyze the container — no dependencies coming from Chainguard:"
pei 'chainctl libraries verify python-lib-example:$TAG'

p "# Cleanup: stop the container and remove the local venv."
pei 'docker stop python-lib-example && docker rm python-lib-example'

###############################################################################
# Step 2: Chainguard Libraries Build (with Upstream Python images)
###############################################################################
banner "Step 2: Build with Chainguard Libraries and upstream Python images"

p "# Create a pull token for the Python ecosystem."
pei 'CREDS_OUTPUT=$(chainctl auth pull-token --repository="${ECOSYSTEM}" --parent="${ORG_NAME}" --name="${TOKEN_NAME}" --ttl="${TTL}" -o json)'

pei 'export CGR_USER=$(echo $CREDS_OUTPUT | jq -r ".identity_id")'
pei 'export CGR_TOKEN=$(echo $CREDS_OUTPUT | jq -r ".token")'

pei "# Create a .netrc file with credentials for the Chainguard Python repo."

{
  echo "machine libraries.cgr.dev"
  echo "  login ${CGR_USER}"
  echo "  password ${CGR_TOKEN}"
} > .netrc

pei "TAG=\"upstream-cg-libs\""

pe "# The Dockerfile mounts .netrc as a build secret and sets UV_INDEX_URL/UV_EXTRA_INDEX_URL to prioritize the Chainguard repo, falling back to PyPI:"
pei 'cat ../step2-cg-build/Dockerfile'
pei ""

pe "# Build using .netrc as a BuildKit secret"
pei "docker build --no-cache \
  --secret id=netrc,src=.netrc  \
  -t python-lib-example:\$TAG \
  -f ../step2-cg-build/Dockerfile ."

p "# Run and test the container."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'
pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Analyze the container — dependencies now covered by Chainguard:"
pei 'chainctl libraries verify python-lib-example:$TAG'

p "# Cleanup: stop the container and remove the image."
pei 'docker stop python-lib-example && docker rm python-lib-example'

###############################################################################
# Step 3: Full Chainguard Build (Image + Libraries)
###############################################################################
banner "Step 3: Full Chainguard Build (Chainguard Python images + Chainguard Libraries)"

pei "TAG=\"chainguard-cg-libs\""

pei "# The Chainguard python-dev image already includes uv — let's look at the Dockerfile:"
pei 'cat ../step3-cg-all/Dockerfile'
pei ""

pe "# Build the image:"
pei "docker build --no-cache \
  --secret id=netrc,src=.netrc \
  -t python-lib-example:\$TAG \
  -f ../step3-cg-all/Dockerfile ."

p "# Run and test the container."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'
pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Analyze the container — full Chainguard coverage:"
pei 'chainctl libraries verify python-lib-example:$TAG'

banner "Step 4: View Python Library Provenance"
pei "# Each Chainguard-built dependency includes an SBOM under dist-info/sboms/."
pei "# chainctl libraries verify uses the SBOM to confirm packages were built by Chainguard. Let's inspect the Flask SBOM:"
pe "jq '{spdxVersion, dataLicense, SPDXID, name, documentNamespace, creationInfo, packages: [.packages[0]]}' venv/lib/python3.14/site-packages/flask-3.0.2.dist-info/sboms/sbom.spdx.json | jq ."
pei ""

p "# Cleanup: stop the container and remove the image."
pei 'docker stop python-lib-example && docker rm python-lib-example'

###############################################################################
# Final Cleanup
###############################################################################
banner "Final cleanup: delete .netrc and revoke the Chainguard pull token"
pei "ID=\$(chainctl iam ids ls --parent=\"\${ORG_NAME}\" -o json | jq -r --arg name \"\${TOKEN_NAME}\" '.items[] | select(.name | startswith(\$name)) | .id')"
pei 'chainctl iam identities delete "$ID" --parent "$ORG_NAME" --yes'
pei 'rm .netrc'

p "# Demo complete!"
exit 0
