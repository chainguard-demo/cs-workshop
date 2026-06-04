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
NEW_IMAGE="cgr.dev/${ORG}/postgres:16"

clear
banner "Postgres is currently using the upstream image."
pe "kubectl -n taskboard get statefulset postgres -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"
pe "kubectl get vulnerabilityreports -n taskboard -l trivy-operator.resource.kind=StatefulSet -o custom-columns=IMAGE:.report.artifact.repository,CRIT:.report.summary.criticalCount,HIGH:.report.summary.highCount,MED:.report.summary.mediumCount,LOW:.report.summary.lowCount"



banner "Let's migrate it to Chainguard."
pe "kubectl -n taskboard set image statefulset/postgres postgres=${NEW_IMAGE}"
pe "kubectl -n taskboard rollout status statefulset/postgres --timeout=3m"
pe "kubectl -n taskboard get pod postgres-0 -o jsonpath='{.spec.containers[0].image}{\"\\n\"}'"

banner "Verify its still working."
pe "curl -ksS https://taskboard.localhost/api/tasks | jq -c '.[] | {id, title, done}'"

banner "Force trivy to re-scan the StatefulSet and wait for its report."
pe "../../scripts/force-rescan.sh -n taskboard postgres"
