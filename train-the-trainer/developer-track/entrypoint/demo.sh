#! env bash

. ../../../base.sh

# Delete existing cluster
if kind get clusters 2>/dev/null | grep -Eq '^entrypoint-example$'; then
  kind delete cluster --name entrypoint-example
fi

kind create cluster --name entrypoint-example

clear

banner "Here's some manifests that deploy nginx. It uses an entrypoint script that uses envsubst to insert environment variable values into templates."
pe "$BATCAT manifest.yaml"
pe "kubectl apply -f  manifest.yaml"
pe "kubectl rollout status deployment nginx"

banner "Let's call /pod."
pe "kubectl debug -it \$(kubectl get pod -l app=nginx -o json | jq -r '.items[0].metadata.name') --profile=general --image=cgr.dev/chainguard/nginx:latest-dev -- wget -qO - http://nginx:80/pod"

banner "Now we'll migrate the deployment to Chainguard with an initContainer."
pe "git diff --no-index -U1000 manifest.yaml manifest-init-container.yaml"
pe "kubectl apply -f manifest-init-container.yaml"
pe "kubectl rollout status deployment nginx"

banner "It should still work when we call /pod again."
pe "kubectl debug -it \$(kubectl get pod -l app=nginx -o json | jq -r '.items[0].metadata.name') --profile=general --image=cgr.dev/chainguard/nginx:latest-dev -- wget -qO - http://nginx:80/pod"

banner "For information that is known at deploy time, we can generate the configuration before we apply the manifests."
pe "git diff --no-index -U1000 manifest.yaml manifest-envsubst.yaml"
pe "ENVIRONMENT_NAME=development envsubst < manifest-envsubst.yaml | kubectl apply -f -"
pe "kubectl rollout status deployment nginx"

banner "We should see the expected response from /environment."
pe "kubectl debug -it \$(kubectl get pod -l app=nginx -o json | jq -r '.items[0].metadata.name') --profile=general --image=cgr.dev/chainguard/nginx:latest-dev -- wget -qO - http://nginx:80/environment"
