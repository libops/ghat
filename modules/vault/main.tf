resource "google_storage_bucket" "conf" {
  project                     = var.project
  name                        = "${var.project}-vault-config"
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_service_account" "cr-gsa" {
  project    = var.project
  account_id = "${var.name}-cr"
}

resource "google_artifact_registry_repository_iam_member" "ghat-cr" {
  project    = var.project
  location   = "us"
  repository = "private"
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.cr-gsa.email}"
}

resource "google_project_iam_member" "cr-token-creator" {
  project = var.project
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.cr-gsa.email}"
}

resource "google_storage_bucket_iam_member" "conf-admin" {
  bucket = google_storage_bucket.conf.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cr-gsa.email}"
}

resource "google_storage_bucket_object" "conf" {
  name   = "agent.hcl"
  source = "${path.module}/agent.hcl"
  bucket = google_storage_bucket.conf.name
}

// allow the vault server identity permissions needed for vault gcp auth
resource "google_project_iam_member" "vault-server" {
  project = var.project
  role    = "roles/iam.serviceAccountKeyAdmin"
  member  = "serviceAccount:vault-server@libops-vault.iam.gserviceaccount.com"
}
