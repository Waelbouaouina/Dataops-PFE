##############################
# Buckets & topics existants
##############################

data "google_storage_bucket" "inventory_bucket" {
  name = var.data_bucket
}

data "google_storage_bucket" "function_source_bucket" {
  name = var.function_bucket
}

data "google_pubsub_topic" "csv_success_topic" {
  project = var.project_id
  name    = "csv-success-topic"
}

data "google_pubsub_topic" "csv_error_topic" {
  project = var.project_id
  name    = "csv-error-topic"
}

##############################
# Import du Service Account dataloader-sa
##############################

data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
  project    = var.project_id
}

##############################
# Numéro de projet pour Composer
##############################

data "google_project" "current" {}
