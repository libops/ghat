variable "project" {
  type        = string
  description = "The GCP project to deploy to"
}

variable "vault_addr" {
  type        = string
  description = "The vault server address"
}

variable "gh_app_id" {
  type        = string
  description = "GitHub App ID"
}

variable "gh_install_id" {
  type        = string
  description = "GitHub Install ID"
}
