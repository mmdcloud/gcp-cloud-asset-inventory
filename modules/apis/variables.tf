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