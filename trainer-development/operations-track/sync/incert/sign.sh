#!/usr/bin/env bash
# Example from https://edu.chainguard.dev/chainguard/chainguard-images/features/incert-custom-certs

incert -ca-certs-file selfsigned.pem -platform linux/arm64 -image-url $1 -dest-image-url $2

