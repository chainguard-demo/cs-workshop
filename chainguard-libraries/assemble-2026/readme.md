# Migrating a uv project to Chainguard Libraries

**Assemble London 2026**

A `uv`-managed Python service with 40 locked dependencies from PyPI is moved
onto Chainguard Libraries. Three things happen on the way, and each one is the
point:

1. Configuring the index changes nothing. `uv lock` leaves a lockfile that
   already satisfies `pyproject.toml` **completely untouched** — not one line —
   even where the requirements are ranges with newer releases published.
2. Once the graph is routed through Chainguard, one dependency stops resolving
   — the newest release of `pyjokes` is withheld by an organisation policy, the
   way a novel malware finding would arrive. The fix is a **downgrade**.
3. A live High-severity CVE closes **without any version bump**, because the
   artefact behind the pin becomes a remediated `+cgr.N` build.

Run `./demo.sh` for the scripted walkthrough.

---

## The application

`reportbot` is a small release-report generator. It does just enough real work
to pull a representative slice of the dependency tree into the venv — YAML
config, a Jinja2 template, a Pydantic model, a Pillow-rendered badge, a rich
table. It prints:

```
─────────────────────────────── reportbot 0.1.0 ────────────────────────────────
Release 2026.1 (stable): 2/3 components green.
badge rendered: 790 bytes
```

CVE posture is measured with `grype --only-fixed`. The pins were deliberately
trimmed so that **celery is the only finding** — there is nothing else in the
scan to explain away:

| Scan point | Findings | Detail |
|---|---|---|
| Baseline, from PyPI | 1 | celery 5.2.1, `GHSA-q4xr-rc97-m4xx`, High, fixed in 5.2.2 |
| After migration (Chainguard, same versions) | 1 | *identical* — rebuilding from source changes nothing |
| After remediation (`5.2.1+cgr.1`) | 0 | `No vulnerabilities found` |

The middle row is the interesting one. Rebuilding a package from source does
not change its CVE posture; only the remediated builds do.

`demo.sh` scans at the second and third points. The baseline and the migrated
image produce byte-identical grype output, so the first row is stated rather
than shown — add `grype reportbot:pypi --only-fixed` after the baseline
build if you would rather demonstrate it.

### Why these dependencies

| Package | Pin | Role in the demo |
|---|---|---|
| `celery` | `5.2.1` | The one CVE. Remediated as `5.2.1+cgr.1`, reached by re-resolution. |
| `pyjokes` | `0.8.3` | Withheld by the demo's Libraries policy. Upstream-only and dependency-free. Fixed by pinning **back** to `0.8.2`. |
| `rich`, `python-dateutil` | `13.7.0`, `2.8.2` | Held a version behind so the closing "day two" step has something ordinary to bump. |
| `tabulate`, `idna`, `pyyaml`, `werkzeug`, `flask`, `jinja2`, `requests`, `urllib3`, `pillow`, `pydantic` | ranges (`>=`, `~=`) | Deliberately *not* exact pins. Several have newer releases on PyPI, so step 4 shows `uv lock` leaving a satisfied lockfile alone even where the constraints would permit a bump. |
| everything else | pinned | Pinned to the newest version Chainguard builds from source, so the migration is not muddied by unrelated CVEs. |

---

## Prerequisites

- `chainctl`, authenticated, with `libraries.python.pull` entitlement
- `uv`, `jq`, `tree`, `docker` with BuildKit
- `grype` **0.100.0 or later** — earlier versions do not understand `+cgr.N`
  local versions and will report remediated packages as still vulnerable
- Access to `cgr.dev/chainguard-private/python:3.13-dev`
- Network access to `https://libraries.cgr.dev/`

---

## One-time setup: the demo policy

The block in this demo is **synthetic**. Rather than depending on a real
malicious package — which PyPI removes, and which would put malware in your
lockfile and image layers — the demo blocks one version of an ordinary
dependency using a Libraries policy in your own organisation.

The newest version is the blocked one, which is the realistic shape: novel
malware lands in a fresh release, and the remedy is to pin back.

Two rules govern whether a block actually bites, and both matter:

1. **The token must be org-scoped.** `chainctl auth token
   --audience=libraries.cgr.dev` returns an *unscoped* token and no policy is
   evaluated against it — every request serves normally. Policies only apply
   when the token carries an org scope: `--scope="$ORG_NAME"`. `demo.sh` does
   this; it is the single easiest thing to get wrong.
2. **Blocks only apply to upstream-fallback artefacts.** A version Chainguard
   has rebuilt (served from `/python/simple/…`) is not subject to the org block
   list. The blocked version must be one served from `/python-upstream/simple/…`.

`pyjokes` satisfies both: Chainguard has never built it, so every version comes
via its upstream tier. It is also pure Python with no dependencies, so it adds
nothing to the graph, and the block is what strands it on PyPI — which makes
the straggler and the blocked package the same package.

```bash
chainctl libraries policy create --name=assemble-demo --parent="$ORG_NAME" \
  --cooldown-days=7 \
  --block=purl=pkg:pypi/pyjokes@0.8.3
```

Only one policy can be bound per ecosystem, so activating it replaces the
existing PYTHON binding. `--cooldown-days=7` preserves the behaviour of the
default policy it displaces, and the malware gate is global rather than
policy-bound, so nothing is weakened:

```bash
chainctl libraries policy disable default-7d-cooldown --parent="$ORG_NAME" --ecosystem=PYTHON
chainctl libraries policy enable  assemble-demo       --parent="$ORG_NAME" --ecosystem=PYTHON --mode=ENFORCE
```

Verify, using a **scoped** token — `0.8.3` should be withheld, `0.8.2` served:

```bash
NETRC=$(mktemp); chmod 600 "$NETRC"
printf 'machine libraries.cgr.dev\nlogin token-user\npassword %s\n' \
  "$(chainctl auth token --audience=libraries.cgr.dev --scope="$ORG_NAME")" > "$NETRC"

for v in 0.8.2 0.8.3; do
  printf '%s ' "$v"
  curl -s -o /dev/null -w '%{http_code}\n' --netrc-file "$NETRC" \
    "https://libraries.cgr.dev/python-upstream/simple/pyjokes/$v/pyjokes-$v-py3-none-any.whl"
done
# 0.8.2 302   <- allowed
# 0.8.3 409   <- blocked
```

A blocked artefact returns `409` with `reason: POLICY_ORG_BLOCKLIST`, and the
denial is complete — following the redirect yields no bytes.

To put the organisation back as it was:

```bash
chainctl libraries policy disable assemble-demo       --parent="$ORG_NAME" --ecosystem=PYTHON
chainctl libraries policy enable  default-7d-cooldown --parent="$ORG_NAME" --ecosystem=PYTHON --mode=ENFORCE
chainctl libraries policy delete  assemble-demo       --parent="$ORG_NAME"
```

`demo.sh` defaults to `ORG_NAME=rob.best`; override with
`ORG_NAME=other.org ./demo.sh`.

---

## Layout

```
app/                                  pristine baseline, never mutated
  pyproject.toml                      PyPI only, pyjokes==0.8.3 (the blocked pin)
  uv.lock                             40 dependencies, all from PyPI
  Dockerfile                          uv sync --frozen, no credentials
  src/reportbot/
configs/
  pyproject.chainguard.toml           + Chainguard indexes, PyPI still a fallback
  pyproject.chainguard-default.toml   + default = true, closing the fallback
  pyproject.chainguard-fixed.toml     pyjokes pinned back to 0.8.2
  Dockerfile.chainguard               + the netrc secret mount
work/                                 scratch copy, created and removed by demo.sh
```

Each change is a complete file swapped into place, shown first as
`git diff --no-index -U10000` so the whole file is on screen with the change
highlighted. Lockfile changes are shown by snapshotting `uv.lock` and diffing
the whole file against the snapshot.

---

## Walkthrough

The script copies `app/` to `work/` and mutates the copy. `app/` is the
pristine baseline and is never touched.

### 1. The project, before anything changes

```bash
tree
cat pyproject.toml
cat src/reportbot/__main__.py
grep -B1 -A5 '^name = "tabulate"' uv.lock
cat Dockerfile
```

That lockfile grep is the premise of the whole demo — an entry is not just a
version, it is an **absolute URL and an integrity hash**:

```toml
[[package]]
name = "tabulate"
version = "0.9.0"
source = { registry = "https://pypi.org/simple" }
sdist = { url = "https://files.pythonhosted.org/packages/ec/fe/.../tabulate-0.9.0.tar.gz", hash = "sha256:0095b12b..." }
wheels = [
    { url = "https://files.pythonhosted.org/packages/40/44/.../tabulate-0.9.0-py3-none-any.whl", hash = "sha256:024ca478..." },
]
```

There are 208 such PyPI references in the baseline lockfile.

### 2. Build and run it — no credentials involved

```bash
docker build -t reportbot:pypi .
docker run --rm reportbot:pypi
```

Nothing Chainguard is configured yet, so no `--secret` is needed.

### 3. Get a Chainguard token

```bash
CHAINGUARD_TOKEN=$(chainctl auth token --audience=libraries.cgr.dev --scope=rob.best)
printf "machine libraries.cgr.dev\nlogin token-user\npassword %s\n" \
  "$CHAINGUARD_TOKEN" > "$NETRC"
chmod 600 "$NETRC"
```

The token is never printed. `--scope` is load-bearing: without it, policies are
not evaluated. `$NETRC` is a `mktemp` path outside the repository, removed on
exit.

### 4. Point uv at Chainguard

```bash
git diff --no-index -U10000 pyproject.toml ../configs/pyproject.chainguard.toml
git diff --no-index -U10000 Dockerfile ../configs/Dockerfile.chainguard
uv lock
diff -q .before.lock uv.lock
grep -B1 -A5 '^name = "tabulate"' uv.lock
```

`pyproject.chainguard.toml` declares the remediated index first, then the
standard index. It stops short of `default = true`, so **PyPI is still a
configured index** — deliberately. `Dockerfile.chainguard` adds the netrc
secret mount.

The `diff` prints **nothing**. `uv lock` did not change one line: every entry
already records `source = "https://pypi.org/simple"`, PyPI is still a
configured index, and every requirement is still satisfiable there, so the
lockfile is already valid and uv has no reason to touch it. Adding an index
does not move an existing lock.

That is not an artefact of pinning. Ten dependencies are ranges rather than
exact pins, and several have newer releases on PyPI — `tabulate>=0.9.0` stays
locked at `0.9.0` with a newer version published, which the `tabulate` grep
shows directly. A lockfile that satisfies `pyproject.toml` is not re-resolved.

Building here would be a waste: `uv sync --frozen` would install exactly what
the lockfile says, from `files.pythonhosted.org`, and
`chainctl libraries verify` would read **0.00%**. The lockfile has to be fixed
first, which is the rest of the walkthrough.

This is the step people get wrong: pointing uv at Chainguard changes nothing
on its own.

### 5. Close the fallback

```bash
git diff --no-index -U10000 pyproject.toml ../configs/pyproject.chainguard-default.toml
uv lock
```

One added line — `default = true` — makes the Chainguard index *the* default
and drops PyPI entirely. Now every recorded `source` is an index that is no
longer configured, so uv has to re-resolve the whole graph — and immediately
hits the wall:

```
× No solution found when resolving dependencies:
╰─▶ Because pyjokes was not found in the package registry and your project
    depends on pyjokes==0.8.3, we can conclude that your project's
    requirements are unsatisfiable.
```

### 6. Meet the policy block

Chainguard withholds `0.8.3`, and with PyPI gone there is nowhere else to get
it:

```bash
chainctl libraries packages blocked --parent=$ORG_NAME --ecosystem=PYTHON --package pyjokes
chainctl libraries policy describe assemble-demo --parent=$ORG_NAME
```

```
 PACKAGE | VERSION | REASON |    ATTEMPTED     |    UNBLOCKS    | COUNT
 pyjokes | 0.8.3   | policy | 2026-09-28 14:07 | never (policy) | 116
```

```
Name: assemble-demo
Cooldown: 7
Block list (1):
  - pkg:pypi/pyjokes@0.8.3
```

Ask Chainguard for that exact artefact and it says why:

```bash
curl -s --netrc-file $NETRC \
  https://libraries.cgr.dev/python-upstream/simple/pyjokes/0.8.3/pyjokes-0.8.3-py3-none-any.whl | jq .
```

```json
{
  "error": "file withheld by policy: policy",
  "reason": "POLICY_ORG_BLOCKLIST",
  "message": "file withheld by policy: policy"
}
```

`POLICY_ORG_BLOCKLIST` is *your* organisation's block list, not Chainguard's
global malware feed, which reports `MALWARE_DETECTED`.

### 7. Pin back to a version the policy allows

The previous version serves normally, which is what makes the downgrade a
viable fix:

```bash
curl -sL --netrc-file $NETRC \
  https://libraries.cgr.dev/python-upstream/simple/pyjokes/0.8.2/pyjokes-0.8.2-py3-none-any.whl | tar -tv
```

```bash
git diff --no-index -U10000 pyproject.toml ../configs/pyproject.chainguard-fixed.toml
uv lock
```

This is the `uv lock` that actually migrates the project. With PyPI gone and
`0.8.3` off the pin, resolution finally succeeds, and because no recorded
`source` is reachable any more it rewrites every entry — a wall of change in
the diff. Nothing drifts: no `--upgrade` is involved, so the locked versions
still act as preferences and only the provenance moves.

Nothing points at PyPI any more:

```bash
grep -c 'pypi.org\|pythonhosted' uv.lock                      # 0
grep -A6 '^name = "pyjokes"' uv.lock | grep -oE 'https://[^"]+'
# https://libraries.cgr.dev/python/simple
# https://libraries.cgr.dev/python-upstream/simple/pyjokes/0.8.2/pyjokes-0.8.2.tar.gz
# https://libraries.cgr.dev/python-upstream/simple/pyjokes/0.8.2/pyjokes-0.8.2-py3-none-any.whl
```

The `source` line records the configured index; the artefact URLs show the
tier that actually served it. `pyjokes` came over Chainguard's **upstream**
tier, byte-identical to PyPI's.

### 8. Build the migrated project

```bash
docker build --secret id=netrc,src=$NETRC -t reportbot:cg-migrated .
chainctl libraries verify venv
docker run --rm reportbot:cg-migrated
```

**`Verification Coverage: 90.24%`** — see [The coverage
number](#the-coverage-number) for what the missing 10% is.

### 9. Re-resolve for remediations

```bash
grype reportbot:cg-migrated --only-fixed
```

Still one finding, unchanged from the baseline. `+cgr.N` builds only arrive
when the package is allowed to move:

```bash
chainctl libraries packages versions pypi:celery | grep remediated
# 5.2.1+cgr.1 | remediated | - | 2026-05-30 08:22 | 2025-09-12 18:16 | ...
uv lock --upgrade-package celery
```

`5.2.1+cgr.1` is a PEP 440 local version. It satisfies `celery==5.2.1` and
sorts *above* plain `5.2.1`, so the pin in `pyproject.toml` never changes —
which is the whole trick.

### 10. Result

```bash
docker build --secret id=netrc,src=$NETRC -t reportbot:cg-remediated .
docker run --rm reportbot:cg-remediated
grype reportbot:cg-remediated --only-fixed
# No vulnerabilities found
```

The SBOM shipped inside the wheel shows its work:

```bash
jq '.packages[0] | {versionInfo, supplier, sourceInfo}' \
  venv/lib/python3.13/site-packages/celery-5.2.1+cgr.1.dist-info/sboms/sbom.spdx.json
```

```
"sourceInfo": "Build by Chainguard, Inc. from git+https://github.com/celery/celery,
 tag: v5.2.1, commit id: d32356c0e46... with patches:
 0001-bump-local-version-to-cgr.1.patch, 0002-CVE-2021-23727-primary-fix.patch."
```

### 11. Day two

```bash
uv add --no-sync 'rich===15.0.0' --upgrade-package rich
uv add --no-sync 'python-dateutil===2.9.0.post0' --upgrade-package python-dateutil
git diff --no-index .before.lock uv.lock
```

Both resolve straight to `libraries.cgr.dev/python/simple` with no further
configuration. Eight changed lines per package, no new
transitive dependencies — an ordinary, reviewable version bump. `--no-sync`
keeps it lockfile-only; the project is only ever installed inside the image.

---

## Maintenance

Two parts of this demo track live data and should be re-checked shortly before
presenting.

### The demo policy

The block is synthetic, so nothing expires — but the policy has to be in place
and correctly bound. Confirm with a **scoped** token:

```bash
chainctl libraries policy binding list --parent=$ORG_NAME   # assemble-demo | PYTHON | ENFORCE
chainctl libraries policy describe assemble-demo --parent=$ORG_NAME
```

```bash
for v in 0.8.2 0.8.3; do
  printf '%s ' "$v"
  curl -s -o /dev/null -w '%{http_code}\n' --netrc-file "$NETRC" \
    "https://libraries.cgr.dev/python-upstream/simple/pyjokes/$v/pyjokes-$v-py3-none-any.whl"
done
# 0.8.2 302   <- allowed
# 0.8.3 409   <- blocked
```

If both return `302`, the most likely cause is an **unscoped token**. The second
most likely is that Chainguard has since built `pyjokes`, which would move it
off the upstream path and out of reach of the block list; in that case pick
another package whose index entries are all `/python-upstream/simple/…`.

`chainctl libraries packages blocked` accumulates one row per day the block is
hit, so expect several rows of history from previous runs. They age out after
30 days.

### The coverage number

`90.24%` is 37 of 41. The detail is in `verify -o json --detailed`:

```
Python packages: 37 of 40 packages verified via per-package SBOMs (92.5%)
```

40 Python packages are installed; 41 is the count including one non-Python
materialized artefact (bundled native libraries such as
`pillow.libs/libwebp…so`). The three unverified Python packages are the ones
Chainguard has not built from source, all served over the upstream proxy:

| Package | Version |
|---|---|
| `charset-normalizer` | `3.5.1` |
| `pyjokes` | `0.8.2` |
| `pytz` | `2026.3` |

They are byte-identical to PyPI's, so there is no Chainguard SBOM in the
`.dist-info` to verify against. Re-check with:

```bash
chainctl libraries update-hashes --dry-run uv.lock | grep '^Packages:'
```

If more of them become available, bump the pins in `app/pyproject.toml` and
regenerate the baseline:

```bash
cd app && rm uv.lock && uv lock
```

---

## Notes

- **Policies only apply to org-scoped tokens.** `chainctl auth token
  --audience=libraries.cgr.dev` returns an unscoped token; requests made with
  it are not evaluated against any policy and every artefact serves. Add
  `--scope="$ORG_NAME"`. Symptom when you get this wrong: `chainctl libraries
  packages blocked` records `reason=policy` events with a rising counter while
  the downloads all succeed.
- **Block lists only cover upstream-fallback artefacts.** A version Chainguard
  has rebuilt (`/python/simple/…`) is not subject to the org block list; only
  versions served from `/python-upstream/simple/…` are. That is why the demo
  blocks `pyjokes`, which Chainguard has never built.
- **Two different denials, two different reasons.** The org block list returns
  `409 POLICY_ORG_BLOCKLIST`; Chainguard's global malware feed returns
  `409 MALWARE_DETECTED` and is not org-scoped. Cooldown returns
  `409 POLICY_COOLDOWN`.
- **`default = true` is load-bearing.** The remediated index forces
  `index-strategy = "unsafe-best-match"` — `first-index` stops at the
  remediated index, which does not carry most of these packages. Given that
  strategy, omitting `default = true` leaves PyPI in the candidate set, so on
  any fresh resolve a blocked version comes straight from PyPI with nothing to
  indicate it. `pyproject.chainguard.toml` omits it deliberately, for step 4;
  the other two configs set it.
- **`--frozen`, not `--locked`.** Astral's reference Dockerfile uses
  `uv sync --locked`, which re-resolves in memory and fails if the lockfile is
  not current. That is the better production default, and worth saying aloud.
  `--frozen` installs the lockfile verbatim instead, so what lands in the image
  is exactly the lockfile the audience just watched change, with no second
  resolution to explain.
- **Run the install in Linux.** Chainguard does not publish macOS wheels, so
  compiled packages (`pillow`, `pydantic-core`, `markupsafe`) fall back to PyPI
  on a Mac and coverage drops. The demo builds in a container for this reason.
- **Builds are layer-cached, deliberately.** `pyproject.toml` and `uv.lock` are
  the only files copied before the install, so the install layer's cache key is
  exactly those two. Every step changes one of them, so each rebuild is real;
  re-running the whole demo is much faster. `DEMO_NO_CACHE=1 ./demo.sh` forces
  cold builds.
- **`uv sync --no-cache` stays, though.** That disables *uv's* cache, not
  Docker's, and is irrelevant on a layer-cache hit. On a miss it guarantees a
  real download from the configured index. A BuildKit cache mount for
  `~/.cache/uv` would speed up cold builds but could serve wheels fetched
  before the index was switched, quietly undoing the migration inside the
  image.
- **`--no-install-project` matters.** Building `reportbot` itself would resolve
  an unlocked build backend (`hatchling`, `packaging`) against the Chainguard
  index and fail on a hash mismatch. The Dockerfile installs dependencies only
  and runs the app from `PYTHONPATH`.
- **Re-resolves are scoped, not big-bang.** `uv lock --upgrade-package` holds
  every other package at its locked version, so each step has a visible and
  minimal blast radius. Package names are written out explicitly in `demo.sh`
  rather than derived at runtime, so what you see on screen is what runs — but
  they need re-checking if the dependency set changes.
- **Re-resolution, not `update-hashes`, is what moves the lockfile.**
  `update-hashes` only rewrites what Chainguard rebuilt: a version served by
  the upstream proxy is byte-identical to PyPI's, so there is no different hash
  to write and chainctl reports it as "not in Chainguard". It also leaves
  **91 `files.pythonhosted.org` wheel URLs** behind across ten packages
  (`charset-normalizer` 37, `markupsafe` 20, `pydantic-core` 11, `pillow` 10,
  `pyyaml` 7, and others) — invisible to `grep -B3 'pypi.org/simple'`, which
  matches only `source` registry lines. `uv lock` routes all of them through
  `libraries.cgr.dev` in one step, which is why the demo uses it. See
  `ECO-ticket-draft.md`.
- **The step 7 lockfile diff is a wall of change, by design.** That is the one
  `uv lock` that re-resolves: dropping PyPI invalidates every recorded
  `source`, so `source`, `url`, `hash` and `upload-time` are rewritten on every
  entry. Versions should not move — locked versions still act as preferences,
  including for the ten range-pinned dependencies — so a version change in that
  diff means Chainguard does not carry the locked build; worth a glance.
  Later steps re-resolve a single package and are not diffed, to keep them
  readable. (`update-hashes` leaves `upload-time` alone, which the next
  re-resolve then corrects everywhere — repro in `ECO-ticket-draft.md`.)
- **`update-hashes --remediated` is not the path to `+cgr.N` builds.** It looks
  for the exact pinned version, and the remediated index publishes
  `5.2.1+cgr.1`, not `5.2.1`. Re-resolution is what reaches remediated builds.
- **Filenames are normalised.** PyPI names fold to underscores in artefact
  filenames; `pyjokes` happens to have neither, but e.g. `python-dateutil`
  serves `python_dateutil-…`.
- **`.netrc` is written to a temp file outside the repo** and removed on exit.
