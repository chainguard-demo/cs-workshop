terraform {
  required_providers {
    harbor = { source = "goharbor/harbor" }
  }
}

provider "harbor" {
  url      = "http://localhost"
  username = "admin"
  password = "Harbor12345"
}

resource "harbor_registry" "cgr_dev" {
  provider_name = "docker-registry"
  name          = "cgr.dev"
  endpoint_url  = "https://cgr.dev"
  access_id     = var.chainguard_username
  access_secret = var.chainguard_pull_token
}

resource "harbor_project" "cgr_proxy" {
  name        = "cgr-proxy"
  public      = true
  registry_id = harbor_registry.cgr_dev.registry_id
}

resource "harbor_project" "cgr_mirror" {
  name   = "cgr-mirror"
  public = true
}

resource "harbor_replication" "cgr_mirror" {
  name        = "cgr-mirror"
  action      = "pull"
  registry_id = harbor_registry.cgr_dev.registry_id

  schedule = "manual"

  dest_namespace = "cgr-mirror"

  # A value of -1 will 'Flatten All Levels', which removes the source repository
  # path, leaving only the image base name.
  #
  # For instance:
  #   cgr.dev/org_name/python -> harbor.example.com/cgr-mirror/python
  dest_namespace_replace = -1

  filters {
    name = "${var.chainguard_organization_name}/*"
  }
}
