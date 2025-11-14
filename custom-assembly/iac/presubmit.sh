#!/bin/bash

set -euo pipefail

org_name="${1:?Must provide organization name as the first argument.}"

tmp_dir=$(mktemp -d)
trap "rm -rf ${tmp_dir}" EXIT

# Download the APKINDEX for the private repository. We use this to check if
# packages in the yaml files exist in the private APK repository.
apk_repo="https://apk.cgr.dev/${org_name}"
apk_token=$(chainctl auth token --audience apk.cgr.dev)
apk_index="${tmp_dir}/APKINDEX"
for arch in x86_64 amd64; do
  echo "${apk_repo}: downloading the APKINDEX for ${arch}" >&2
  curl \
    -sSf \
    -u "_token:${apk_token}" \
    "${apk_repo}/${arch}/APKINDEX.tar.gz" \
    2>/dev/null \
    | tar -xOz \
    >> "${apk_index}"
done

# Validate each yaml file
while read -r f; do
  repo="${f#images/}"
  repo="${repo%.yaml}"
  repo="${repo%.yml}"

  # The file should define a source image from which the custom image is derived
  src=$(yq '.source // ""' "${f}")
  if [[ -z "${src}" ]]; then
    echo "${repo}: ERROR: file does not define a 'source'" >&2
    exit 1
  fi

  # If the repository exists, ensure the repository is configured for custom assembly
  if [[ -n $(chainctl image repo list --parent="${org_name}" --repo="${repo}" -o id) ]]; then
    echo "${repo}: checking the repository is enabled for custom assembly." >&2
    chainctl image repo list --parent=${org_name} -o json \
      | jq --arg repo "${repo}" -e \
        '.items[] | select(.name == $repo) | .sync_config.apkoOverlay != null' \
        >/dev/null \
        || (echo "${repo}: ERROR: not a custom assembly enabled repository" >&2; exit 1)
  fi

  # Check that every package defined in the yaml file exists in the private APK
  # repository
  echo "${repo}: validating package list" >&2
  while read -r package; do
    echo "${repo}: checking package '${package}' is in ${apk_repo}" >&2
    grep -q "^P:${package}$" "${apk_index}" || (echo "${repo}: ERROR: package '${package}' not found in ${apk_repo}" >&2; exit 1)
  done < <(yq '.custom_overlay.contents.packages[]' "${f}")
done < <(find images -type f -name '*.yaml' -o -name '*.yml')
