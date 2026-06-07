# Taskboard — Chainguard Migration Demo

This is an end to end demo of migrating an example service to Chainguard.

It's a three-tier sample application deployed to a local Kubernetes cluster with
continuous vulnerability scanning. The point of the demo is to show what
happens to a workload's CVE profile when you migrate from upstream base
images to Chainguard images, as well as some of the issues you may
encounter along the way and how to resolve them.

```
                       https://taskboard.localhost
                                 │
                         ┌───────▼────────┐
                         │  ingress-nginx │
                         └───────┬────────┘
                                 │
                         ┌───────▼────────┐
                         │  frontend      │  React + Vite, served by nginx
                         │  (Deployment)  │  proxies /api → backend
                         └───────┬────────┘
                                 │
                         ┌───────▼────────┐
                         │  backend       │  Node.js + Express
                         │  (Deployment)  │  node-postgres → Postgres
                         └───────┬────────┘
                                 │
                         ┌───────▼────────┐
                         │  postgres      │  PostgreSQL 16, init.sql seed
                         │  (StatefulSet) │
                         └────────────────┘

         ╔════════════════════════════════════════════╗
         ║   Trivy Operator scans every workload      ║
         ║   →  VulnerabilityReport CRDs              ║
         ║   →  Prometheus metrics                    ║
         ║   →  Grafana "Trivy Operator Dashboard"    ║
         ╚════════════════════════════════════════════╝
```

## Prerequisites

You need these installed on the host:

- [Docker](https://docs.docker.com/get-docker/)
- [k3d](https://k3d.io/) (≥ 5.x)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/) (v3)
- [`chainctl`](https://docs.chainguard.dev/chainguard/chainctl-usage/)
- [`crane`](https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md)
- `jq`

Your Chainguard organization must have these images enrolled (the demo
defaults to `cs-ttt-demo.dev`, which has them):

- `node`
- `postgres`

If you want to migrate the cluster components as well, these are the additional
images you'll also want to have:

- `ingress-nginx-controller`
- `kubectl`
- `cert-manager-controller`
- `cert-manager-cainjector`
- `cert-manager-webhook`
- `cert-manager-acmesolver`
- `cert-manager-startupapicheck`
- `grafana`
- `k8s-sidecar`
- `prometheus`
- `prometheus-operator`
- `prometheus-config-reloader`
- `kube-state-metrics`
- `trivy-operator`
- `trivy`

## Demo

This is how to run the demo.

Set `ORG` if you aren't using the `cs-ttt-demo.dev` organization.

```bash
export ORG=my-org
```

### 1. Bootstrap

Stand up the cluster with all the components running on upstream images.

```bash
./scripts/bootstrap.sh
```

### 2. Explain Demo

Show the directory structure and talk about the example.

```bash
tree
```

List all the pods to show the cluster up and running.

```bash
kubectl get pods --all-namespaces
```

### 3. Demonstrate Application

Open the app at `https://taskboard.localhost`.

Trust warnings are expected — TLS uses a local self-signed CA.

### 4. Demonstrate Grafana

Open Grafana at `https://grafana.taskboard.localhost`. The username and password
are `admin / admin`.

Navigate to the dashboard at `Taskboard - CVEs in Running Pods`.

### 5. Migrate Frontend

```bash
cd app/frontend
./demo.sh
```

### 6. Migrate Backend

```bash
cd app/backend
./demo.sh
```

### 7. Migrate Database

```bash
cd app/db
./demo.sh
```
## 8. Teardown

```bash
./scripts/teardown.sh
```
