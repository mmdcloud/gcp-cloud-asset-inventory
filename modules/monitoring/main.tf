variable "project_id" { type = string }
variable "notification_emails" { type = list(string) }
variable "dlq_subscription" { type = string }

resource "google_monitoring_notification_channel" "email" {
  for_each     = toset(var.notification_emails)
  project      = var.project_id
  display_name = "CAI alerts - ${each.key}"
  type         = "email"
  labels       = { email_address = each.key }
}

locals {
  channels = [for c in google_monitoring_notification_channel.email : c.id]
}

resource "google_monitoring_alert_policy" "dlq_backlog" {
  project               = var.project_id
  display_name          = "CAI feed: messages in dead-letter queue"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "DLQ undelivered messages > 0"
    condition_threshold {
      filter          = "resource.type=\"pubsub_subscription\" AND resource.labels.subscription_id=\"${var.dlq_subscription}\" AND metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "export_failure" {
  project               = var.project_id
  display_name          = "CAI export: Cloud Scheduler job failed"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "Scheduler job error log"
    condition_matched_log {
      filter = "resource.type=\"cloud_scheduler_job\" AND resource.labels.job_id:\"cai-export-\" AND severity>=ERROR"
    }
  }

  alert_strategy {
    notification_rate_limit { period = "3600s" }
  }
}
