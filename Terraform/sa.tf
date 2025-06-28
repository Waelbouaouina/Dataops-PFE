##############################
# Service Account à importer
##############################

resource "google_service_account" "dataloader_sa" {
  account_id   = "dataloader-sa"
  display_name = "Dataloader Service Account"

  lifecycle {
    prevent_destroy = true
  }
}
