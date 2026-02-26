#!/bin/bash

. ../../base.sh

cd step1-orig/

TYPE_SPEED=100
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

echo -e "
Demo: Converting a JavaScript App to Use Chainguard Libraries

This demo shows how to rebuild a Node.js app using Chainguard Libraries instead of the public npm registry.
We'll build with the upstream registry first, then migrate to Chainguard Libraries using npm, Yarn, and Bun.
"
wait

banner "Setup"
read -p "Enter your Chainguard organization name: " ORG_NAME
export ORG_NAME

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

pe "CREDS_OUTPUT=\$(chainctl auth pull-token \
  --repository=javascript \
  --parent=\$ORG_NAME \
  --name=js-workshop-token-\$USER \
  --ttl=1h \
  -o json)"

pei "export CGR_USER=\$(echo \$CREDS_OUTPUT | jq -r \".identity_id\")"
pei "export CGR_TOKEN=\$(echo \$CREDS_OUTPUT | jq -r \".token\")"
pei "export TOKEN=\$(printf '%s' \$\"{CGR_USER}:\${CGR_TOKEN}\" | base64 | tr -d '\n')"
pei "printf 'registry=https://libraries.cgr.dev/javascript/\n//libraries.cgr.dev/javascript/:_auth=%s\n//libraries.cgr.dev/javascript/:always-auth=true\n' \"\$(echo -n \"\${CGR_USER}:\${CGR_TOKEN}\" | base64 | tr -d '\\n')\" > .npmrc"

pe "cat .npmrc"
pe "cat Dockerfile.npm"

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

pei "printf 'npmRegistryServer: \"https://libraries.cgr.dev/javascript/\"\nnpmAlwaysAuth: true\nnpmAuthIdent: \"%s\"\nnodeLinker: node-modules\n' \"\${CGR_USER}:\${CGR_TOKEN}\" > .yarnrc.yml"

pe "cat .yarnrc.yml"
pe "cat Dockerfile.yarn"

pe "docker build --no-cache \
  --secret id=yarnrc,src=./.yarnrc.yml \
  -t js-lib-example:yarn-cg \
  -f Dockerfile.yarn ."

pei 'docker run -d -p 3000:3000 --name js-lib-example js-lib-example:yarn-cg'
pei 'sleep 2'
pe 'curl http://localhost:3000'
pe 'curl http://localhost:3000/api/health'

pei 'docker stop js-lib-example && docker rm js-lib-example'

banner "Step 5: Build with Chainguard Libraries (Bun)"

#pei "printf '[install]\nregistry = \"https://libraries.cgr.dev/javascript/\"\n\n[install.scopes]\n\"libraries.cgr.dev\" = { token = \"%s\", username = \"%s\" }\n' \"\${CGR_TOKEN}\" \"\${CGR_USER}\" > bunfig.toml"

{
  echo "[install.registry]"
  echo "url = \"https://libraries.cgr.dev/javascript/\""
  echo "username = \"${CGR_USER}\""
  echo "password = \"${CGR_TOKEN}\""
} > bunfig.toml

pe "cat bunfig.toml"
pe "cat Dockerfile.bun"

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
pei 'rm -f .npmrc .yarnrc.yml bunfig.toml'
pei "docker image ls | grep js-lib-example | awk '{print \$2}' | xargs docker image rm"

banner "Demo Complete!"
