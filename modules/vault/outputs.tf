output "bucket" {
  value = google_storage_bucket.conf.name
}

output "gsa" {
  value = google_service_account.cr-gsa.name
}
