locals {
  labels = {
    managed_by = "terraform"
    component  = "cloud-asset-inventory"
    env        = "prod"
  }
}

module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

module "sinks" {
  source         = "../../modules/sinks"
  project_id     = var.project_id
  location       = var.bq_location
  dataset_id     = "cloud_asset_inventory"
  bucket_name    = "${var.project_id}-cai-archive"
  retention_days = var.retention_days
  labels         = local.labels
  depends_on     = [module.apis]
}

module "exports" {
  source      = "../../modules/exports"
  project_id  = var.project_id
  region      = var.region
  org_id      = var.org_id
  dataset_id  = module.sinks.dataset_id
  bucket_name = module.sinks.bucket_name
  jobs        = var.export_jobs
  depends_on  = [module.apis]
}

module "feeds" {
  source         = "../../modules/feeds"
  project_id     = var.project_id
  dataset_id     = module.sinks.dataset_id
  retention_days = var.retention_days
  labels         = local.labels
  feeds          = var.feeds
  depends_on     = [module.apis]
}

module "monitoring" {
  source              = "../../modules/monitoring"
  project_id          = var.project_id
  notification_emails = var.alert_emails
  dlq_subscription    = module.feeds.dlq_subscription
  depends_on          = [module.apis]
}

module "saved_queries" {
  source        = "../../modules/saved_queries"
  project_id    = var.project_id
  saved_queries = var.saved_queries
  depends_on    = [module.apis]
}
