####################################
# 1) Bindings projet pour TON USER
####################################

resource "google_project_iam_binding" "tf_bq_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  members = ["user:${var.terraform_user_email}"]
}

resource "google_project_iam_binding" "tf_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  members = ["user:${var.terraform_user_email}"]
}

resource "google_project_iam_binding" "tf_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  members = ["user:${var.terraform_user_email}"]
}

resource "google_project_iam_binding" "tf_cf_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  members = ["user:${var.terraform_user_email}"]
}

resource "google_project_iam_binding" "tf_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  members = ["user:${var.terraform_user_email}"]
}

resource "google_project_iam_binding" "tf_composer_admin" {
  project = var.project_id
  role    = "roles/composer.admin"
  members = ["user:${var.terraform_user_email}"]
}

####################################
# 2) actAs & TokenCreator pour TON USER sur dataloader-sa
####################################

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

####################################
# 3) Bindings runtime pour dataloader-sa
####################################

resource "google_project_iam_binding" "sa_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  members = ["serviceAccount:${data.google_service_account.dataloader_sa.email}"]
}

resource "google_project_iam_binding" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_service_account.dataloader_sa.email}"]
}

resource "google_project_iam_binding" "sa_bq_dataowner" {
  project = var.project_id
  role    = "roles/bigquery.dataOwner"
  members = ["serviceAccount:${data.google_service_account.dataloader_sa.email}"]
}

####################################
# 4) Bindings pour Cloud Build SA
####################################

locals {
  # identifiant exact : PROJECT_NUMBER@cloudbuild.gserviceaccount.com
  cloudbuild_sa = "${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_binding" "cb_bq_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

resource "google_project_iam_binding" "cb_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

resource "google_project_iam_binding" "cb_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

resource "google_project_iam_binding" "cb_cf_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

resource "google_project_iam_binding" "cb_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

resource "google_project_iam_binding" "cb_composer_admin" {
  project = var.project_id
  role    = "roles/composer.admin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

# --- NOUVEAU ---
# Pour créer/supprimer les objets GCS (zip CF)
resource "google_project_iam_binding" "cb_storage_obj_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

# Pour créer des environnements Composer
resource "google_project_iam_binding" "cb_composer_env_admin" {
  project = var.project_id
  role    = "roles/composer.environmentAdmin"
  members = ["serviceAccount:${local.cloudbuild_sa}"]
}

resource "google_service_account_iam_member" "cb_act_as_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_service_account_iam_member" "cb_token_creator" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.cloudbuild_sa}"
}
