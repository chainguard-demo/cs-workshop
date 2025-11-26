#! env bash

. ../../base.sh

: "${ORGANIZATION:=cs-ttt-demo.dev}"

clear

banner "Chainguard continually rebuilds the latest version for each supported release track."
pe "chainctl package versions list python --show-active"
pe "chainctl image list --parent=${ORGANIZATION} --repo=python --updated-within=72h -o table"

banner "Therefore, the tags we produce are highly mutable. Even for very specific tags."
pe "chainctl image history --parent=${ORGANIZATION} python:3.13.3-r2"
pe "DIGEST_NEW=\$(chainctl image history --parent=${ORGANIZATION} python:3.13.3-r2 -o json | jq -r '.[0].digest')"
pe "DIGEST_OLD=\$(chainctl image history --parent=${ORGANIZATION} python:3.13.3-r2 -o json | jq -r '.[1].digest')"
pe "chainctl image diff cgr.dev/${ORGANIZATION}/python@\${DIGEST_OLD} cgr.dev/${ORGANIZATION}/python@\${DIGEST_NEW} | jq -r ."

banner "The digest is the sha256 checksum of the manifest/index."
pe "crane manifest cgr.dev/${ORGANIZATION}/python:3.13.3-r2 | jq -r ."
pe "crane manifest --platform=linux/amd64 cgr.dev/${ORGANIZATION}/python:3.13.3-r2 | jq -r ."
pe "crane manifest cgr.dev/${ORGANIZATION}/python:3.13.3-r2 | sha256sum"

banner "You can see the digest when you pull an image."
pe "docker pull cgr.dev/${ORGANIZATION}/python:3.13.3-r2"

banner "You can use the digest to pull a specific image. You can include a tag to indicate the version it provides."
pe "docker pull cgr.dev/${ORGANIZATION}/python:3.13@$(crane digest cgr.dev/${ORGANIZATION}/python:3.13.3-r2)"

banner "But it's worth noting that the tag is purely informational here."
pe "docker pull cgr.dev/${ORGANIZATION}/python:carrot@$(crane digest cgr.dev/${ORGANIZATION}/python:3.13.3-r2)"
