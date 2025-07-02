##############################
# Activer les APIs
##############################

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
# BigQuery Dataset
##############################

resource "google_bigquery_dataset" "inventory_dataset" {
  project    = var.project_id
  dataset_id = var.bq_dataset_id
  location   = var.location
}

##############################
# BigQuery Tables
##############################

resource "google_bigquery_table" "raw_table" {
  dataset_id = google_bigquery_dataset.inventory_dataset.dataset_id
  table_id   = "raw_table"
  schema     = file("${path.module}/schemas/raw_table.json")
}

resource "google_bigquery_table" "tds_table" {
  dataset_id = google_bigquery_dataset.inventory_dataset.dataset_id
  table_id   = "tds_table"
  schema     = file("${path.module}/schemas/tds_table.json")
}

resource "google_bigquery_table" "bds_table" {
  dataset_id = google_bigquery_dataset.inventory_dataset.dataset_id
  table_id   = "bds_table"
  schema     = file("${path.module}/schemas/bds_table.json")
}

##############################
# Cloud Function: packaging & deploy
##############################

data "archive_file" "csv_validator_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../cloud_function"
  output_path = "${path.module}/csv_validator.zip"
}

resource "google_storage_bucket_object" "csv_validator_zip" {
  name   = "csv_validator.zip"
  bucket = data.google_storage_bucket.function_source_bucket.name
  source = data.archive_file.csv_validator_zip.output_path
}

resource "google_cloudfunctions_function" "csv_validator" {
  name                  = "csv-validator"
  runtime               = "python39"
  region                = var.region
  entry_point           = "validate_csv"
  service_account_email = data.google_service_account.dataloader_sa.email

  source_archive_bucket = data.google_storage_bucket.function_source_bucket.name
  source_archive_object = google_storage_bucket_object.csv_validator_zip.name

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
# Pub/Sub Subscription → Cloud Run
##############################

resource "google_pubsub_subscription" "invoke_dataloader" {
  name    = "invoke-dataloader-sub"
  project = var.project_id
  topic   = "projects/${var.project_id}/topics/csv-success-topic"

  push_config {
    push_endpoint = google_cloud_run_service.dataloader_service.status[0].url

    oidc_token {
      service_account_email = data.google_service_account.dataloader_sa.email
    }
  }
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
# Cloud Composer v2 – Environment
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

##############################
# Outputs
##############################

output "composer_dag_bucket" {
  description = "Bucket pour déposer les DAGs"
  value       = google_composer_environment.composer_env.config[0].dag_gcs_prefix
}
