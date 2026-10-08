variable "project_id" { type = string }
variable "region" { type = string }
variable "org_id" { type = string }
variable "dataset_id" { type = string }
variable "bucket_name" { type = string }

variable "jobs" {
  type = map(object({
    content_type       = string # RESOURCE | IAM_POLICY | ORG_POLICY | ACCESS_POLICY | OS_INVENTORY | RELATIONSHIP
    schedule           = string
    destination        = optional(string, "bigquery") # bigquery | gcs
    asset_types        = optional(list(string), [])
    relationship_types = optional(list(string), [])
    separate_tables    = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for j in values(var.jobs) : contains(["bigquery", "gcs"], j.destination)])
    error_message = "destination must be bigquery or gcs."
  }
  validation {
    condition = alltrue([for j in values(var.jobs) : contains(
      ["RESOURCE", "IAM_POLICY", "ORG_POLICY", "ACCESS_POLICY", "OS_INVENTORY", "RELATIONSHIP"], j.content_type)])
    error_message = "Invalid content_type."
  }
}