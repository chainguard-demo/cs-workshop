#! env bash
. ../../base.sh

# A local zot registry stands in for a real one; unlike distribution it implements the
# OCI referrers API. Reuse the container if a previous run left it behind, otherwise
# start a fresh one bound to loopback.
REGISTRY="localhost:5000"
IMAGE="${REGISTRY}/cg-workshop"

clear
banner "Exercise 4.1: Sign and verify your own image"

$BATCAT Dockerfile

# Interactive — generates cosign.key and cosign.pub in the current directory
pe "COSIGN_PASSWORD=\"\" cosign generate-key-pair"

pe "docker start zot 2>/dev/null || docker run -d --name zot -p 5000:5000 ghcr.io/project-zot/zot:latest"

pe "docker build . -t ${IMAGE}:latest"
pe "docker push ${IMAGE}:latest"

pe "DIGEST=\$(crane digest ${IMAGE}:latest)"

pe "cosign sign --key cosign.key -y ${IMAGE}@\${DIGEST}"
pe "cosign verify --key cosign.pub ${IMAGE}@\${DIGEST}"

# The signature is a separate artifact that refers to the image; no new tag appears
pe "crane ls ${IMAGE}"

# It is an OCI referrer. zot serves the referrers API as an index keyed by the image digest,
# which is what oras discover reads.
pe "curl -s http://${REGISTRY}/v2/cg-workshop/referrers/\${DIGEST} | jq '{mediaType, referrers: [.manifests[] | {artifactType, digest}]}'"
pe "oras discover ${IMAGE}@\${DIGEST}"

wait

banner "Exercise 4.2: Attach an SBOM to the image as an attestation"

# Generate from the pushed digest, not the local tag, so the SBOM describes exactly what was signed
pe "syft ${IMAGE}@\${DIGEST} -o spdx-json > sbom.spdx.json"
pe "jq '{spdxVersion, name, packages: (.packages | length)}' sbom.spdx.json"

# cosign wraps the SBOM in an in-toto statement whose subject is the image digest, signs it, and pushes it next to the image
pe "cosign attest --key cosign.key -y --type spdxjson --predicate sbom.spdx.json ${IMAGE}@\${DIGEST}"

# A second referrer has appeared alongside the signature
pe "oras discover ${IMAGE}@\${DIGEST}"
# Each referrer is a Sigstore bundle wrapping a DSSE envelope; the in-toto statement inside names the image digest as its subject
pe "for ref in \$(oras discover --format json ${IMAGE}@\${DIGEST} | jq -r '.manifests[].digest'); do oras blob fetch --output - ${IMAGE}@\$(oras manifest fetch ${IMAGE}@\$ref | jq -r '.layers[0].digest') | jq -c '.dsseEnvelope.payload | @base64d | fromjson | {predicateType, subject: .subject[0].digest.sha256}'; done"

# Verification returns the signed envelope; the SBOM is the base64 payload inside it
pe "cosign verify-attestation --key cosign.pub --type spdxjson ${IMAGE}@\${DIGEST} > attestation.json"
pe "jq -r '.payload | @base64d | fromjson | {predicateType, subject: .subject[0].digest.sha256, packages: (.predicate.packages | length)}' attestation.json"
pe "jq -r '.payload | @base64d | fromjson | .predicate.packages[] | [.name, .versionInfo] | @tsv' attestation.json | column -t"

# Scan the attested SBOM rather than re-inspecting the image
pe "grype sbom:sbom.spdx.json"
