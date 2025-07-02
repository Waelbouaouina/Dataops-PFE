##############################
# Buckets & service account existants
##############################

data "google_storage_bucket" "inventory_bucket" {
  name = var.data_bucket
}

data "google_storage_bucket" "function_source_bucket" {
  name = var.function_bucket
}

data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
  project    = var.project_id
}

data "google_project" "current" {}
