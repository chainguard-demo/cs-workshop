#!/usr/bin/env bash
# Walk through migrating Postgres to the Chainguard postgres image.
# Unlike the app components, Postgres has no in-repo Dockerfile to rebuild;
# the migration is a simple `kubectl set image` against the StatefulSet.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
if [[ "$(pwd -P)" != "${SCRIPT_DIR}" ]]; then
  echo "ERROR: run this demo from its own directory (cd ${SCRIPT_DIR})" >&2
  exit 1
fi
# shellcheck disable=SC1091
. ../../../base.sh

ORG="${ORG:-cs-ttt-demo.dev}"
UPSTREAM_IMAGE="postgres:16.12-alpine"

clear
banner "Postgres is currently running an older upstream tag."
pe "kubectl -n taskboard get statefulset postgres -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"

banner "Ask Chainguard which postgres-16 patch tags are currently supported (non-dev, MAJOR.MINOR only)."
pe "chainctl image repo list --parent=${ORG} --repo=postgres -o json | jq -r '.items[].activeTags[]?' | grep -E '^16.*' | sort -V"

banner "Pick the newest patch. We could also just upgrade upstream (e.g. postgres:16.14-alpine) — same shape of operation. Here we go straight to Chainguard at the matching patch level."
pe "CG_TAG=\$(chainctl image repo list --parent=${ORG} --repo=postgres -o json | jq -r '.items[].activeTags[]?' | grep -E '^16\.[0-9]+\$' | sort -V | tail -1)"
pe "echo \${CG_TAG}"

banner "Capture the immutable digest so the deployment doesn't drift when the tag is later rebuilt."
pe "DIGEST=\$(crane digest cgr.dev/${ORG}/postgres:\${CG_TAG})"
pe "echo \${DIGEST}"

banner "Mirror the image into our internal registry — workloads pull from there, not cgr.dev. The digest is preserved end-to-end."
pe "crane copy --insecure cgr.dev/${ORG}/postgres:\${CG_TAG}@\${DIGEST} registry.localhost:5000/taskboard-postgres:\${CG_TAG}"
pe "NEW_IMAGE=\"registry.localhost:5000/taskboard-postgres:\${CG_TAG}@\${DIGEST}\""
pe "echo \${NEW_IMAGE}"

banner "Migrate the StatefulSet to the digest-pinned mirrored image."
pe "kubectl -n taskboard set image statefulset/postgres postgres=\${NEW_IMAGE}"
pe "kubectl -n taskboard rollout status statefulset/postgres --timeout=3m"
pe "kubectl -n taskboard get pod postgres-0"

banner "Check data persisted."
pe "curl -ksS https://taskboard.localhost/api/tasks | jq -c '.[] | {id, title, done}'"

banner "Force trivy to re-scan the StatefulSet and wait for its report."
pe "../../scripts/force-rescan.sh -n taskboard postgres"
