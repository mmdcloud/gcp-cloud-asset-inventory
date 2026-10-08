resource "google_bigquery_dataset" "inventory" {
  project                         = var.project_id
  dataset_id                      = var.dataset_id
  location                        = var.location
  description                     = "Cloud Asset Inventory exports and real-time feed events"
  delete_contents_on_destroy      = false
  default_partition_expiration_ms = var.retention_days * 24 * 60 * 60 * 1000
  labels                          = var.labels
}

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