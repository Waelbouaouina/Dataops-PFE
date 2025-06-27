// Terraform/pubsub.tf

resource "google_pubsub_subscription" "invoke_dataloader" {
  name  = "invoke-dataloader-sub"
  topic = google_pubsub_topic.csv_success_topic.name

  push_config {
    push_endpoint = google_cloud_run_service.dataloader_service.status[0].url

    oidc_token {
      service_account_email = google_service_account.dataloader_sa.email
    }
  }
}
