##############################
# Providers & APIs
##############################

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "bigquery_api" {
  project = var.project_id
  service = "bigquery.googleapis.com"
}
resource "google_project_service" "pubsub_api" {
  project = var.project_id
  service = "pubsub.googleapis.com"
}
resource "google_project_service" "run_api" {
  project = var.project_id
  service = "run.googleapis.com"
}
resource "google_project_service" "cloudfunctions_api" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
}
resource "google_project_service" "composer_api" {
  project = var.project_id
  service = "composer.googleapis.com"
}

##############################
# Data sources – EXISTANTS
##############################

data "google_storage_bucket" "inventory_bucket" {
  name = var.data_bucket
}

data "google_storage_bucket" "function_source_bucket" {
  name = var.function_bucket
}

data "google_service_account" "dataloader_sa" {
  project    = var.project_id
  account_id = "dataloader-sa"
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
# Cloud Function: packaging & deploy
##############################

resource "google_storage_bucket_object" "csv_validator_zip" {
  name   = "csv_validator.zip"
  bucket = data.google_storage_bucket.function_source_bucket.name
  source = "${path.module}/../cloud_function/csv_validator.zip"
}

resource "google_cloudfunctions_function" "csv_validator" {
  name        = "csv-validator"
  runtime     = "python39"
  region      = var.region
  entry_point = "validate_csv"

  source_archive_bucket = data.google_storage_bucket.function_source_bucket.name
  source_archive_object = google_storage_bucket_object.csv_validator_zip.name

  service_account_email = data.google_service_account.dataloader_sa.email

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = data.google_storage_bucket.inventory_bucket.name
  }

  environment_variables = {
    SUCCESS_TOPIC = data.google_pubsub_topic.csv_success_topic.id
    ERROR_TOPIC   = data.google_pubsub_topic.csv_error_topic.id
  }
}

##############################
# BigQuery Tables (to create)
##############################

resource "google_bigquery_table" "raw_table" {
  dataset_id = var.bq_dataset_id
  table_id   = "raw_table"
  schema     = file("${path.module}/schemas/raw_table.json")
}

resource "google_bigquery_table" "tds_table" {
  dataset_id = var.bq_dataset_id
  table_id   = "tds_table"
  schema     = file("${path.module}/schemas/tds_table.json")
}

resource "google_bigquery_table" "bds_table" {
  dataset_id = var.bq_dataset_id
  table_id   = "bds_table"
  schema     = file("${path.module}/schemas/bds_table.json")
}

##############################
# Cloud Run – Dataloader
##############################

resource "google_cloud_run_service" "dataloader_service" {
  name     = "dataloader-service"
  location = var.region

  template {
    spec {
      service_account_name = data.google_service_account.dataloader_sa.email

      containers {
        image = "gcr.io/${var.project_id}/dataloader-image:latest"
        env {
          name  = "BUCKET_NAME"
          value = data.google_storage_bucket.inventory_bucket.name
        }
        env {
          name  = "BQ_DATASET"
          value = var.bq_dataset_id
        }
        env {
          name  = "BQ_TABLE"
          value = google_bigquery_table.raw_table.table_id
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

##############################
# Composer v2 – Environment
##############################

resource "google_composer_environment" "composer_env" {
  project = var.project_id
  name    = "composer-environment"
  region  = var.region

  config {
    node_config {
      service_account = data.google_service_account.dataloader_sa.email
    }
    software_config {
      image_version = "composer-2.13.4-airflow-2.10.5"
    }
  }
}

output "composer_dag_bucket" {
  value       = google_composer_environment.composer_env.config[0].dag_gcs_prefix
  description = "Bucket pour déposer les DAGs"
}
