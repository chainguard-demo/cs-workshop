#!/bin/bash

ORG="cs-ttt-demo.dev"
UPSTREAM_REGISTRY="cgr.dev/${ORG}/"
DOWNSTREAM_REGISTRY="localhost:80/library/"

requirements=(cosign chainctl jq)
for requirement in "${requirements[@]}"; do
    if ! command -v $requirement &> /dev/null
    then
        echo "$requirement could not be found in \$PATH, please install it."
        exit 1
    fi
done

# Images will be signed by either the CATALOG_SYNCER or APKO_BUILDER identity in your organization.
CATALOG_SYNCER=$(chainctl iam account-associations describe $ORG -o json | jq -r '.[].chainguard.service_bindings.CATALOG_SYNCER')
APKO_BUILDER=$(chainctl iam account-associations describe $ORG -o json | jq -r '.[].chainguard.service_bindings.APKO_BUILDER')

verify_signature() {
    echo "Verifying attestation for $UPSTREAM_REGISTRY$image"
    cosign verify \
        --certificate-oidc-issuer=https://issuer.enforce.dev \
        --certificate-identity-regexp="https://issuer.enforce.dev/(${CATALOG_SYNCER}|${APKO_BUILDER})" \
    $UPSTREAM_REGISTRY/$image -o text
}

echo "Processing ${#images[@]} images from $IMAGE_LIST"

images=($(crane catalog cgr.dev | grep $ORG | cut -f 2 -d '/'))

for image in "${images[@]}"; do
    image="$image:latest"
    verify_signature
        if [ $? -eq 0 ]; then
          cosign copy $UPSTREAM_REGISTRY$image $DOWNSTREAM_REGISTRY$image
        else
            echo "!!!!!!!!!! Image $image failed signature verification, not copying to $DOWNSTREAM_REGISTRY !!!!!!!!!!"
        fi
done
