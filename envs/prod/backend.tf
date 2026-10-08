terraform {
  backend "gcs" {
    bucket = "REPLACE-tfstate-bucket"
    prefix = "cloud-asset-inventory/prod"
  }
}