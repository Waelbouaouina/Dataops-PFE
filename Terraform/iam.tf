# Pub/Sub Admin pour Terraform
resource "google_project_iam_member" "terraform_pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "user:TON_EMAIL_OU_SA_QUI_TERRAFORM"
}

# Autoriser la Function à publier sur les topics
resource "google_pubsub_topic_iam_member" "publisher_success" {
  topic  = google_pubsub_topic.csv_success_topic.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.dataloader_sa.email}"
}
resource "google_pubsub_topic_iam_member" "publisher_error" {
  topic  = google_pubsub_topic.csv_error_topic.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

# Autoriser la subscription à invoquer le Cloud Run
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_service.dataloader_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.dataloader_sa.email}"
}

# Composer Service Agent Extension
data "google_project" "current" {}
resource "google_project_iam_member" "composer_service_agent_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}
