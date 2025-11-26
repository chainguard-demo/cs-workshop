variable "chainguard_username" {
  type        = string
  description = "Username associated with the pull token"
}

variable "chainguard_pull_token" {
  type        = string
  description = "Pull token value"
}

variable "chainguard_organization_name" {
  type        = string
  description = "Name of the organization to mirror images from"
}