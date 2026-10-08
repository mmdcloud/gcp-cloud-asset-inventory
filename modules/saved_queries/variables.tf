variable "project_id" { type = string }

variable "saved_queries" {
  description = "Saved IAM policy analysis queries. `query` is an iamPolicyAnalysisQuery object (camelCase, REST format)."
  type = map(object({
    description = optional(string, "")
    query       = any
  }))
  default = {}
}