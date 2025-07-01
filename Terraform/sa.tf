##############################
# Service Account – EXISTANT
##############################

data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
}
