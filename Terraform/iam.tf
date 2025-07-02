locals {
  # on n'utilise plus data.google_service_account
  sa_email = var.dataloader_sa_email
}

# Permet à TON user (ou SA Terraform) de lire les SAs si besoin
# (Optionnel si tu n'en as plus besoin)
resource "google_project_iam_member" "terraform_sa_serviceaccount_viewer" {
  project = var.project_id
  role    = "roles/iam.serviceAccountViewer"
  member  = "user:${var.terraform_sa_email}"
}

# Bindings pour le SA dataloader
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
