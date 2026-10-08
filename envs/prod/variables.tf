variable "org_id" { type = string }
variable "project_id" { type = string }

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "bq_location" {
  description = "BigQuery dataset / GCS bucket location"
  type        = string
  default     = "asia-south1"
}

variable "retention_days" {
  type    = number
  default = 365
}

variable "alert_emails" { type = list(string) }

variable "export_jobs" {
  type = map(object({
    content_type       = string
    schedule           = string
    destination        = optional(string, "bigquery")
    asset_types        = optional(list(string), [])
    relationship_types = optional(list(string), [])
    separate_tables    = optional(bool, false)
  }))
  default = {
    resource      = { content_type = "RESOURCE", schedule = "0 1 * * *", separate_tables = true }
    iam_policy    = { content_type = "IAM_POLICY", schedule = "15 1 * * *" }
    org_policy    = { content_type = "ORG_POLICY", schedule = "30 1 * * *" }
    access_policy = { content_type = "ACCESS_POLICY", schedule = "45 1 * * *" }
    os_inventory  = { content_type = "OS_INVENTORY", schedule = "0 2 * * *" }
    relationship = {
      content_type = "RELATIONSHIP"
      schedule     = "15 2 * * *"
      asset_types  = ["compute.googleapis.com/Instance", "compute.googleapis.com/Disk"]
    }
    resource_archive = { content_type = "RESOURCE", schedule = "0 3 * * 0", destination = "gcs" }
  }
}

variable "feeds" {
  type = map(object({
    scope_type           = string
    scope_id             = string
    content_type         = optional(string, "RESOURCE")
    asset_types          = optional(list(string), [".*"])
    asset_names          = optional(list(string), [])
    relationship_types   = optional(list(string), [])
    condition_expression = optional(string)
    condition_title      = optional(string, "feed filter")
  }))
  default = {}
}

variable "saved_queries" {
  type = map(object({
    description = optional(string, "")
    query       = any
  }))
  default = {}
}