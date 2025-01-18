data "google_storage_bucket" "conf" {
  name    = "${var.project}-vault-conf"
  project = var.project
}

resource "google_storage_bucket_object" "conf" {
  name   = "agent.hcl"
  source = "${path.module}/agent.hcl"
  bucket = data.google_storage_bucket.conf.name
}
