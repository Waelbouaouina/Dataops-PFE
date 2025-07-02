######################################
# 1) Bindings projet pour Terraform
######################################

resource "google_project_iam_binding" "tf_project_roles" {
  project = var.project_id
  role    = "roles/editor"

  members = [
    "user:${var.terraform_user_email}"
  ]
}

######################################
# 2) Bindings projet pour dataloader-sa runtime
######################################

resource "google_project_iam_binding" "sa_runtime_roles" {
  project = var.project_id
  role    = "roles/storage.objectViewer"

  members = [
    "serviceAccount:${var.dataloader_sa_email}"
  ]
}

resource "google_project_iam_binding" "sa_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"

  members = [
    "serviceAccount:${var.dataloader_sa_email}"
  ]
}

resource "google_project_iam_binding" "sa_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataOwner"

  members = [
    "serviceAccount:${var.dataloader_sa_email}"
  ]
}

######################################
# 3) SA IAM Members pour actAs & TokenCreator
######################################

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
