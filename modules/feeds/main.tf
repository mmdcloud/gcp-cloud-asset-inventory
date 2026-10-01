terraform {
  required_providers {
    google      = { source = "hashicorp/google" }
    google-beta = { source = "hashicorp/google-beta" }
  }
}

variable "project_id" { type = string }
variable "dataset_id" { type = string }
variable "retention_days" { type = number }
variable "labels" { type = map(string) }

variable "feeds" {
  type = map(object({
    scope_type           = string # organization | folder | project
    scope_id             = string
    content_type         = optional(string, "RESOURCE")
    asset_types          = optional(list(string), [".*"])
    asset_names          = optional(list(string), [])
    relationship_types   = optional(list(string), [])
    condition_expression = optional(string)
    condition_title      = optional(string, "feed filter")
  }))
  default = {}

  validation {
    condition     = alltrue([for f in values(var.feeds) : contains(["organization", "folder", "project"], f.scope_type)])
    error_message = "scope_type must be organization, folder or project."
  }
}

# Service agents must exist before IAM bindings can reference them.
resource "google_project_service_identity" "cloudasset" {
  provider = google-beta
  project  = var.project_id
  service  = "cloudasset.googleapis.com"
}

resource "google_project_service_identity" "pubsub" {
  provider = google-beta
  project  = var.project_id
  service  = "pubsub.googleapis.com"
}

locals {
  cai_agent    = "serviceAccount:${google_project_service_identity.cloudasset.email}"
  pubsub_agent = "serviceAccount:${google_project_service_identity.pubsub.email}"
}

# ---- Pub/Sub plumbing ----
resource "google_pubsub_topic" "feed" {
  project                    = var.project_id
  name                       = "cai-feed"
  message_retention_duration = "604800s"
  labels                     = var.labels
}

resource "google_pubsub_topic" "dlq" {
  project                    = var.project_id
  name                       = "cai-feed-dlq"
  message_retention_duration = "604800s"
  labels                     = var.labels
}

resource "google_bigquery_table" "events" {
  project             = var.project_id
  dataset_id          = var.dataset_id
  table_id            = "feed_events"
  deletion_protection = true
  labels              = var.labels

  time_partitioning {
    type          = "DAY"
    field         = "publish_time"
    expiration_ms = var.retention_days * 24 * 60 * 60 * 1000
  }

  schema = jsonencode([
    { name = "subscription_name", type = "STRING", mode = "NULLABLE" },
    { name = "message_id", type = "STRING", mode = "NULLABLE" },
    { name = "publish_time", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "data", type = "JSON", mode = "NULLABLE" },
    { name = "attributes", type = "JSON", mode = "NULLABLE" },
  ])
}

resource "google_pubsub_subscription" "bq" {
  project                    = var.project_id
  name                       = "cai-feed-to-bq"
  topic                      = google_pubsub_topic.feed.id
  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  labels                     = var.labels

  expiration_policy { ttl = "" } # never expire

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 5
  }

  bigquery_config {
    table          = "${var.project_id}.${var.dataset_id}.${google_bigquery_table.events.table_id}"
    write_metadata = true
  }

  depends_on = [
    google_bigquery_dataset_iam_member.pubsub_writer,
    google_project_iam_member.pubsub_meta,
  ]
}

resource "google_pubsub_subscription" "dlq_pull" {
  project                    = var.project_id
  name                       = "cai-feed-dlq-pull"
  topic                      = google_pubsub_topic.dlq.id
  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  labels                     = var.labels

  expiration_policy { ttl = "" }
}

# ---- IAM ----
resource "google_pubsub_topic_iam_member" "cai_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.feed.name
  role    = "roles/pubsub.publisher"
  member  = local.cai_agent
}

resource "google_bigquery_dataset_iam_member" "pubsub_writer" {
  project    = var.project_id
  dataset_id = var.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.pubsub_agent
}

resource "google_project_iam_member" "pubsub_meta" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = local.pubsub_agent
}

resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "bq_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.bq.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

# ---- Feeds (one resource type per scope) ----
resource "google_cloud_asset_organization_feed" "this" {
  for_each           = { for k, f in var.feeds : k => f if f.scope_type == "organization" }
  billing_project    = var.project_id
  org_id             = each.value.scope_id
  feed_id            = each.key
  content_type       = each.value.content_type
  asset_types        = each.value.asset_types
  asset_names        = each.value.asset_names
  relationship_types = each.value.relationship_types

  feed_output_config {
    pubsub_destination { topic = google_pubsub_topic.feed.id }
  }

  dynamic "condition" {
    for_each = each.value.condition_expression == null ? [] : [1]
    content {
      expression = each.value.condition_expression
      title      = each.value.condition_title
    }
  }

  depends_on = [google_pubsub_topic_iam_member.cai_publisher]
}

resource "google_cloud_asset_folder_feed" "this" {
  for_each           = { for k, f in var.feeds : k => f if f.scope_type == "folder" }
  billing_project    = var.project_id
  folder             = each.value.scope_id
  feed_id            = each.key
  content_type       = each.value.content_type
  asset_types        = each.value.asset_types
  asset_names        = each.value.asset_names
  relationship_types = each.value.relationship_types

  feed_output_config {
    pubsub_destination { topic = google_pubsub_topic.feed.id }
  }

  dynamic "condition" {
    for_each = each.value.condition_expression == null ? [] : [1]
    content {
      expression = each.value.condition_expression
      title      = each.value.condition_title
    }
  }

  depends_on = [google_pubsub_topic_iam_member.cai_publisher]
}

resource "google_cloud_asset_project_feed" "this" {
  for_each           = { for k, f in var.feeds : k => f if f.scope_type == "project" }
  billing_project    = var.project_id
  project            = each.value.scope_id
  feed_id            = each.key
  content_type       = each.value.content_type
  asset_types        = each.value.asset_types
  asset_names        = each.value.asset_names
  relationship_types = each.value.relationship_types

  feed_output_config {
    pubsub_destination { topic = google_pubsub_topic.feed.id }
  }

  dynamic "condition" {
    for_each = each.value.condition_expression == null ? [] : [1]
    content {
      expression = each.value.condition_expression
      title      = each.value.condition_title
    }
  }

  depends_on = [google_pubsub_topic_iam_member.cai_publisher]
}

output "topic_id" { value = google_pubsub_topic.feed.id }
output "dlq_subscription" { value = google_pubsub_subscription.dlq_pull.name }
