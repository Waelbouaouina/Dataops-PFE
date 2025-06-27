// Terraform/iam.tf

# Autoriser ta Function (SA) à publier sur les topics
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

# Autoriser la subscription à invoquer ton Cloud Run
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_service.dataloader_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.dataloader_sa.email}"
}
