terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.20.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "6.20.0"
    }
  }
}

data "google_service_account" "service_account" {
  account_id = var.gsa
  project    = var.project
}

data "docker_registry_image" "image" {
  count = length(var.containers)
  name  = var.containers[count.index].image
}

resource "google_cloud_run_v2_service" "cloudrun" {
  for_each     = toset(var.regions)
  name         = var.name
  location     = each.value
  launch_stage = "BETA"
  project      = var.project

  lifecycle {
    create_before_destroy = true
  }

  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    service_account = data.google_service_account.service_account.email

    dynamic "containers" {
      for_each = var.containers
      content {
        image   = format("%s@%s", containers.value.image, data.docker_registry_image.image[containers.key].sha256_digest)
        name    = containers.value.name
        command = containers.value.command
        args    = containers.value.args
        dynamic "ports" {
          for_each = containers.value.port != 0 ? [containers.value.port] : []
          content {
            container_port = ports.value
          }
        }

        dynamic "liveness_probe" {
          for_each = containers.value.liveness_probe != "" ? [containers.value.liveness_probe] : []
          content {
            http_get {
              path = liveness_probe.value
            }
            period_seconds    = 300
            failure_threshold = 1
          }
        }

        dynamic "env" {
          for_each = concat(
            [
              for secret in var.secrets : {
                name = secret.name
                value_source = {
                  secret_key_ref = {
                    secret  = secret.secret_name
                    version = "latest"
                  }
                }
              }
            ],
            [
              for env_var in var.addl_env_vars : {
                name  = env_var.name
                value = env_var.value
              }
            ]
          )
          content {
            name  = env.value.name
            value = try(env.value.value, null)

            dynamic "value_source" {
              for_each = try([env.value.value_source], [])
              content {
                secret_key_ref {
                  secret  = value_source.value.secret
                  version = value_source.value.version
                }
              }
            }
          }
        }

        dynamic "volume_mounts" {
          for_each = containers.value.volume_mounts
          content {
            name       = volume_mounts.value.name
            mount_path = volume_mounts.value.mount_path
          }
        }

        resources {
          cpu_idle = containers.value.gpus == ""
          limits = merge(
            {
              memory = containers.value.memory,
              cpu    = containers.value.cpu
            },
            containers.value.gpus != "" ? {
              "nvidia.com/gpu" = containers.value.gpus
            } : {}
          )
        }
      }
    }
    dynamic "volumes" {
      for_each = var.empty_dir_volumes
      content {
        name = volumes.value.name
        empty_dir {
          medium     = "MEMORY"
          size_limit = volumes.value.size_limit
        }
      }
    }
    dynamic "volumes" {
      for_each = var.gcs_volumes
      content {
        name = volumes.value.name
        gcs {
          bucket    = volumes.value.bucket
          read_only = volumes.value.read_only
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = toset(var.regions)
  location = each.value
  name     = google_cloud_run_v2_service.cloudrun[each.value].name
  project  = var.project
  role     = "roles/run.invoker"
  member   = "allUsers"
}
