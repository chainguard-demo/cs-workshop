# Chainguard Libraries for Python Remediated

This demo shows how Chainguard's python-remediated repository backports security fixes to older package versions, letting you maintain version stability while staying secure.

We'll use CVE-2021-23727 (stored command injection in Celery 5.2.1) to demonstrate three approaches:
1. **Vulnerable** - Celery 5.2.1 from PyPI
2. **Upstream Fix** - Celery 5.2.2 from PyPI
3. **Remediated** - Celery 5.2.1 from Chainguard with backported fix

Run `./demo.sh` for an interactive walkthrough.

## Prerequisites

- Docker with BuildKit support
- chainctl authenticated with `libraries.python.pull` entitlements
- jq for JSON parsing
- Your Chainguard organization name

## Setup

```bash
export ORG_NAME="<your-org-name>"
```

## Step 1: Vulnerable Build (Celery 5.2.1 from PyPI)

```bash
cd step1-orig
docker build -t celery-demo:vulnerable .
docker run --rm celery-demo:vulnerable
```

## Step 2: Upstream Fix (Celery 5.2.2 from PyPI)

```bash
cd ../step2-upstream-fix
docker build -t celery-demo:fixed .
docker run --rm celery-demo:fixed
```

## Step 3: Chainguard Remediated (Celery 5.2.1 with Fix)

```bash
cd ../step3-cg

CREDS=$(chainctl auth pull-token --repository=python --parent=$ORG_NAME --name="py-demo-$USER" --ttl=1h -o json)
cat > .netrc <<EOF
machine libraries.cgr.dev
  login $(echo $CREDS | jq -r .identity_id)
  password $(echo $CREDS | jq -r .token)
EOF

docker build --secret id=netrc,src=.netrc -t celery-demo:remediated .
docker run --rm celery-demo:remediated

chainctl libraries verify celery-demo:remediated
```

## Cleanup

```bash
ID=$(chainctl iam ids ls --parent=$ORG_NAME -o json | jq -r '.items[] | select(.name | startswith("py-demo")) | .id')
chainctl iam identities delete "$ID" --parent $ORG_NAME --yes
rm .netrc
docker rmi celery-demo:vulnerable celery-demo:fixed celery-demo:remediated
```

## About CVE-2021-23727

Stored command injection in Celery < 5.2.2. The `exception_to_python()` function loads arbitrary Python classes from backend metadata without validation. Version 5.2.2 added proper validation, and Chainguard backported this fix to 5.2.1.

## Why Remediated Libraries

Traditional security patching forces a choice:
- **Upgrade**: Get fixes but risk breaking changes
- **Stay**: Maintain stability but remain vulnerable

Chainguard's remediated libraries provide both:
- Keep the same version (5.2.1)
- Get the security fix backported
- Full SBOM and provenance
- Verifiable with chainctl
