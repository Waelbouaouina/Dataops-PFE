// iam.tf

// On suppose que var.project_id est déjà défini dans variables.tf
// et que sa.tf contient bien la data source pour dataloader_sa.

locals {
  sa_email = data.google_service_account.dataloader_sa.email
}

resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.sa_email}"
}

resource "google_project_iam_member" "sa_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${local.sa_email}"
}

resource "google_project_iam_member" "sa_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.sa_email}"
}
