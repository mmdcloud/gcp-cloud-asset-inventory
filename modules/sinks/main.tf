variable "project_id" { type = string }
variable "location" { type = string }
variable "dataset_id" { type = string }
variable "bucket_name" { type = string }
variable "retention_days" { type = number }
variable "labels" { type = map(string) }

resource "google_bigquery_dataset" "inventory" {
  project                         = var.project_id
  dataset_id                      = var.dataset_id
  location                        = var.location
  description                     = "Cloud Asset Inventory exports and real-time feed events"
  delete_contents_on_destroy      = false
  default_partition_expiration_ms = var.retention_days * 24 * 60 * 60 * 1000
  labels                          = var.labels
}

# Long-term snapshot archive. Scheduler overwrites a fixed object path;
# versioning keeps every prior snapshot as a noncurrent version.
resource "google_storage_bucket" "archive" {
  project                     = var.project_id
  name                        = var.bucket_name
  location                    = var.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = var.labels

  versioning { enabled = true }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
      with_state                 = "ARCHIVED"
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 2555
      with_state                 = "ARCHIVED"
    }
    action { type = "Delete" }
  }
}

output "dataset_id" { value = google_bigquery_dataset.inventory.dataset_id }
output "bucket_name" { value = google_storage_bucket.archive.name }
