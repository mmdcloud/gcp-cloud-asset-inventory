variable "project_id" { type = string }
variable "location" { type = string }
variable "dataset_id" { type = string }
variable "bucket_name" { type = string }
variable "retention_days" { type = number }
variable "labels" { type = map(string) }