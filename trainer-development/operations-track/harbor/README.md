# Harbor

This is an example of syncing Chainguard images to a Harbor instance.

It demonstrates two approaches:

| Approach    | Description                                                          |
| ----------- | -------------------------------------------------------------------- |
| Proxy Cache | Configure a 'Project' as a pull through cache for images in cgr.dev. |
| Replication | Mirror images from cgr.dev using a Replication Rule.                 |

## Requirements

These instructions assume you are running on MacOS and you have the following
tools installed.

- `chainctl`
- `docker`
- `kind`
- `kubectl`
- `helm`
- `terraform`

## Instructions

### Deploy Harbor

Stand up a Harbor instance in a local `kind` cluster.

First, create the cluster with the provided `kind` configuration.

```
kind create cluster --config ./kind/config.yaml
```

Then, install the NGINX ingress controller.

```
kubectl apply -f ./manifests/deploy-ingress-nginx.yaml
```

Finally, install Harbor with Helm. Use the custom values in this folder.

```
helm repo add harbor https://helm.goharbor.io
helm upgrade --install harbor harbor/harbor -n harbor -f ./helm/values.yaml --create-namespace
```

The UI should eventually become available at http://localhost/harbor.

Login as `admin` with the default password `Harbor12345`.

### Generate Pull Token

Generate a pull token in your organization. We will use this later to allow
Harbor to connect to your Chainguard registry.

```
chainctl auth configure-docker --parent {org_name} --pull-token
```

Save the username and password (token) from the example command somewhere.

### Terraform Configuration

You can use the provided `terraform` module to quickly configure the Harbor
instance.

Populate `./terraform/terraform.tfvars` with your organization name and the pull
token credentials.

```
# terraform.tfvars
chainguard_organization_name = "ORGANIZATION_NAME"
chainguard_username          = "USERNAME"
chainguard_pull_token        = "PULL_TOKEN"
```

Apply the `terraform` module to setup the Proxy Cache Project and Replication
Rule in Harbor.

```
cd terraform/
terraform init
terraform apply -var-file=terraform.tfvars
```

## Demonstration

### Proxy Cache

Pull an image from the `cgr-proxy` project.

```
docker pull localhost:80/cgr-proxy/{ORG_NAME}/python:latest
```

Vist http://localhost/harbor/projects. You should see the image under the
`cgr-proxy` project.

### Replication Rule

Visit http://localhost/harbor/replications.

Select the `cgr-mirror` replication rule.

There may already be an execution in progress under `Executions`. If not, select
`Replicate` and kick one off.

Visit http://localhost/harbor/projects. Observe images populating under the
`cgr-mirror` project.

Pull a replicated image from the `cgr-mirror` project:

```
docker pull localhost:80/cgr-mirror/python:latest
```

## Cleanup

Tear down the `kind` cluster.

```
kind delete cluster
```

Remove the terraform state and `.terraform` directory.

```
rm -rf ./terraform/.terraform
rm ./terraform/terraform.tfstate*
```
