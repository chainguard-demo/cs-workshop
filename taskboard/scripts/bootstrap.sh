#!/usr/bin/env bash

# Bootstrap the Taskboard demo end-to-end:
#   - k3d cluster (with local registry)
#   - ingress-nginx, cert-manager, trivy-operator, kube-prometheus-stack
#   - app images built from upstream Dockerfiles, pushed to local registry
#   - Chainguard images for the demos pre-mirrored into the local registry
#   - app + ingress + grafana ingress deployed
#
# Run a second time to re-apply manifests after editing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLUSTER_NAME="taskboard"
ORG="${ORG:-cs-ttt-demo.dev}"
CLUSTER_YAML="${REPO_ROOT}/cluster.yaml.tmpl"
LOCAL_REGISTRY="registry.localhost:5000"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

require() {
  for cmd in "$@"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "ERROR: required command not found: ${cmd}" >&2
      exit 1
    fi
  done
}

require k3d kubectl helm docker chainctl jq crane

# --- cluster -----------------------------------------------------------------
if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  log "k3d cluster '${CLUSTER_NAME}' already exists — reusing"
else
  log "creating k3d cluster '${CLUSTER_NAME}'"
  k3d cluster create --config "${CLUSTER_YAML}"
fi

kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null

log "waiting for cluster API to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=2m >/dev/null

# --- helm repos --------------------------------------------------------------
log "updating helm repos"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo add aqua https://aquasecurity.github.io/helm-charts/ >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

# --- ingress-nginx -----------------------------------------------------------
log "installing ingress-nginx"
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f "${REPO_ROOT}/deploy/ingress-nginx/values.yaml" \
  --wait --timeout 5m

# --- cert-manager ------------------------------------------------------------
log "installing cert-manager"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  -f "${REPO_ROOT}/deploy/cert-manager/values.yaml" \
  --wait --timeout 5m

log "applying cert-manager ClusterIssuer + CA"
kubectl apply -f "${REPO_ROOT}/deploy/cert-manager/manifests/issuer.yaml"
# Wait for the CA secret so leaf certs can be signed.
kubectl wait --for=condition=Ready certificate/taskboard-ca -n cert-manager --timeout=2m

# --- monitoring stack --------------------------------------------------------
log "installing kube-prometheus-stack (Grafana + Prometheus only)"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f "${REPO_ROOT}/deploy/kube-prometheus-stack/values.yaml" \
  --wait --timeout 10m

# --- trivy operator ----------------------------------------------------------
log "installing trivy-operator"
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system --create-namespace \
  -f "${REPO_ROOT}/deploy/trivy-operator/values.yaml" \
  --wait --timeout 5m

# --- build + push app images ------------------------------------------------
# Build every iteration of the per-component Dockerfiles and push them to the
# local registry. The demos re-run `docker build --push` but pay only the
# manifest cost since the layers are already there.
log "building all taskboard image iterations → ${LOCAL_REGISTRY}"
"${SCRIPT_DIR}/build-images.sh"

# shellcheck disable=SC1091
source "${REPO_ROOT}/.images.env"
export BACKEND_IMAGE FRONTEND_IMAGE

# --- mirror Chainguard postgres into the local registry ---------------------
# The db demo runs `crane copy` against the same tag, but with the blobs
# already pushed here the demo-time copy is just a manifest write.
log "mirroring cgr.dev/${ORG}/postgres:16 → ${LOCAL_REGISTRY}/taskboard-postgres"
crane copy --insecure "cgr.dev/${ORG}/postgres:16" "${LOCAL_REGISTRY}/taskboard-postgres:16" >/dev/null

# --- deploy app --------------------------------------------------------------
log "applying app manifests (BACKEND_IMAGE=${BACKEND_IMAGE})"
kubectl apply -f "${REPO_ROOT}/app/manifests/namespace.yaml"

kubectl apply -f "${REPO_ROOT}/app/db/manifests/postgres.yaml"
# Substitute image refs into the workload manifests at apply time.
sed -e "s|\${BACKEND_IMAGE}|${BACKEND_IMAGE}|g" \
  "${REPO_ROOT}/app/backend/manifests/deployment.yaml" | kubectl apply -f -
sed -e "s|\${FRONTEND_IMAGE}|${FRONTEND_IMAGE}|g" \
  "${REPO_ROOT}/app/frontend/manifests/deployment.yaml" | kubectl apply -f -
kubectl apply -f "${REPO_ROOT}/app/frontend/manifests/ingress.yaml"
kubectl apply -f "${REPO_ROOT}/deploy/kube-prometheus-stack/manifests/ingress.yaml"
kubectl apply -f "${REPO_ROOT}/deploy/kube-prometheus-stack/manifests/dashboard.yaml"

log "waiting for app rollout"
kubectl -n taskboard rollout status statefulset/postgres --timeout=5m
kubectl -n taskboard rollout status deploy/taskboard-backend --timeout=3m
kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=3m

cat <<EOF

\033[1;32mDone.\033[0m

  App:     https://taskboard.localhost
  Grafana: https://grafana.taskboard.localhost   (admin / admin)

The Trivy Operator will scan the running workloads in the background. Reports
appear as VulnerabilityReport CRDs and metrics in the Grafana dashboard
"Trivy Operator Dashboard".

  kubectl get vulnerabilityreports -A
  kubectl get -n taskboard vulnerabilityreports
EOF
