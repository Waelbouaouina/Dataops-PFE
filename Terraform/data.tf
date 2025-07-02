##############################
# Data sources – EXISTANTS
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
# Service Account – EXISTANT
##############################

data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"

  # <- garantit que le binding Terraform_sa_serviceaccount_viewer
  #    sera créé AVANT la lecture de ce data source
  depends_on = [
    google_project_iam_member.terraform_sa_serviceaccount_viewer
  ]
}
