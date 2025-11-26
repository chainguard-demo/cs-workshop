#!/usr/bin/env bash
DEPLOY_DIR="non-cg"

# validate envsubst is installed
if ! command -v envsubst &> /dev/null
then
    echo "envsubst could not be found, please install it)"
    echo
    echo "On MacOS: brew install gettext && brew link --force gettext"
    echo "On Debian/Ubuntu: apt-get install gettext-base"
    exit
fi

if ! command -v kind &> /dev/null
then
    echo "kind could not be found, please install it"
    echo
    echo "open https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit
fi

if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found, please install it"
    echo
    echo "open https://kubernetes.io/docs/tasks/tools/"
    exit
fi

read -p "Enter the Chainguard org name (default is cs-ttt-demo.dev): " ORG_NAME
export ORG_NAME=${ORG_NAME:-cs-ttt-demo.dev}

read -p "Are you using Chainguard images? (YES/no): " CHAINGUARD_IMAGES
CHAINGUARD_IMAGES=${CHAINGUARD_IMAGES:-yes}

# if .pull-token exists, source it
if [ -f .pull-token ]; then
  echo ".pull-token file found, using token from there"
  source .pull-token
else
  echo "No .pull-token file found, please enter the pull token user and password"
  read -p "Enter the pull token user: " PULL_USER
  read -p "Enter the pull token password: " PULL_PASS

  read -p "Do you want to save the pull token (in .pull-token) for future use? (YES/no): " SAVE_TOKEN
  SAVE_TOKEN=${SAVE_TOKEN:-yes}
  if [ "$SAVE_TOKEN" == "yes" ]; then
    echo "export PULL_USER=$PULL_USER" > .pull-token
    echo "export PULL_PASS=$PULL_PASS" >> .pull-token
  fi
fi


# ask if we should start kind
read -p "A Kubernetes cluster is required, do you want to start a new Kind cluster? (YES/no): " START_KIND
START_KIND=${START_KIND:-yes}
if [ "$START_KIND" == "yes" ]; then
  kind create cluster --name harbor --config kind/config.yaml
  kubectl wait --for=condition=Ready node/harbor-control-plane --timeout=1m
fi

kubectl create ns harbor


# if using Chainguard images, ask for the registry URL (default is cgr.dev/cs-ttt-demo.dev )
if [ "$CHAINGUARD_IMAGES" == "yes" ]; then
  DEPLOY_DIR="cg"
  export REGISTRY_URL="cgr.dev/${ORG_NAME}"

  cat ${DEPLOY_DIR}/manifests/deploy-ingress-nginx.template | envsubst > ${DEPLOY_DIR}/manifests/deploy-ingress-nginx.yaml
  kubectl create ns ingress-nginx
  kubectl create secret docker-registry regcred --docker-server "cgr.dev" --docker-username $PULL_USER --docker-password $PULL_PASS -n ingress-nginx

  cat ${DEPLOY_DIR}/helm/values.template | envsubst > ${DEPLOY_DIR}/helm/values.yaml
  kubectl create secret docker-registry regcred --docker-server "cgr.dev" --docker-username $PULL_USER --docker-password $PULL_PASS -n harbor

fi

kubectl apply -f ${DEPLOY_DIR}/manifests/deploy-ingress-nginx.yaml
kubectl wait --for=condition=Ready -n ingress-nginx pod --selector=app.kubernetes.io/name=ingress-nginx --selector=app.kubernetes.io/component=controller

helm repo add harbor https://helm.goharbor.io
helm upgrade --install harbor harbor/harbor -n harbor -f ${DEPLOY_DIR}/helm/values.yaml --wait

cat terraform/terraform.templatevars | envsubst > terraform/terraform.tfvars
echo "Harbor should now available at http://localhost/harbor"

