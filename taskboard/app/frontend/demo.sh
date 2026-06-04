#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
if [[ "$(pwd -P)" != "${SCRIPT_DIR}" ]]; then
  echo "ERROR: run this demo from its own directory (cd ${SCRIPT_DIR})" >&2
  exit 1
fi
# shellcheck disable=SC1091
. ../../../base.sh

ORG="${ORG:-cs-ttt-demo.dev}"
REGISTRY="registry.localhost:5000/taskboard-frontend"
ATTEMPT1_IMAGE="${REGISTRY}:1"
ATTEMPT2_IMAGE="${REGISTRY}:2"
ATTEMPT3_IMAGE="${REGISTRY}:3"
ATTEMPT4_IMAGE="${REGISTRY}:4"

# Drop any tags left over from a previous run of this demo so each build below
# starts from the (cached) layers populated by scripts/build-images.sh rather
# than from a stale tagged image.
docker rmi -f \
  "${ATTEMPT1_IMAGE}" "${ATTEMPT2_IMAGE}" "${ATTEMPT3_IMAGE}" "${ATTEMPT4_IMAGE}" \
  >/dev/null 2>&1 || true

clear
banner "The existing Dockerfile."
pe "${BATCAT} 0.Dockerfile"

banner "Which is currently running in the cluster."
pe "kubectl -n taskboard get pods -l app=taskboard-frontend"
pe "curl -ksS -o /dev/null -w 'HTTP %{http_code}\\n' https://taskboard.localhost/"

banner "Let's try to migrate it to Chainguard."
pe "git diff --no-index -U10000 0.Dockerfile 1.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 1.Dockerfile -t ${ATTEMPT1_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-frontend frontend=${ATTEMPT1_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=10s || true"
pe "kubectl -n taskboard get pods -l app=taskboard-frontend"
pe "kubectl -n taskboard logs --tail=15 \$(kubectl -n taskboard get pods -l app=taskboard-frontend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "The app defaults LOG_DIR to /var/log/taskboard — root-owned. Point it at /app/logs instead, which the non-root runtime user owns."
pe "git diff --no-index -U10000 1.Dockerfile 2.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 2.Dockerfile -t ${ATTEMPT2_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-frontend frontend=${ATTEMPT2_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=10s || true"
pe "kubectl -n taskboard get pods -l app=taskboard-frontend"
pe "kubectl -n taskboard logs --tail=15 \$(kubectl -n taskboard get pods -l app=taskboard-frontend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "Logging fixed, but serve depends on getconf, which isn't in the production image."
pe "docker run -it --rm -u root --entrypoint sh cgr.dev/${ORG}/node:20-dev -c 'apk search --no-cache cmd:getconf'"

banner "Found it: posix-libc-utils-bin. apk install it via the -dev variant."
pe "git diff --no-index -U10000 2.Dockerfile 3.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 3.Dockerfile -t ${ATTEMPT3_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-frontend frontend=${ATTEMPT3_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=60s"
pe "kubectl -n taskboard get pods -l app=taskboard-frontend"
pe "kubectl -n taskboard logs --tail=15 \$(kubectl -n taskboard get pods -l app=taskboard-frontend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "It works — but the image is still a single-stage build."
pe "docker images ${REGISTRY} --format '{{.Repository}}:{{.Tag}}  {{.Size}}'"

banner "Refactor to multi-stage: build in -dev, ship the production node:20 runtime + just getconf via apk chroot."
pe "git diff --no-index -U10000 3.Dockerfile 4.Dockerfile"
pe "docker build --push --build-arg ORG=${ORG} -f 4.Dockerfile -t ${ATTEMPT4_IMAGE} ."
pe "kubectl -n taskboard set image deploy/taskboard-frontend frontend=${ATTEMPT4_IMAGE}"
pe "kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=2m"
pe "kubectl -n taskboard get pods -l app=taskboard-frontend"
pe "kubectl -n taskboard logs --tail=15 \$(kubectl -n taskboard get pods -l app=taskboard-frontend --sort-by=.metadata.creationTimestamp -o name | tail -1)"

banner "Compare image sizes across iterations."
pe "docker images --format '{{.Repository}}:{{.Tag}}\\t{{.Size}}' | grep '${REGISTRY}' | sort"

banner "Force trivy to re-scan the new ReplicaSet and wait for its report."
pe "../../scripts/force-rescan.sh -n taskboard taskboard-frontend"
