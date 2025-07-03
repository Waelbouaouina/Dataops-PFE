data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
  project    = var.project_id
}

locals {
  build_sa = "tmt-dev-01@${var.project_id}.iam.gserviceaccount.com"
}

# IAM bindings - organisés par service

# GCS
resource "google_project_iam_binding" "tf_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# BigQuery
resource "google_project_iam_binding" "cb_bq_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# Cloud Functions
resource "google_project_iam_binding" "tf_cf_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# Pub/Sub
resource "google_project_iam_binding" "tf_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# Cloud Run
resource "google_project_iam_binding" "tf_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# Composer
resource "google_project_iam_binding" "cb_composer_env_creator" {
  project = var.project_id
  role    = "roles/composer.environmentCreator"
  members = ["serviceAccount:${local.build_sa}"]
}

resource "google_project_iam_binding" "tf_composer_admin" {
  project = var.project_id
  role    = "roles/composer.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# ActAs / Token Creator
resource "google_service_account_iam_member" "cb_actas_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.build_sa}"
}

resource "google_service_account_iam_member" "tf_token_creator" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.build_sa}"
}
