// main.tf
##############################
// Providers
##############################

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

##############################
// Activer les APIs nécessaires
##############################

resource "google_project_service" "container_registry" {
  project = var.project_id
  service = "containerregistry.googleapis.com"
}
resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}
resource "google_project_service" "bigquery_api" {
  project = var.project_id
  service = "bigquery.googleapis.com"
}
resource "google_project_service" "storage_api" {
  project = var.project_id
  service = "storage.googleapis.com"
}
resource "google_project_service" "pubsub_api" {
  project = var.project_id
  service = "pubsub.googleapis.com"
}
resource "google_project_service" "composer_api" {
  project = var.project_id
  service = "composer.googleapis.com"
}
resource "google_project_service" "dataflow_api" {
  project = var.project_id
  service = "dataflow.googleapis.com"
}

##############################
// Service Account pour Cloud Run
##############################

resource "google_service_account" "dataloader_sa" {
  account_id   = "dataloader-sa"
  display_name = "Dataloader Service Account"
}

##############################
// Buckets de Stockage
##############################

resource "google_storage_bucket" "inventory_bucket" {
  name     = "inventory-bucket-${var.project_id}"
  location = var.region
  versioning { enabled = true }
}

resource "google_storage_bucket" "function_source_bucket" {
  name     = "function-source-${var.project_id}"
  location = var.region
}

resource "google_storage_bucket_object" "csv_validator_zip" {
  name   = "csv_validator.zip"
  bucket = google_storage_bucket.function_source_bucket.name
  source = "cloud_function/csv_validator.zip"
}

##############################
// BigQuery Dataset & Tables
##############################

resource "google_bigquery_dataset" "inventory_dataset" {
  dataset_id                 = "inventory_dataset"
  location                   = var.region
  delete_contents_on_destroy = false
}

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
// Cloud Run: Dataloader
##############################

resource "google_cloud_run_service" "dataloader_service" {
  name     = "dataloader-service"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.dataloader_sa.email

      containers {
        image = "gcr.io/${var.project_id}/dataloader-image:latest"

        env {
          name  = "BUCKET_NAME"
          value = google_storage_bucket.inventory_bucket.name
        }
        env {
          name  = "BQ_DATASET"
          value = google_bigquery_dataset.inventory_dataset.dataset_id
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

resource "google_project_iam_member" "dataloader_sa_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "dataloader_sa_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

##############################
// Cloud Function: CSV Validator
##############################

resource "google_cloudfunctions_function" "csv_validator" {
  name        = "csv-validator"
  description = "Valide le CSV via Great Expectations et publie sur Pub/Sub"
  runtime     = "python39"
  region      = var.region

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.inventory_bucket.name
  }

  source_archive_bucket = google_storage_bucket.function_source_bucket.name
  source_archive_object = google_storage_bucket_object.csv_validator_zip.name
  entry_point           = "validate_csv"
  service_account_email = google_service_account.dataloader_sa.email

  environment_variables = {
    SUCCESS_TOPIC = google_pubsub_topic.csv_success_topic.name
    ERROR_TOPIC   = google_pubsub_topic.csv_error_topic.name
  }
}

##############################
// Pub/Sub Topics
##############################

resource "google_pubsub_topic" "csv_success_topic" {
  name = "csv-success-topic"
}

resource "google_pubsub_topic" "csv_error_topic" {
  name = "csv-error-topic"
}

##############################
// Cloud Composer (Airflow) – Composer v2.x
##############################

resource "google_composer_environment" "composer_env" {
  project = var.project_id
  name    = "composer-environment"
  region  = var.region

  config {
    software_config {
      # une version supportée  
      image_version = "composer-2.13.4-airflow-2.10.5"
    }
    # pour custom CPU/Mémoire, utilise workloads_config (optionnel)
    # workloads_config {
    #   scheduler { cpu="2000m" memory="4Gi" }
    #   webserver { cpu="1000m" memory="2Gi" }
    # }
  }
}

output "composer_dag_bucket" {
  value       = google_composer_environment.composer_env.config[0].dag_gcs_prefix
  description = "Bucket pour déposer les DAGs"
}

##############################
// Monitoring: Notification Channels & Alert Policy
##############################

resource "google_monitoring_notification_channel" "email_alert" {
  for_each     = toset(var.alert_emails)
  display_name = "Alert-Email ${each.value}"
  type         = "email"
  labels = {
    email_address = each.value
  }
}

resource "google_monitoring_alert_policy" "csv_validator_errors" {
  display_name          = "CSV Validator Errors"
  combiner              = "OR"
  notification_channels = [
    for ch in google_monitoring_notification_channel.email_alert : ch.id
  ]

  conditions {
    display_name = "Error Rate > 0"
    condition_threshold {
      filter          = "metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND resource.labels.function_name=\"${google_cloudfunctions_function.csv_validator.name}\" AND metric.label.\"status\"=\"error\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
}

##############################
// Data Catalog (Lineage)
##############################

resource "google_data_catalog_entry_group" "inventory_entry_group" {
  entry_group_id = "inventory_entry_group"
  display_name   = "Inventory Entry Group"
}

resource "google_data_catalog_tag_template" "inventory_tag_template" {
  provider        = google-beta
  tag_template_id = "inventory_tag_template"
  display_name    = "Inventory Tag Template"

  fields {
    field_id     = "source_system"
    display_name = "Source System"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id     = "processed_date"
    display_name = "Processed Date"
    type {
      primitive_type = "TIMESTAMP"
    }
  }
}

##############################
// Cloud Logging Sink
##############################

resource "google_logging_project_sink" "csv_validator_sink" {
  name        = "csv-validator-sink"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.inventory_dataset.dataset_id}"
  filter      = "resource.type=\"cloud_function\" AND resource.labels.function_name=\"${google_cloudfunctions_function.csv_validator.name}\""
}

##############################
// Cloud Build Trigger (CI/CD)
##############################

resource "google_cloudbuild_trigger" "git_trigger" {
  name    = "inventory-ci-trigger"
  project = var.project_id

  github {
    owner = "Waelbouaouina"
    name  = "Dataops-PFE"
    push {
      branch = "main"
    }
  }

  filename = "cloudbuild.yaml"
}
