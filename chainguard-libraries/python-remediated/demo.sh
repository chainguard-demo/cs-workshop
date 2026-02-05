#!/usr/bin/env bash

. ../../base.sh

TYPE_SPEED=100
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

echo -e "
Demo: Chainguard Libraries for Python - Remediated Repository

CVE-2021-23727 in Celery 5.2.1 - Three approaches:
1. Vulnerable: Celery 5.2.1 from PyPI
2. Upstream Fix: Celery 5.2.2 from PyPI
3. Remediated: Celery 5.2.1 from Chainguard with backported fix
"
wait

banner "Setup"

read -p "Enter your Chainguard organization name: " ORG_NAME
export ORG_NAME

banner "Step 1: Vulnerable (Celery 5.2.1 from PyPI)"
wait
pei "cd step1-orig"
pe "cat requirements.txt"
pei ""

pei "docker build --no-cache -t celery-demo:vulnerable ."

banner "This run will work, as celery 5.2.1 allows OS command injection."
wait
pei "docker run --rm celery-demo:vulnerable"

banner "Step 2: Upstream Fix (Celery 5.2.2 from PyPI)"
wait

pei "cd ../step2-upstream-fix"
pe "cat requirements.txt"

pei "docker build --no-cache -t celery-demo:fixed ."
banner "This will throw an exception, as the OS command injection vuln is fixed in 5.2.2."
wait
pei "docker run --rm celery-demo:fixed"

banner "Step 3: Remediated (Celery 5.2.1 from Chainguard)"
wait
pei "cd ../step3-cg"
pe "cat requirements.txt"

pei "CREDS=\$(chainctl auth pull-token --repository=python --parent=\$ORG_NAME --name=py-demo-\$USER --ttl=1h -o json)"

{
  echo "machine libraries.cgr.dev"
  echo "login $(echo $CREDS | jq -r .identity_id)"
  echo "password $(echo $CREDS | jq -r .token)"
} > .netrc

pe "cat pyproject.toml"
pei ""

pei "docker build --no-cache --secret id=netrc,src=.netrc -t celery-demo:remediated ."
banner "This will throw an exception - celery 5.2.1 from Chainguard's python-remediated repository includes the CVE fix."
wait
pei "docker run --rm celery-demo:remediated"

banner "Use chainctl libraries verify to determine package coverage from Chainguard."
wait
pei "chainctl libraries verify celery-demo:remediated"

banner "Cleanup"
wait
pei "ID=\$(chainctl iam ids ls --parent=\$ORG_NAME -o json | jq -r '.items[] | select(.name | startswith(\"py-demo\")) | .id')"
pei "chainctl iam identities delete \$ID --parent \$ORG_NAME --yes"
pei "rm .netrc"
pei "docker rmi celery-demo:vulnerable celery-demo:fixed celery-demo:remediated"

echo -e "
${GREEN}Demo Complete!${COLOR_RESET}

Key Takeaways:
✓ Celery 5.2.1 has CVE-2021-23727
✓ Traditional fix: Upgrade to 5.2.2 (may break compatibility)
✓ Chainguard: Use 5.2.1 with backported fix
  - Same version, no compatibility risk
  - Security fix included
  - Full SBOM and provenance
"

exit 0
