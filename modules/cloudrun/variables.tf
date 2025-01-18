variable "name" {
  type = string
}

variable "gsa" {
  type = string
}

variable "min_instances" {
  type    = string
  default = "0"
}
variable "max_instances" {
  type    = string
  default = "5"
}

variable "regions" {
  type        = list(string)
  description = "The GCP region(s) to deploy to"
  default = [
    "us-east5",
  ]
}

variable "project" {
  type        = string
  description = "The GCP project to use"
}

variable "secrets" {
  type = list(object({
    name        = string
    secret_id   = string
    secret_name = string
  }))
  default = []
}

variable "containers" {
  type = list(object({
    image          = string
    name           = string
    command        = optional(list(string), null)
    args           = optional(list(string), null)
    port           = optional(number, 0)
    memory         = optional(string, "512Mi")
    cpu            = optional(string, "1000m")
    liveness_probe = optional(string, "")
    gpus           = optional(string, "")
    volume_mounts = optional(list(object({
      name       = string
      mount_path = string
    })), [])
  }))
}

variable "empty_dir_volumes" {
  type = list(object({
    name       = string
    size_limit = optional(string, "2Mi")
  }))
  default = []
}


variable "gcs_volumes" {
  type = list(object({
    name      = string
    bucket    = string
    read_only = optional(bool, true)
  }))
  default = []
}


variable "addl_env_vars" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
