# Import des buckets existants
data "google_storage_bucket" "inventory_bucket" {
  name = var.data_bucket
}

data "google_storage_bucket" "function_source_bucket" {
  name = var.function_bucket
}

# Import du service account runtime
data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
  project    = var.project_id
}

# Numéro de projet (pour Cloud Build SA)
data "google_project" "current" {
  project_id = var.project_id
}

# Import des topics Pub/Sub existants
data "google_pubsub_topic" "csv_success_topic" {
  project = var.project_id
  name    = "csv-success-topic"
}

data "google_pubsub_topic" "csv_error_topic" {
  project = var.project_id
  name    = "csv-error-topic"
}
