#!/usr/bin/env bash
#
# Assemble London 2026 - Migrating a uv project to Chainguard Libraries
#
# The demo mutates a scratch copy in work/; app/ is never touched.

set -uo pipefail

. ../../base.sh

TYPE_SPEED=140
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${DEMO_DIR}/work"
NETRC="$(mktemp -t cglibs)"          # outside the repo, mode 600
IMAGE="reportbot"

# Organisation the policy commands are scoped to. Override with
# ORG_NAME=other.org ./demo.sh
ORG_NAME="${ORG_NAME:-rob.best}"

# The blocked package. Blocked by the 'assemble-demo' Libraries policy in
# ${ORG_NAME} - see readme.md for the one-time setup. It must be a version
# served by upstream fallback: policy blocks do not apply to Chainguard-built
# artefacts. pyproject.chainguard.toml omits default = true so PyPI keeps
# serving it anyway; that bypass is the reveal, so leave those configs
# uncommented - swap_file puts them on screen as a diff.
BLOCKED_PKG="pyjokes"
BLOCKED_VER="0.8.3"   # the newest release - blocked, as novel malware would be
FIXED_VER="0.8.2"     # the known-good release we pin back to
POLICY="assemble-demo"

# Day-two bumps. Both are ordinary upgrades with no new transitive deps, so the
# final lockfile diff is small enough to read on screen. --no-sync keeps them
# lockfile-only: the project is only ever installed inside the image.
BUMP1="rich===15.0.0"
BUMP2="python-dateutil===2.9.0.post0"

# pyproject.toml and uv.lock are the only files copied before the install, so
# the install layer's cache key is exactly those two. Every step here that
# changes either one rebuilds for real; re-running the whole demo is fast.
# Set DEMO_NO_CACHE=1 to force cold builds.
DOCKER_BUILD="docker build"
if [ -n "${DEMO_NO_CACHE:-}" ]; then
  DOCKER_BUILD="docker build --no-cache"
fi

cleanup() { rm -f "${NETRC}"; }
trap cleanup EXIT

# Show a file swap as a git-style diff, then apply it.
swap_file() {
  local target="$1" next="../configs/$2"
  pe "git diff --no-index -U10000 ${target} ${next}"
  cp "${next}" "${target}"
}

# Snapshot uv.lock, then diff the whole file against that snapshot.
lock_snapshot() { cp uv.lock .before.lock; }
lock_diff() { pe "git diff --no-index .before.lock uv.lock"; }

rm -rf "${WORK}"
cp -r "${DEMO_DIR}/app" "${WORK}"
cd "${WORK}" || exit 1

clear

###############################################################################
# The project
###############################################################################
banner "reportbot: a small Python service, managed with uv"
pe "tree"
pe "cat pyproject.toml"
pe "cat src/reportbot/__main__.py"
pe "grep -B1 -A5 '^name = \"tabulate\"' uv.lock"
pe "cat Dockerfile"
pe "${DOCKER_BUILD} -t ${IMAGE}:pypi ."
pe "docker run --rm ${IMAGE}:pypi"
wait

###############################################################################
# Initial migration
###############################################################################
banner "Let's migrate to Chainguard"
pe 'CHAINGUARD_TOKEN=$(chainctl auth token --audience=libraries.cgr.dev --scope='"${ORG_NAME}"')'
export NETRC
pe 'printf "machine libraries.cgr.dev\nlogin token-user\npassword %s\n" "$CHAINGUARD_TOKEN" > "$NETRC"'
pe 'chmod 600 "$NETRC"'
swap_file pyproject.toml pyproject.chainguard.toml
swap_file Dockerfile Dockerfile.chainguard
pe "${DOCKER_BUILD} --secret id=netrc,src=\${NETRC} -t ${IMAGE}:cg ."
pe "docker create --name ${IMAGE}-cg ${IMAGE}:cg"
pe "docker cp ${IMAGE}-cg:/app/.venv ./venv"
pe "docker rm ${IMAGE}-cg"
pe "chainctl libraries verify venv"
pe "grep -B1 -A5 '^name = \"tabulate\"' uv.lock"
wait
rm -rf venv

###############################################################################
# Re-resolve the lockfile
###############################################################################
banner "Re-resolve the lockfile against Chainguard"

lock_snapshot
pe "uv lock"
pe "grep -B1 -A5 '^name = \"tabulate\"' uv.lock"
lock_diff
pe "grep -B3 'pypi.org/simple' uv.lock"
pe "chainctl libraries packages blocked --parent=\${ORG_NAME} --ecosystem=PYTHON --package ${BLOCKED_PKG} | grep '${BLOCKED_VER}\\|REASON'"
pe "chainctl libraries policy describe ${POLICY} --parent=\${ORG_NAME}"
pe "curl -s --netrc-file \${NETRC} \
  https://libraries.cgr.dev/python-upstream/simple/${BLOCKED_PKG}/${BLOCKED_VER}/${BLOCKED_PKG}-${BLOCKED_VER}-py3-none-any.whl | jq ."
wait

###############################################################################
# Close the fallback
###############################################################################
banner "Make Chainguard the only index"

swap_file pyproject.toml pyproject.chainguard-default.toml
pe "uv lock"
wait

###############################################################################
# Resolve the block
###############################################################################
banner "Pin back to a version Chainguard will serve"

pe "curl -sL --netrc-file \${NETRC} \
  https://libraries.cgr.dev/python-upstream/simple/${BLOCKED_PKG}/${FIXED_VER}/${BLOCKED_PKG}-${FIXED_VER}-py3-none-any.whl | tar -tv"
swap_file pyproject.toml pyproject.chainguard-fixed.toml
pe "uv lock"
pe "grep -c 'pypi.org\|pythonhosted' uv.lock"
pe "grep -A6 '^name = \"${BLOCKED_PKG}\"' uv.lock | grep -oE 'https://[^\"]+'"
wait

###############################################################################
# Build the migrated project
###############################################################################
banner "Now build it"

pe "${DOCKER_BUILD} --secret id=netrc,src=\${NETRC} -t ${IMAGE}:cg-migrated ."
pe "docker create --name ${IMAGE}-cgm ${IMAGE}:cg-migrated"
pe "docker cp ${IMAGE}-cgm:/app/.venv ./venv"
pe "docker rm ${IMAGE}-cgm"
pe "chainctl libraries verify venv"
rm -rf venv
pe "docker run --rm ${IMAGE}:cg-migrated"
wait

###############################################################################
# Surgical re-resolve #2: the remediations
###############################################################################
banner "Let's check the CVEs."
pe "grype ${IMAGE}:cg-migrated --only-fixed -q | head -8"
pe "chainctl libraries packages versions pypi:celery | grep remediated"
lock_snapshot
pe "uv lock --upgrade-package celery"
lock_diff
wait

###############################################################################
# Result
###############################################################################
banner "Build it and run it"

pe "${DOCKER_BUILD} --secret id=netrc,src=\${NETRC} -t ${IMAGE}:cg-remediated ."
pe "docker run --rm ${IMAGE}:cg-remediated"
pe "grype ${IMAGE}:cg-remediated --only-fixed -q | head -8"
wait

###############################################################################
# Day two
###############################################################################
banner "Ordinary version bumps, from here on"

lock_snapshot
pe "uv add --no-sync '${BUMP1}' --upgrade-package ${BUMP1%%=*}"
pe "uv add --no-sync '${BUMP2}' --upgrade-package ${BUMP2%%=*}"
lock_diff

exit 0
