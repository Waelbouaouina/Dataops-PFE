##############################
# IAM – Project-level Pub/Sub Publisher
##############################

resource "google_project_iam_member" "dataloader_sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

##############################
# IAM – Cloud Run Invoker
##############################

resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_service.dataloader_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_service_account.dataloader_sa.email}"
}

##############################
# IAM – Composer Service Agent Extension
##############################

data "google_project" "current" {}

resource "google_project_iam_member" "composer_service_agent_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${data.google_project.current.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}
