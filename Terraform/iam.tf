##############################
# Récupère le numéro de projet
##############################
data "google_project" "current" {}

##############################
# Création du Service Account dataloader-sa
##############################
resource "google_service_account" "dataloader_sa" {
  account_id   = "dataloader-sa"
  display_name = "Dataloader Service Account"
}

##############################
# IAM bindings pour dataloader-sa
# -> BIGQUERY : création de tables
# -> STORAGE : lecture d’objets
# -> PUBSUB  : publication
# -> COMPOSER Service Agent Extension
##############################

resource "google_project_iam_member" "sa_bigquery_data_owner" {
  project = var.project_id
  role    = "roles/bigquery.dataOwner"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "sa_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "composer_service_agent_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

##############################
# Permet à Composer d’agir AS dataloader-sa
##############################
resource "google_service_account_iam_member" "dataloader_sa_act_as_by_composer" {
  service_account_id = google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

##############################
# IAM bindings pour TON user/SA Terraform
# -> BIGQUERY : création de tables
# -> STORAGE  : création d’objets
# -> CLOUD FUNCTIONS : déploiement
# -> CLOUD RUN       : déploiement
# -> PUBSUB           : admin
##############################

resource "google_project_iam_member" "tf_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "tf_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "tf_cloudfunctions_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "tf_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "user:${var.terraform_sa_email}"
}

resource "google_project_iam_member" "tf_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "user:${var.terraform_sa_email}"
}

##############################
# Permet à TON Terraform d’agir AS dataloader-sa
##############################
resource "google_service_account_iam_member" "dataloader_sa_act_as_by_tf" {
  service_account_id = google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.terraform_sa_email}"
}
