#! env bash
. ../../base.sh

clear
banner "Exercise 4.1: Sign and verify your own image"

$BATCAT Dockerfile

# Interactive — generates cosign.key and cosign.pub in the current directory
pe "COSIGN_PASSWORD=\"\" cosign generate-key-pair"

pe "docker build . -t ttl.sh/cg-workshop-${USER}:1h"
pe "docker push ttl.sh/cg-workshop-${USER}:1h"

pe "IMAGE=\$(crane digest ttl.sh/cg-workshop-${USER}:1h)"
IMAGE=$(crane digest ttl.sh/cg-workshop-${USER}:1h)

pe "cosign sign --key cosign.key -y ttl.sh/cg-workshop-${USER}@${IMAGE}"
pe "cosign verify --key cosign.pub ttl.sh/cg-workshop-${USER}@${IMAGE}"

wait

banner "Exercise 4.2: Generate and scan an SBOM"

pe "syft cgr.dev/chainguard/python:latest"
pe "syft cgr.dev/chainguard/python:latest -o spdx-json > sbom.json"
pe "jq '.packages | length' sbom.json"
pe "jq '.packages[].name' sbom.json"
