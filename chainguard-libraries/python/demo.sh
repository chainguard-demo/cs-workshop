#! env bash

###############################################################################
# Demo Magic Script: Python Libraries Workshop
# This script uses demo-magic to simulate a live terminal demo.
###############################################################################

# Load demo-magic
. ../../base.sh

pei cd step1-orig/

# Speed (lower = faster). Use -w for waits and ENTER manually if you prefer.
TYPE_SPEED=100
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

###############################################################################
# Intro
###############################################################################
echo -e "
Demo: Converting a Python App to Use Chainguard Libraries

This demo walks through taking an existing sample Python application and rebuilding it using Chainguard Libraries for Python.
We’ll demonstrate how to transition from using upstream PyPI dependencies to Chainguard’s trusted library source — without changing your source code or build process — while gaining improved security and provenance.

To keep everything portable and reproducible, the demo uses containerized builds rather than local python setups. We will also be using uv to install python dependencies since it is faster than pip, and also preserves repo precedence when doing builds with Chainguard Libraries.

The application is a simple Python Flask application that uses the Pillow package to perform basic analysis of an image.

The demo includes three main stages:
1. Baseline Build (Upstream Python & Python Slim Images):
   - Build the python application using upstream python build containers and a python:slim runtime container.
   - This represents a typical python build pipeline that relies on PyPI for dependencies.
   - Verify the application runs successfully, then scan the resulting image to confirm that all dependencies are sourced from PyPI.

2. Chainguard Libraries Migration (Same Upstream Builders):
   - Rebuild the same application using Chainguard Libraries for Python, keeping the same upstream Python and Python Slim containers.
   - Demonstrate that switching dependency sources has no impact on functionality.
   - Re-scan the image to show that dependencies are now covered by Chainguard’s verified library set.

3. Chainguard Build & Runtime Containers:
   - Rebuild and run the application using both Chainguard’s build and runtime container images together with Chainguard Libraries.
   - Perform a final scan to confirm full coverage from Chainguard’s trusted ecosystem and show that the application still functions as expected.

4. Lastly we will look at how to view provenance for Chainguard Libraries for Python. We will look at an SBOM for one of the dependencies and discuss some key attributes.

Let's get started!
"
wait

###############################################################################
# Setup
###############################################################################
banner "# Let's start by setting up our environment variables."
pei "ECOSYSTEM=\"python\""
pei "TOKEN_NAME=\"python-libraries-workshop-token-$USER\""
pei "TTL=\"8760h\""
pei ""
pei ""

read -p "Enter your Chainguard organization name (e.g. myorg.com): " ORG_NAME
export ORG_NAME

###############################################################################
# Step 1: Baseline Build (Upstream Python + PyPI)
###############################################################################
banner "Step 1: Build and run using upstream Python and PyPI - Let's get a baseline by building our app as is, without using Chainguard Libraries"

pei "# We will build a sample Python app using PyPI for dependencies and the upstream python image."
pei "# Lets take a look at the requirements.txt file first, you'll see some standard Flask dependencies and Pillow that are needed for the build:"
pe "cat  requirements.txt"
pei ""

p "# Let's take a look at the dockerfile:"
pei 'cat Dockerfile'
pei ""

p '# Now lets set our builder and runtime image and build the project.'
pei "TAG=\"upstream\""
pei "UPSTREAM_PYTHON_IMAGE=\"python:3.13\""
pei "BUILDER_IMAGE=\"\$UPSTREAM_PYTHON_IMAGE\""
pei "RUNTIME_IMAGE=\"\$UPSTREAM_PYTHON_IMAGE-slim\""

pei "# Build the image"
pei "docker build --no-cache \
  --build-arg BUILDER_IMAGE=\$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=\$RUNTIME_IMAGE \
  -t python-lib-example:\$TAG ."


p "# Run the container and test it by uploading an image, we should get a json response back with some details about the image."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'

pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Copy the venv for scanning to see how many dependencies were pulled from Chainguard:"
pei 'docker cp python-lib-example:/app/venv .'

p "# Analyze the venv with chainver, as you can see no dependencies are coming from Chainguard"
pei 'chainver --parent $ORG_NAME venv'

p "# Cleanup Step - Stop the running container and remove the local venv directory."
pei 'docker stop python-lib-example && docker rm python-lib-example && rm -rf venv'

###############################################################################
# Step 2: Chainguard Libraries Build (with Upstream Python images)
###############################################################################
banner "Step 2: Build with Chainguard Libraries and upstream containers (Upstream Python)"

p "# In order to use Chainguard Libraries for Python to build our app, we will need to create a pull token for the Python ecosystem. Press enter to create your token."
pei 'CREDS_OUTPUT=$(chainctl auth pull-token --library-ecosystem="${ECOSYSTEM}" --parent="${ORG_NAME}" --name="${TOKEN_NAME}" --ttl="${TTL}" -o json)'

pei 'export CGR_USER=$(echo $CREDS_OUTPUT | jq -r ".identity_id")'
pei 'export CGR_TOKEN=$(echo $CREDS_OUTPUT | jq -r ".token")'

pei "# Create a .netrc file to hold the credentials to the Chainguard Python repo."

p "cat > .netrc <<EOF
machine libraries.cgr.dev
  login ${CGR_USER}
  password ${CGR_TOKEN}
EOF"

{
  echo "machine libraries.cgr.dev"
  echo "  login ${CGR_USER}"
  echo "  password ${CGR_TOKEN}"
} > .netrc



pe '# Now lets set our tag, builder and runtime image and build the same app as before but using chainguard libraries.'
pei "TAG=\"upstream-cg-libs\""
pei "BUILDER_IMAGE=\"\$UPSTREAM_PYTHON_IMAGE\""
pei "RUNTIME_IMAGE=\"\$UPSTREAM_PYTHON_IMAGE-slim\""

pe "# Lets take a look at the dockerfile as it is slightly different from before, notice that we will be mounting our .netrc file as a build secret so that the credentials are not stored in the layers or in the builder logs, and we ensure we have removed any local cache so that the dependencies will be fetched from the Chainguard repo. We also set the UV_INDEX_URL and UV_EXTRA_INDEX_URL to point to the Chainguard Python remediated repo as highest precedence followed by the Chainguard python repo and finally falling back to PyPI as the last preferred index to use:"
pei 'cat ../step2-cg-build/Dockerfile'
pei ""

pe "# Build image using .netrc as a BuildKit secret"
pei "docker build --no-cache \
  --build-arg BUILDER_IMAGE=\$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=\$RUNTIME_IMAGE \
  --secret id=netrc,src=.netrc  \
  -t python-lib-example:\$TAG \
  -f ../step2-cg-build/Dockerfile ."

p "# Run the container and test it by uploading an image, we should get a json response back with some details about the image."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'
pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Copy and analyze venv"
pei 'docker cp python-lib-example:/app/venv .'
pei 'chainver --parent $ORG_NAME venv'

p "# Cleanup Step - Stop the running container and remove the local venv directory."
pei 'docker stop python-lib-example && docker rm python-lib-example && rm -rf venv'

###############################################################################
# Step 3: Full Chainguard Build (Image + Libraries)
###############################################################################
banner "Step 3: Full Chainguard Build (Chainguard Python images + Chainguard Libraries for Python)"
pei "# In this step we will use the same app but this time we will build with Chainguard libraries, using the Chainguard python-dev image and python runtime image."

pe '# Now lets set our tag, builder and runtime image and build the same app as before but using chainguard libraries.'
pei "TAG=\"chainguard-cg-libs\""
pei "BUILDER_IMAGE=\"cgr.dev/chainguard/python:latest-dev\""
pei "RUNTIME_IMAGE=\"cgr.dev/chainguard/python:latest\""

pei "# For this build we will use the same .netrc file as before but we tweak the Dockerfile slightly, the Chainguard python image already includes uv (no need to install it):"
pei 'cat ../step3-cg-all/Dockerfile'
pei ""

pe "# Now lets build the image using the Chainguard python images:"
pei "docker build --no-cache \
  --build-arg BUILDER_IMAGE=\$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=\$RUNTIME_IMAGE \
  --secret id=netrc,src=.netrc \
  -t python-lib-example:\$TAG \
  -f ../step3-cg-all/Dockerfile ."

p "# Run the container and test it by uploading an image, we should get a json response back with some details about the image."
pei 'docker run -d -p 5055:5055 --name python-lib-example python-lib-example:$TAG'
pe 'curl -F "file=@linky.png" http://127.0.0.1:5055/upload'

p "# Copy the venv directory from the container locally so we can scan it with chainver."
pei 'docker cp python-lib-example:/app/venv .'
pei 'chainver --parent $ORG_NAME venv'

banner "Step 4: View Python Library Provenance"
pei "# Each Python dependency built by Chainguard is accompanied by an SBOM, the SBOM can be found in the <site-packages>/<package-name>-version.dist-info/sboms directory where the dependency was installed."
pei '# Chainver looks at the sbom to determine if the package was built by Chainguard, you can see the packages.supplier field is Chainguard, Inc and the download location shows the github URL and commit ID of the version that was built. Lets take a look at the first part of the SBOM for the Flask dependency:'
pe "jq '{spdxVersion, dataLicense, SPDXID, name, documentNamespace, creationInfo, packages: [.packages[0]]}' venv/lib/python3.13/site-packages/flask-3.0.2.dist-info/sboms/sbom.spdx.json | jq ."
pei ""

p "# Cleanup: Stop the container and delete the local venv directory."
pei 'docker stop python-lib-example && docker rm python-lib-example && rm -rf venv'

###############################################################################
# Final Cleanup
###############################################################################
banner "Final cleanup delete local .netrc and delete the Chainguard pull token"
pei "ID=\$(chainctl iam ids ls --parent=\"\${ORG_NAME}\" -o json | jq -r --arg name \"\${TOKEN_NAME}\" '.items[] | select(.name | startswith(\$name)) | .id')"
pei 'chainctl iam identities delete "$ID" --parent "$ORG_NAME" --yes'
pei 'rm .netrc'

p "# Demo complete!"
exit 0
