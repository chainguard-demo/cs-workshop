#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
if [[ "$(pwd -P)" != "${SCRIPT_DIR}" ]]; then
  echo "ERROR: run this demo from its own directory (cd ${SCRIPT_DIR})" >&2
  exit 1
fi
# shellcheck disable=SC1091
. ../../../base.sh

ORG="${ORG:-cs-ttt-demo.dev}"
REGISTRY="registry.localhost:5000"
ATTEMPT1_IMAGE="${REGISTRY}/taskboard-backend:attempt1"
ATTEMPT2_IMAGE="${REGISTRY}/taskboard-backend:chainguard"

# Drop any tags left over from a previous run of this demo so each build below
# starts from the (cached) layers populated by scripts/build-images.sh rather
# than from a stale tagged image.
docker rmi -f "${ATTEMPT1_IMAGE}" "${ATTEMPT2_IMAGE}" >/dev/null 2>&1 || true

clear
banner "Here's the existing Dockerfile."
pe "${BATCAT} 0.Dockerfile"

banner "Which is running in the cluster now."
pe "kubectl -n taskboard get pods -l app=taskboard-backend"

banner "And serving the API as expected."
pe "curl -ksS https://taskboard.localhost/api/tasks | jq -c '.[] | {id, title, done}'"

banner "Migrate to Chainguard — multi-stage, node-dev for build, node (non-dev) for runtime."
pe "git diff --no-index -U10000 0.Dockerfile 1.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 1.Dockerfile -t ${ATTEMPT1_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-backend backend=${ATTEMPT1_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-backend --timeout=2m"
pe "kubectl -n taskboard get pods -l app=taskboard-backend"

banner "Pod is up. But notice how long it takes to terminate one."
pe "time kubectl -n taskboard delete --wait=true \$(kubectl -n taskboard get pods -l app=taskboard-backend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "The node process isn't handling SIGTERM. The node image ships with dumb-init for exactly this reason."
pe "git diff --no-index -U10000 1.Dockerfile 2.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 2.Dockerfile -t ${ATTEMPT2_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-backend backend=${ATTEMPT2_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-backend --timeout=2m"
pe "kubectl -n taskboard get pods -l app=taskboard-backend"

banner "Now time the same delete with dumb-init as PID 1."
pe "time kubectl -n taskboard delete --wait=true \$(kubectl -n taskboard get pods -l app=taskboard-backend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "And confirm the API still serves the same rows."
pe "curl -ksS https://taskboard.localhost/api/tasks | jq -c '.[] | {id, title, done}'"

banner "Force trivy to re-scan the new ReplicaSet and wait for its report."
pe "../../scripts/force-rescan.sh -n taskboard taskboard-backend"
