#! env bash

. ../../base.sh

for i in $(docker ps -f 'name=webserver' -q); do
  docker rm -f $i
done

if kind get clusters | grep -q nginx; then
  kind delete cluster --name=nginx
fi

kind create cluster --name nginx

clear

banner "Let's start a simple webserver container."
pe "docker run -d -p 8080:8080 --name webserver cgr.dev/chainguard/nginx"

banner "Check it's running."
pe "curl http://localhost:8080"

banner "Try to exec in."
pe "docker exec -it webserver bash"
pe "docker exec -it webserver sh"
pe "docker exec -it webserver /bin/sh"

banner "Use Docker Debug."
pe "docker debug webserver"

banner "Or, cdebug."
pe "cdebug exec -it --rm webserver"
pe "cdebug exec -it --rm --privileged webserver"

banner "Let's run nginx in Kubernetes."
pe "kubectl run nginx --image=cgr.dev/chainguard/nginx --port=8080"
pe "kubectl wait pod/nginx --for=condition=Ready --timeout=60s"
pe "kubectl get pods"

banner "Try to exec in."
pe "kubectl exec -it nginx -- sh"

banner "Use kubectl debug."
pe "kubectl debug -it nginx --profile=general --target nginx --image=busybox"

banner "You could also copy the target pod and swap in the -dev image"
pe "kubectl debug nginx --profile=general --copy-to=nginx-dev --set-image=*=cgr.dev/chainguard/nginx:latest-dev"
pe "kubectl wait pod/nginx-dev --for=condition=Ready --timeout=60s"
pe "kubectl exec -it nginx-dev -- sh"
