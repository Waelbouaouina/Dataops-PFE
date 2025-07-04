locals {
  build_sa = "tmt-dev-01@${var.project_id}.iam.gserviceaccount.com"
}

# 1) GCS (upload/delete du zip CF)
resource "google_project_iam_binding" "tf_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# 2) BigQuery (création / import)
resource "google_project_iam_binding" "cb_bq_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# 3) Cloud Functions
resource "google_project_iam_binding" "tf_cf_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  members = ["serviceAccount:${local.build_sa}"]
}

# 4) ActAs sur dataloader-sa
data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
  project    = var.project_id
}

resource "google_service_account_iam_member" "cb_actas_dataloader" {
  service_account_id = data.google_service_account.dataloader_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.build_sa}"
}

# 5) (Option) Composer admin UI – si besoin pour console uniquement
resource "google_project_iam_binding" "tf_composer_admin" {
  project = var.project_id
  role    = "roles/composer.admin"
  members = ["serviceAccount:${local.build_sa}"]
}
