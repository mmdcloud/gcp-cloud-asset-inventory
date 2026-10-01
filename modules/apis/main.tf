variable "project_id" { type = string }

variable "services" {
  type = set(string)
  default = [
    "cloudasset.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudscheduler.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
}

resource "google_project_service" "this" {
  for_each           = var.services
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

output "enabled" { value = keys(google_project_service.this) }
