# sa.tf

# On ne crée plus la SA, on la consulte seule­ment
data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
}
