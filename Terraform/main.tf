terraform {
  required_version = ">= 1.0"
}

##################################
# 1) Activer les APIs nécessaires
##################################
resource "google_project_service" "bigquery_api" {
  project = var.project_id
  service = "bigquery.googleapis.com"
}

resource "google_project_service" "storage_api" {
  project = var.project_id
  service = "storage.googleapis.com"
}

resource "google_project_service" "cloudfunctions_api" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "composer_api" {
  project = var.project_id
  service = "composer.googleapis.com"
}

##################################
# 2) Création (ou import) du Dataset BigQuery
##################################
resource "google_bigquery_dataset" "inventory_dataset" {
  project    = var.project_id
  dataset_id = var.bq_dataset_id
  location   = var.location

  lifecycle {
    ignore_changes = [dataset_id]
  }

  depends_on = [
    google_project_iam_binding.cb_bq_admin,
  ]
}

##################################
# 3) Création du nouveau bucket GCS tmt-storage-02
##################################
resource "google_storage_bucket" "new_data_bucket" {
  name          = "tmt-storage-02"
  project       = var.project_id
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
    ignore_changes = [name]
  }
}

##################################
# 4) Packaging et upload de la Cloud Function
##################################
data "archive_file" "csv_validator_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../cloud_function"
  output_path = "${path.module}/csv_validator.zip"
}

resource "google_storage_bucket_object" "csv_validator_zip" {
  bucket = google_storage_bucket.new_data_bucket.name  # Utilise le nouveau bucket
  name   = "csv_validator.zip"
  source = data.archive_file.csv_validator_zip.output_path

  depends_on = [
    google_project_iam_binding.tf_storage_admin,
  ]
}

##################################
# 5) Déploiement (ou import) de la Cloud Function
##################################
resource "google_cloudfunctions_function" "csv_validator" {
  name                  = var.function_name
  runtime               = var.function_runtime
  region                = var.region
  entry_point           = var.function_entry
  service_account_email = data.google_service_account.dataloader_sa.email

  source_archive_bucket = google_storage_bucket.new_data_bucket.name  # Nouveau bucket
  source_archive_object = google_storage_bucket_object.csv_validator_zip.name

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.new_data_bucket.name  # Trigger sur nouveau bucket
  }

  depends_on = [
    google_project_iam_binding.tf_cf_admin,
    google_service_account_iam_member.cb_actas_dataloader,
  ]
}

##################################
# 6) Environnement Composer
##################################
resource  "google_composer_environment" "composer_env" {
  project = var.project_id
  region  = var.region
  name    = "composer-env-wael"

  config {
    node_config {
      service_account = data.google_service_account.dataloader_sa.email
    }
    software_config {
      image_version = "composer-2.13.4-airflow-2.10.5"
    }
    
    environment_size = "ENVIRONMENT_SIZE_SMALL"

  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [name]
  }

  depends_on = [
    google_service_account_iam_member.cb_actas_dataloader,
  ]
}
