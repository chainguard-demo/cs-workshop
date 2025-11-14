#!/bin/bash

set -euo pipefail

org_name="${1:?Must provide organization name as the first argument.}"

tmp_dir=$(mktemp -d)
trap "rm -rf ${tmp_dir}" EXIT

# Apply each yaml file
while read -r f; do
  repo="${f#images/}"
  repo="${repo%.yaml}"
  repo="${repo%.yml}"

  # Extract the custom overlay from the file
  custom_overlay="${tmp_dir}/${repo}.yaml"
  yq '.custom_overlay' "${f}" > "${tmp_dir}/${repo}.yaml"

  flags=(
    --yes
    --parent="${org_name}"
    -f "${custom_overlay}"
  )
  echo "${f}: checking if repo exists..." >&2
  if [[ -z $(chainctl image repo list --parent="${org_name}" --repo="${repo}" -o id) ]]; then
    # If the repo doesn't exist, then we can use the --save-as functionality to
    # create it from the 'source'
    echo "${f}: repo doesn't exist, creating it with --save-as..." >&2
    source=$(yq '.source' "${f}")
    flags+=(--repo="${source}")
    flags+=(--save-as="${repo}")
  else
    flags+=(--repo="${repo}")
  fi

  echo "${f}: applying..." >&2
  chainctl image repo build apply ${flags[@]}
done < <(find images -type f -name '*.yaml' -o -name '*.yml')
