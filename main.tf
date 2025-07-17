terraform {
  required_version = "= 1.5.7"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.2"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.44.0"
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
  registry_auth {
    address     = "us-docker.pkg.dev"
    config_file = pathexpand("~/.docker/config.json")
  }
}

module "vault" {
  source  = "./modules/vault"
  project = var.project
  name    = "ghat"
}

data "docker_registry_image" "image" {
  name = "us-docker.pkg.dev/${var.project}/private/ghat:main"
}

module "ghat" {
  source = "git::https://github.com/libops/terraform-cloudrun-v2?ref=0.1.2"

  name    = "ghat"
  project = var.project
  gsa     = module.vault.gsa
  containers = [
    {
      name           = "ghat",
      image          = format("%s@%s", data.docker_registry_image.image.name, data.docker_registry_image.image.sha256_digest)
      port           = 8080,
      liveness_probe = "/healthcheck",
      memory         = "512Mi",
      cpu            = "1000m",
      volume_mounts = [
        {
          name       = "vault-secrets",
          mount_path = "/vault/secrets"
        }
      ]
    },
    {
      name   = "vault",
      image  = "hashicorp/vault:1.18.3@sha256:8f1ba670da547c6af67be55609bd285c3ee3d8b73f88021adbfc43c82ca409e8",
      memory = "512Mi",
      cpu    = "500m",
      args = [
        "agent",
        "-config=/etc/vault/agent.hcl"
      ],
      volume_mounts = [
        {
          name       = "vault-secrets",
          mount_path = "/vault/secrets"
        },
        {
          name       = "vault-config",
          mount_path = "/etc/vault"
        },
      ]
    }
  ]
  empty_dir_volumes = [
    {
      name = "vault-secrets"
    }
  ]
  gcs_volumes = [
    {
      name   = "vault-config"
      bucket = module.vault.bucket
    }
  ]

  addl_env_vars = tolist([
    {
      name  = "GITHUB_APP_ID"
      value = var.gh_app_id
    },
    {
      name  = "GITHUB_INSTALL_ID"
      value = var.gh_install_id
    },
    {
      name  = "GITHUB_APP_PRIVATE_KEY"
      value = "/vault/secrets/gha-private.pem"
    },
    {
      name  = "VAULT_ADDR"
      value = var.vault_addr
    }
  ])
  providers = {
    google = google.default
  }
}
