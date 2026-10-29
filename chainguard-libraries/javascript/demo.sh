#!/bin/bash

. ../../base.sh
export GIT_PAGER=cat

cd step1-orig/

TYPE_SPEED=100
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

echo -e "
Demo: Converting a JavaScript App to Use Chainguard Libraries

This demo shows how to rebuild a Node.js app using Chainguard Libraries instead of the public npm registry.
We'll build with the upstream registry first, then migrate to Chainguard Libraries using npm, Yarn, and Bun,
authenticating with short-lived tokens from the current chainctl session.
"
wait

banner "Step 1: Baseline Build with Upstream Registry"

pe "cat package.json"
pe "cat Dockerfile"

pei "docker build --no-cache -t js-lib-example:upstream ."

pei 'docker run -d -p 3000:3000 --name js-lib-example js-lib-example:upstream'
pei 'sleep 2'
pe 'curl http://localhost:3000'
pe 'curl http://localhost:3000/api/health'

pei 'docker stop js-lib-example && docker rm js-lib-example'

banner "Step 2: Build with Chainguard Libraries (npm)"

pei "cd ../step2-cg"
rm -f .npmrc bunfig.toml

pe "chainctl auth configure-npm"

pe "cut -c -80 .npmrc"
pe "git diff --no-index -U1000 ../step1-orig/Dockerfile Dockerfile.npm"

pe "docker build --no-cache \
  --secret id=npmrc,src=./.npmrc \
  -t js-lib-example:npm-cg \
  -f Dockerfile.npm ."

pei 'docker run -d -p 3000:3000 --name js-lib-example js-lib-example:npm-cg'
pei 'sleep 2'
pe 'curl http://localhost:3000'
pe 'curl http://localhost:3000/api/health'

pei 'docker stop js-lib-example && docker rm js-lib-example'

banner "Step 3: Build with Chainguard Libraries (Yarn)"

# Yarn Classic reads .npmrc too, but only sends credentials for unscoped
# packages when always-auth is set; configure-npm does not write that line.
pe "echo '//libraries.cgr.dev/javascript/:always-auth=true' >> .npmrc"
pe "git diff --no-index -U1000 Dockerfile.npm Dockerfile.yarn"

pe "docker build --no-cache \
  --secret id=npmrc,src=./.npmrc \
  -t js-lib-example:yarn-cg \
  -f Dockerfile.yarn ."

pei 'docker run -d -p 3000:3000 --name js-lib-example js-lib-example:yarn-cg'
pei 'sleep 2'
pe 'curl http://localhost:3000'
pe 'curl http://localhost:3000/api/health'

pei 'docker stop js-lib-example && docker rm js-lib-example'

banner "Step 4: Build with Chainguard Libraries (Bun)"

pe "export CGR_TOKEN=\$(chainctl auth token --audience libraries.cgr.dev)"

{
  echo "[install.registry]"
  echo "url = \"https://libraries.cgr.dev/javascript/\""
  echo "token = \"${CGR_TOKEN}\""
} > bunfig.toml

pe "cut -c -80 bunfig.toml"
pe "git diff --no-index -U1000 Dockerfile.npm Dockerfile.bun"

pe "docker build --no-cache \
  --secret id=bunfig,src=./bunfig.toml \
  -t js-lib-example:bun-cg \
  -f Dockerfile.bun ."

pei 'docker run -d -p 3000:3000 --name js-lib-example js-lib-example:bun-cg'
pei 'sleep 2'
pe 'curl http://localhost:3000'
pe 'curl http://localhost:3000/api/health'

banner "Cleanup"

pei 'docker stop js-lib-example && docker rm js-lib-example'
pei 'rm -f .npmrc bunfig.toml'
pei "docker image ls | grep js-lib-example | awk '{print \$2}' | xargs docker image rm"

banner "Demo Complete!"
