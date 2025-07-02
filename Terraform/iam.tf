# Numéro de projet pour composer SA
data "google_project" "current" {}

#-----------------------------------------------------------------------------#
# 1) IAM pour dataloader-sa (Importé)
#    - BigQuery : création des tables
#    - Storage : lecture des objets
#    - Pub/Sub  : publication
#    - Composer Service Agent Extension
#    - Composer peut "ActAs" dataloader-sa
#-----------------------------------------------------------------------------#

resource "google_project_iam_member" "sa_bigquery_data_owner" {
  project = var.project_id
  role    = "roles/bigquery.dataOwner"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "sa_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

# Composer Service Agent v2 Extensions
resource "google_project_iam_member" "composer_service_agent_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

# Composer doit pouvoir impersonner dataloader-sa
resource "google_service_account_iam_member" "composer_act_as_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

#-----------------------------------------------------------------------------#
# 2) IAM pour TON Terraform (user ou SA)
#    - BigQuery admin
#    - Storage admin
#    - CloudFunctions admin
#    - Cloud Run admin
#    - Pub/Sub admin
#    - IAM Service Account User (pour actAs dataloader-sa)
#-----------------------------------------------------------------------------#

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

# Terraform doit aussi pouvoir actAs dataloader-sa
resource "google_service_account_iam_member" "tf_act_as_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.terraform_sa_email}"
}
