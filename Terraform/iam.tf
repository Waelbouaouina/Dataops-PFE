########################################
# IAM pour dataloader-sa (importé via data.tf)
########################################

# BigQuery : création de tables
resource "google_project_iam_member" "sa_bigquery_data_owner" {
  project = var.project_id
  role    = "roles/bigquery.dataOwner"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

# Storage : lecture d’objets
resource "google_project_iam_member" "sa_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

# Pub/Sub : publication
resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

# Extension Composer Service Agent
resource "google_project_iam_member" "composer_service_agent_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

# Composer peut impersonner dataloader-sa
resource "google_service_account_iam_member" "composer_act_as_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

# Composer peut obtenir un token OAuth (getAccessToken)
resource "google_service_account_iam_member" "composer_token_creator" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

########################################
# IAM pour TON Terraform (user ou SA)
########################################

# BigQuery admin
resource "google_project_iam_member" "tf_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "user:${var.terraform_sa_email}"
}

# Storage admin
resource "google_project_iam_member" "tf_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "user:${var.terraform_sa_email}"
}

# Cloud Functions admin
resource "google_project_iam_member" "tf_cloudfunctions_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  member  = "user:${var.terraform_sa_email}"
}

# Cloud Run admin
resource "google_project_iam_member" "tf_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "user:${var.terraform_sa_email}"
}

# Pub/Sub admin
resource "google_project_iam_member" "tf_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "user:${var.terraform_sa_email}"
}

# Terraform peut impersonner dataloader-sa
resource "google_service_account_iam_member" "tf_act_as_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.terraform_sa_email}"
}

# Terraform peut obtenir un token OAuth (getAccessToken)
resource "google_service_account_iam_member" "tf_token_creator" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.terraform_sa_email}"
}
