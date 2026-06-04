#!/usr/bin/env bash
# Force trivy-operator to rescan one or more workloads and wait for fresh
# VulnerabilityReports. Drop a call to this at the end of each demo.sh so the
# "CVEs in Running Pods" dashboard updates promptly.
#
# Usage:
#   ./scripts/force-rescan.sh -n NAMESPACE [-t TIMEOUT_SECONDS] WORKLOAD [WORKLOAD ...]
#
# A WORKLOAD matches the `trivy-operator.resource.name` label exactly OR with
# a `-<hash>` suffix — that covers both bare workload names (StatefulSets,
# DaemonSets) and Deployments-via-their-ReplicaSet hash suffix.

set -euo pipefail

NAMESPACE=""
TIMEOUT=180

while getopts ":n:t:" opt; do
  case "$opt" in
    n) NAMESPACE="$OPTARG" ;;
    t) TIMEOUT="$OPTARG" ;;
    *) echo "usage: $0 -n NS [-t TIMEOUT] WORKLOAD [WORKLOAD ...]" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [[ -z "$NAMESPACE" || $# -eq 0 ]]; then
  echo "usage: $0 -n NS [-t TIMEOUT] WORKLOAD [WORKLOAD ...]" >&2
  exit 2
fi

workloads=("$@")
BLUE='\033[1;34m'; RESET='\033[0m'
log() { printf "${BLUE}==>${RESET} %s\n" "$*"; }

# JSON array of workload prefixes for the jq filter.
prefixes_json() {
  printf '%s\n' "${workloads[@]}" | jq -R . | jq -s .
}

# VR names whose resource.name label matches one of the workloads exactly or
# with a -<hash> suffix (ReplicaSets).
matching_vrs() {
  local p; p=$(prefixes_json)
  kubectl -n "$NAMESPACE" get vulnerabilityreport -o json 2>/dev/null | jq -r --argjson p "$p" '
    .items[]
    | (.metadata.labels["trivy-operator.resource.name"] // "") as $rn
    | select($p | any(. as $x | ($rn == $x or ($rn | startswith($x + "-")))))
    | .metadata.name'
}

# Workloads that still have no matching VR.
missing_workloads() {
  local p; p=$(prefixes_json)
  kubectl -n "$NAMESPACE" get vulnerabilityreport -o json 2>/dev/null | jq -r --argjson p "$p" '
    [.items[].metadata.labels["trivy-operator.resource.name"] // ""] as $names
    | $p
    | map(select(. as $w | ($names | any(. == $w or startswith($w + "-"))) | not))
    | .[]'
}

# Print one summary line per matching VR.
summarise() {
  local p; p=$(prefixes_json)
  kubectl -n "$NAMESPACE" get vulnerabilityreport -o json | jq -r --argjson p "$p" '
    .items[]
    | (.metadata.labels["trivy-operator.resource.name"] // "") as $rn
    | select($p | any(. as $x | ($rn == $x or ($rn | startswith($x + "-")))))
    | "  \(.metadata.name) — CRIT=\(.report.summary.criticalCount) HIGH=\(.report.summary.highCount) MED=\(.report.summary.mediumCount) LOW=\(.report.summary.lowCount)"'
}

log "deleting stale reports in ${NAMESPACE} for: ${workloads[*]}"
matching_vrs | xargs -r -I {} kubectl -n "$NAMESPACE" delete vulnerabilityreport {} >/dev/null || true

log "bouncing trivy-operator to force a reconcile"
kubectl -n trivy-system rollout restart deploy/trivy-operator >/dev/null
kubectl -n trivy-system rollout status deploy/trivy-operator --timeout=2m >/dev/null

log "waiting up to ${TIMEOUT}s for fresh reports"
deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
  if [[ -z "$(missing_workloads)" ]]; then
    summarise
    exit 0
  fi
  sleep 3
done

echo "ERROR: timed out after ${TIMEOUT}s; still missing reports for:" >&2
missing_workloads | sed 's/^/  - /' >&2
exit 1
