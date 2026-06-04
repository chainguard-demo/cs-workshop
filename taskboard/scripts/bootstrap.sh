#!/usr/bin/env bash
# Bootstrap the Taskboard demo end-to-end:
#   - k3d cluster (with local registry)
#   - ingress-nginx, cert-manager, trivy-operator, kube-prometheus-stack
#   - app images built from upstream Dockerfiles, pushed to local registry
#   - app + ingress + grafana ingress deployed
#
# Run a second time to re-apply manifests after editing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLUSTER_NAME="taskboard"
ORG="${ORG:-cs-ttt-demo.dev}"
CLUSTER_TMPL="${REPO_ROOT}/cluster.yaml.tmpl"
CLUSTER_RENDERED="${REPO_ROOT}/.cluster.yaml"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

require() {
  for cmd in "$@"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "ERROR: required command not found: ${cmd}" >&2
      exit 1
    fi
  done
}

require k3d kubectl helm docker chainctl jq

# --- cgr.dev pull token ------------------------------------------------------
# Mint a fresh 24h pull token in the demo org and render it into the k3d
# cluster config. Every node ends up with /etc/rancher/k3s/registries.yaml
# carrying auth for cgr.dev, so workloads can pull private Chainguard images
# without ImagePullSecrets in every manifest.
log "minting 24h cgr.dev pull token in ${ORG}"
PULL_TOKEN_JSON=$(chainctl auth pull-token create \
  --parent="${ORG}" \
  --ttl=24h \
  --name="e2e-example-bootstrap" \
  --description="bootstrap.sh for chainguard-demo/e2e-example ($(date -u +%Y-%m-%dT%H:%M:%SZ))" \
  --output=json)
CGR_USER=$(jq -r '.identity_id' <<<"${PULL_TOKEN_JSON}")
CGR_PASS=$(jq -r '.token' <<<"${PULL_TOKEN_JSON}")
if [[ -z "${CGR_USER}" || -z "${CGR_PASS}" || "${CGR_USER}" == "null" ]]; then
  echo "ERROR: failed to parse pull token from chainctl output" >&2
  echo "${PULL_TOKEN_JSON}" >&2
  exit 1
fi

log "rendering ${CLUSTER_RENDERED} from template"
sed -e "s|@@CGR_USER@@|${CGR_USER}|" \
    -e "s|@@CGR_PASS@@|${CGR_PASS}|" \
    "${CLUSTER_TMPL}" > "${CLUSTER_RENDERED}"

# --- cluster -----------------------------------------------------------------
if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  log "k3d cluster '${CLUSTER_NAME}' already exists — refreshing cgr.dev creds on existing nodes"
  # Write the rendered registries.yaml into each node and restart it so
  # containerd picks up the new auth. The format inside the node matches
  # the `registries.config` block we just rendered.
  REGISTRY_AUTH=$(mktemp)
  trap 'rm -f "${REGISTRY_AUTH}"' EXIT
  cat > "${REGISTRY_AUTH}" <<EOF
mirrors:
  "registry.localhost:5000":
    endpoint:
      - http://registry.localhost:5000
configs:
  "cgr.dev":
    auth:
      username: "${CGR_USER}"
      password: "${CGR_PASS}"
EOF
  for node in $(k3d node list --no-headers | awk -v c="${CLUSTER_NAME}" '$3==c && $2 ~ /(server|agent)/ {print $1}'); do
    log "  → ${node}"
    docker cp "${REGISTRY_AUTH}" "${node}:/etc/rancher/k3s/registries.yaml"
    docker restart "${node}" >/dev/null
  done
  rm -f "${REGISTRY_AUTH}"
  trap - EXIT
else
  log "creating k3d cluster '${CLUSTER_NAME}'"
  k3d cluster create --config "${CLUSTER_RENDERED}"
fi

kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null

# Wait for the API server to come back after potential node restarts above.
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
# Build the :0 baseline tag for both components and warm the docker cache for
# every other Dockerfile iteration the demos walk through.
log "building all taskboard image iterations → registry.localhost:5000"
"${SCRIPT_DIR}/build-images.sh"

# Pull resolved image URLs back out of the env file build-images.sh wrote.
# shellcheck disable=SC1091
source "${REPO_ROOT}/.images.env"
export BACKEND_IMAGE FRONTEND_IMAGE

# --- deploy app --------------------------------------------------------------
log "applying app manifests (BACKEND_IMAGE=${BACKEND_IMAGE})"
kubectl apply -f "${REPO_ROOT}/app/manifests/namespace.yaml"

# Containerd on each k3d node already has cgr.dev creds (we wrote
# registries.yaml at cluster create time), but trivy-operator's scan jobs
# need an ImagePullSecret on the workload — that's where it discovers
# registry creds from. Create the docker-registry Secret in taskboard and
# attach it to the default ServiceAccount so every workload picks it up.
log "creating cgr.dev pull-token Secret in taskboard for trivy scan jobs"
kubectl -n taskboard create secret docker-registry cgr-pull-token \
  --docker-server=cgr.dev \
  --docker-username="${CGR_USER}" \
  --docker-password="${CGR_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n taskboard patch serviceaccount default --type=merge \
  -p '{"imagePullSecrets":[{"name":"cgr-pull-token"}]}' >/dev/null

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
  kubectl get -n taskboard vulnerabilityreports.aquasecurity.github.io

To switch the app to Chainguard images and watch the CVE count drop, run:

  ./scripts/migrate-to-chainguard.sh

EOF
