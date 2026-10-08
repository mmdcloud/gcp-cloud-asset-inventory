output "dataset_id" { value = google_bigquery_dataset.inventory.dataset_id }
output "bucket_name" { value = google_storage_bucket.archive.name }