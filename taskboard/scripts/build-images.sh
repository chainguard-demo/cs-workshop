#!/usr/bin/env bash
# Build the baseline taskboard images and warm the host's docker layer cache
# for every other Dockerfile iteration that the per-component demos will
# rebuild interactively.
#
# Outputs:
#   - registry.localhost:5000/taskboard-backend:0  (pushed; what bootstrap deploys)
#   - registry.localhost:5000/taskboard-frontend:0 (pushed; what bootstrap deploys)
#   - cached layers for every other N.Dockerfile (untagged — demos pay no
#     cold-build cost when they re-run `docker build`)
#   - .images.env with BACKEND_IMAGE / FRONTEND_IMAGE pointing at the :0 tags

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REGISTRY="registry.localhost:5000"
ORG="${ORG:-cs-ttt-demo.dev}"

# All logs + docker output go to stderr; the env file is the only stdout.
log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }

build_component() {
  local component="$1"
  local context="${REPO_ROOT}/app/${component}"
  local baseline="${REGISTRY}/taskboard-${component}:0"

  for dockerfile in "${context}"/*.Dockerfile; do
    local n
    n="$(basename "${dockerfile}" .Dockerfile)"

    if [[ "${n}" == "0" ]]; then
      log "building + pushing ${baseline} (${component}/0.Dockerfile)"
      docker build \
        --build-arg "ORG=${ORG}" \
        --file "${dockerfile}" \
        --tag "${baseline}" \
        "${context}" >&2
      docker push "${baseline}" >&2
    else
      log "warming cache: ${component}/${n}.Dockerfile"
      docker build \
        --build-arg "ORG=${ORG}" \
        --file "${dockerfile}" \
        "${context}" >&2
    fi
  done
}

build_component backend
build_component frontend

cat > "${REPO_ROOT}/.images.env" <<EOF
BACKEND_IMAGE=${REGISTRY}/taskboard-backend:0
FRONTEND_IMAGE=${REGISTRY}/taskboard-frontend:0
EOF

log "wrote ${REPO_ROOT}/.images.env"
cat "${REPO_ROOT}/.images.env" >&2
