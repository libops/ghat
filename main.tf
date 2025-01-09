variable "project" {
  type        = string
  description = "The GCP project to deploy to"
}

terraform {
  required_version = "= 1.5.7"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "= 3.0.1"
    }
    github = {
      source  = "integrations/github"
      version = "= 6.2.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "= 6.15.0"
    }
  }

  backend "gcs" {
    bucket = "libops-ghat-terraform"
    prefix = "/github"
  }
}


provider "google" {
  alias   = "default"
  project = var.project
}

provider "docker" {
  alias = "local"
  registry_auth {
    address     = "us-docker.pkg.dev"
    config_file = pathexpand("~/.docker/config.json")
  }
}

module "ghat" {
  source = "./modules/cloudrun"

  name    = "ghat"
  project = var.project
  containers = tolist([
    {
      name           = "ghat",
      image          = "us-docker.pkg.dev/${var.project}/private/ghat:main",
      port           = 8080
      liveness_probe = "/healthcheck"
      memory         = "512Mi"
      cpu            = "1000m"
    }
  ])
  providers = {
    google = google.default
    docker = docker.local
  }
}
