###########################
# Providers & activation API
###########################

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Active uniquement les APIs dont tu as vraiment besoin
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

##################################
# Data sources (objets déjà existants)
##################################

# Bucket où ta Function est empaquetée
data "google_storage_bucket" "function_src" {
  name = var.function_bucket
}

# Bucket où ta data brutes arrivent
data "google_storage_bucket" "inventory" {
  name = var.data_bucket
}

# Service Account dataloader-sa existant
data "google_service_account" "dataloader_sa" {
  project    = var.project_id
  account_id = "dataloader-sa"
}

# Dataset BigQuery existant
data "google_bigquery_dataset" "inventory_ds" {
  project    = var.project_id
  dataset_id = "inventory_dataset"
}

# Topics Pub/Sub existants
data "google_pubsub_topic" "success_topic" {
  project = var.project_id
  name    = "csv-success-topic"
}
data "google_pubsub_topic" "error_topic" {
  project = var.project_id
  name    = "csv-error-topic"
}

##################################
# Empaqueter & déployer la Cloud Function
##################################

resource "google_storage_bucket_object" "csv_validator_zip" {
  name   = "csv_validator.zip"
  bucket = data.google_storage_bucket.function_src.name
  source = "${path.module}/../cloud_function/csv_validator.zip"
}

resource "google_cloudfunctions_function" "csv_validator" {
  name        = "csv-validator"
  runtime     = "python39"
  region      = var.region
  entry_point = "validate_csv"

  source_archive_bucket = data.google_storage_bucket.function_src.name
  source_archive_object = google_storage_bucket_object.csv_validator_zip.name

  service_account_email = data.google_service_account.dataloader_sa.email

  # Réagit à la mise en ligne d’objets dans le bucket de données brutes
  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = data.google_storage_bucket.inventory.name
  }

  environment_variables = {
    SUCCESS_TOPIC = data.google_pubsub_topic.success_topic.id
    ERROR_TOPIC   = data.google_pubsub_topic.error_topic.id
  }
}

##################################
# Tables BigQuery (création/manipulation)
##################################

resource "google_bigquery_table" "raw_table" {
  dataset_id = data.google_bigquery_dataset.inventory_ds.dataset_id
  table_id   = "raw_table"
  schema     = file("${path.module}/schemas/raw_table.json")
}

resource "google_bigquery_table" "tds_table" {
  dataset_id = data.google_bigquery_dataset.inventory_ds.dataset_id
  table_id   = "tds_table"
  schema     = file("${path.module}/schemas/tds_table.json")
}

resource "google_bigquery_table" "bds_table" {
  dataset_id = data.google_bigquery_dataset.inventory_ds.dataset_id
  table_id   = "bds_table"
  schema     = file("${path.module}/schemas/bds_table.json")
}

##################################
# Cloud Run – Dataloader
##################################

resource "google_cloud_run_service" "dataloader" {
  name     = "dataloader-service"
  location = var.region

  template {
    spec {
      service_account_name = data.google_service_account.dataloader_sa.email

      containers {
        image = "gcr.io/${var.project_id}/dataloader-image:latest"
        env {
          name  = "BUCKET_NAME"
          value = data.google_storage_bucket.inventory.name
        }
        env {
          name  = "BQ_DATASET"
          value = data.google_bigquery_dataset.inventory_ds.dataset_id
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

##################################
# Subscription Pub/Sub → Cloud Run
##################################

resource "google_pubsub_subscription" "invoke_dataloader" {
  name  = "invoke-dataloader-sub"
  topic = data.google_pubsub_topic.success_topic.name

  push_config {
    push_endpoint = google_cloud_run_service.dataloader.status[0].url
    oidc_token {
      service_account_email = data.google_service_account.dataloader_sa.email
    }
  }
}

##################################
# IAM Bindings pour Function & Run
##################################

# Autoriser la Function à publier sur les topics
resource "google_pubsub_topic_iam_member" "pub_success" {
  topic  = data.google_pubsub_topic.success_topic.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}
resource "google_pubsub_topic_iam_member" "pub_error" {
  topic  = data.google_pubsub_topic.error_topic.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

# Autoriser la subscription à invoquer le Cloud Run
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_service.dataloader.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

##################################
# Cloud Composer (v2) – Environnement
##################################

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
  description = "Bucket pour déposer les DAGs"
  value       = google_composer_environment.composer_env.config[0].dag_gcs_prefix
}
