#!/usr/bin/env bash
# Tear down the demo. Deletes the k3d cluster + the local registry.

set -euo pipefail

CLUSTER_NAME="taskboard"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  log "deleting k3d cluster '${CLUSTER_NAME}'"
  k3d cluster delete "${CLUSTER_NAME}"
else
  log "no k3d cluster '${CLUSTER_NAME}' found"
fi

if k3d registry list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx 'k3d-registry.localhost'; then
  log "deleting k3d registry 'registry.localhost'"
  k3d registry delete registry.localhost
fi

log "done."
