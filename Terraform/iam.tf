# 1) droits runtime pour dataloader-sa
resource "google_project_iam_member" "sa_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

resource "google_project_iam_member" "sa_bigquery_dataowner" {
  project = var.project_id
  role    = "roles/bigquery.dataOwner"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

# 2) droits Terraform pour CRUD sur tout
resource "google_project_iam_member" "tf_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "user:${var.terraform_user_email}"
}

resource "google_project_iam_member" "tf_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "user:${var.terraform_user_email}"
}

resource "google_project_iam_member" "tf_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "user:${var.terraform_user_email}"
}

resource "google_project_iam_member" "tf_cloudfunctions_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  member  = "user:${var.terraform_user_email}"
}

resource "google_project_iam_member" "tf_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "user:${var.terraform_user_email}"
}

resource "google_project_iam_member" "tf_composer_admin" {
  project = var.project_id
  role    = "roles/composer.admin"
  member  = "user:${var.terraform_user_email}"
}

# 3) Autoriser Terraform à actAs et getAccessToken sur dataloader-sa
resource "google_service_account_iam_member" "tf_act_as_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.terraform_user_email}"
}

resource "google_service_account_iam_member" "tf_token_creator" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.terraform_user_email}"
}
