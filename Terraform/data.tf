##############################
# Import du Service Account dataloader-sa déjà créé
##############################

data "google_service_account" "dataloader_sa" {
  account_id = "dataloader-sa"
  project    = var.project_id
}
