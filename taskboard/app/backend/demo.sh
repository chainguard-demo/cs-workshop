#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
if [[ "$(pwd -P)" != "${SCRIPT_DIR}" ]]; then
  echo "ERROR: run this demo from its own directory (cd ${SCRIPT_DIR})" >&2
  exit 1
fi
# shellcheck disable=SC1091
. ../../../base.sh

ORG="${ORG:-cs-ttt-demo.dev}"
REGISTRY="registry.localhost:5000/taskboard-backend"
ATTEMPT1_IMAGE="${REGISTRY}:1"
ATTEMPT2_IMAGE="${REGISTRY}:2"

# Drop any tags left over from a previous run of this demo so each build below
# starts from the (cached) layers populated by scripts/build-images.sh rather
# than from a stale tagged image.
docker rmi -f "${ATTEMPT1_IMAGE}" "${ATTEMPT2_IMAGE}" >/dev/null 2>&1 || true

clear
banner "Here's the existing Dockerfile."
pe "${BATCAT} 0.Dockerfile"

banner "This is currently running and serving the API as expected."
pe "curl -ksS https://taskboard.localhost/api/tasks | jq -c '.[] | {id, title, done}'"

banner "Migrate to Chainguard — multi-stage, node-dev for build, node (non-dev) for runtime."
pe "git diff --no-index -U10000 0.Dockerfile 1.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 1.Dockerfile -t ${ATTEMPT1_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-backend backend=${ATTEMPT1_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-backend --timeout=2m"
pe "kubectl -n taskboard get pods -l app=taskboard-backend"

banner "Let's see if the API is still working."
pe "curl -ksS https://taskboard.localhost/api/tasks | jq -c '.[] | {id, title, done}'"

banner "We always seem to catch the old pod in a Terminating state. How long does it take to terminate a pod?"
pe "time kubectl -n taskboard delete --wait=true \$(kubectl -n taskboard get pods -l app=taskboard-backend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "The entrypoint is 'node', which becomes PID 1 in the container but 'node' doesn't handle SIGTERM."
pe "docker inspect --format '{{json .Config.Entrypoint}}' ${ATTEMPT1_IMAGE}"
pe "kubectl -n taskboard wait --for=condition=Ready pod -l app=taskboard-backend --timeout=60s && kubectl -n taskboard debug -it \$(kubectl -n taskboard get pods -l app=taskboard-backend --field-selector=status.phase=Running -o name | head -1) --image=cgr.dev/chainguard/busybox --target=backend -- ps -ef"

banner "The node image ships with dumb-init for exactly this reason."
pe "git diff --no-index -U10000 1.Dockerfile 2.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 2.Dockerfile -t ${ATTEMPT2_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-backend backend=${ATTEMPT2_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-backend --timeout=2m"
pe "kubectl -n taskboard get pods -l app=taskboard-backend"

banner "Inspect the new entrypoint — dumb-init is PID 1 and reaps/forwards signals to node."
pe "docker inspect --format '{{json .Config.Entrypoint}}' ${ATTEMPT2_IMAGE}"

banner "Confirm it inside the pod — dumb-init is PID 1 with node as its child."
pe "kubectl -n taskboard wait --for=condition=Ready pod -l app=taskboard-backend --timeout=60s && kubectl -n taskboard debug -it \$(kubectl -n taskboard get pods -l app=taskboard-backend --field-selector=status.phase=Running -o name | head -1) --image=cgr.dev/chainguard/busybox --target=backend -- ps -ef"

banner "Now time the same delete with dumb-init as PID 1."
pe "time kubectl -n taskboard delete --wait=true \$(kubectl -n taskboard get pods -l app=taskboard-backend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "Wait for the replacement pod to be Ready, then confirm the API still serves the same rows."
pe "kubectl -n taskboard wait --for=condition=Ready pod -l app=taskboard-backend --timeout=60s"
pe "curl -ksS https://taskboard.localhost/api/tasks | jq -c '.[] | {id, title, done}'"

banner "Force trivy to re-scan the new ReplicaSet and wait for its report."
pe "../../scripts/force-rescan.sh -n taskboard taskboard-backend"
