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