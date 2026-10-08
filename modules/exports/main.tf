
locals {
  output_config = {
    for k, j in var.jobs : k => j.destination == "bigquery" ? jsonencode({
      bigqueryDestination = {
        dataset                    = "projects/${var.project_id}/datasets/${var.dataset_id}"
        table                      = k
        force                      = true # overwrite same-day partition on re-run
        separateTablesPerAssetType = j.separate_tables
        partitionSpec              = { partitionKey = "REQUEST_TIME" }
      }
      }) : jsonencode({
      gcsDestination = { uri = "gs://${var.bucket_name}/${k}/${lower(j.content_type)}.json" }
    })
  }

  body = {
    for k, j in var.jobs : k => jsonencode(merge(
      {
        contentType  = j.content_type
        outputConfig = jsondecode(local.output_config[k])
      },
      length(j.asset_types) > 0 ? { assetTypes = j.asset_types } : {},
      length(j.relationship_types) > 0 ? { relationshipTypes = j.relationship_types } : {},
    ))
  }
}

resource "google_service_account" "exporter" {
  project      = var.project_id
  account_id   = "cai-exporter"
  display_name = "Cloud Asset Inventory scheduled exporter"
}

resource "google_organization_iam_member" "viewer" {
  org_id = var.org_id
  role   = "roles/cloudasset.viewer"
  member = "serviceAccount:${google_service_account.exporter.email}"
}

resource "google_project_iam_member" "bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.exporter.email}"
}

resource "google_bigquery_dataset_iam_member" "writer" {
  project    = var.project_id
  dataset_id = var.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.exporter.email}"
}

resource "google_storage_bucket_iam_member" "writer" {
  bucket = var.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.exporter.email}"
}

resource "google_cloud_scheduler_job" "export" {
  for_each         = var.jobs
  project          = var.project_id
  region           = var.region
  name             = "cai-export-${replace(each.key, "_", "-")}"
  description      = "exportAssets ${each.value.content_type} -> ${each.value.destination}"
  schedule         = each.value.schedule
  time_zone        = "UTC"
  attempt_deadline = "180s"

  retry_config {
    retry_count          = 3
    min_backoff_duration = "30s"
    max_backoff_duration = "600s"
  }

  http_target {
    http_method = "POST"
    uri         = "https://cloudasset.googleapis.com/v1/organizations/${var.org_id}:exportAssets"
    headers     = { "Content-Type" = "application/json" }
    body        = base64encode(local.body[each.key])

    oauth_token {
      service_account_email = google_service_account.exporter.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_organization_iam_member.viewer,
    google_project_iam_member.bq_job_user,
    google_bigquery_dataset_iam_member.writer,
    google_storage_bucket_iam_member.writer,
  ]
}