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

data "google_pubsub_topic" "csv_success_topic" {
  project = var.project_id
  name    = "csv-success-topic"
}

data "google_pubsub_topic" "csv_error_topic" {
  project = var.project_id
  name    = "csv-error-topic"
}

#  Composer Environment (si déjà créé manuellement)
data "google_composer_environment" "composer_env" {
  name    = "composer-env-wael"
  region  = var.region
  project = var.project_id
}

