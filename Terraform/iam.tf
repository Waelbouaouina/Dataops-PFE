##############################
# Récupère le numéro de projet
##############################
data "google_project" "current" {}

##############################
# Création du Service Account
##############################
resource "google_service_account" "dataloader_sa" {
  account_id   = "dataloader-sa"
  display_name = "Dataloader Service Account"
}

##############################
# IAM bindings pour dataloader-sa
##############################
resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

resource "google_service_account_iam_member" "dataloader_sa_act_as_composer" {
  service_account_id = google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "sa_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "sa_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

##############################
# IAM bindings pour TON Terraform
##############################
resource "google_project_iam_member" "terraform_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "terraform_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "terraform_cloudfunctions_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "terraform_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "terraform_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "user:${var.terraform_sa_email}"
}

##############################
# Extension Composer Service Agent
##############################
resource "google_project_iam_member" "composer_service_agent_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

// Permet à Terraform d’agir AS dataloader-sa
resource "google_service_account_iam_member" "dataloader_sa_act_as" {
  service_account_id = google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.terraform_sa_email}"
}

// Permet à Terraform de créer des tables BigQuery dans le dataset
resource "google_bigquery_dataset_iam_member" "tf_bigquery_tables" {
  dataset_id = var.bq_dataset_id
  role       = "roles/bigquery.dataOwner"
  member     = "user:${var.terraform_sa_email}"
}

// Permet à Terraform de gérer les fonctions Cloud Functions
resource "google_project_iam_member" "tf_cloudfunctions_create" {
  project = var.project_id
  role    = "roles/cloudfunctions.developer"
  member  = "user:${var.terraform_sa_email}"
}
