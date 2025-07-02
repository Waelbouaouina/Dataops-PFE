##############################
# 1) Permissions pour dataloader-sa (runtime)
##############################

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

##############################
# 2) Permissions pour TON Terraform
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

resource "google_service_account_iam_member" "tf_act_as_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.terraform_sa_email}"
}
