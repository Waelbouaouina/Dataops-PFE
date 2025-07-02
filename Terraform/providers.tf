provider "google" {
  project = var.project_id
  region  = var.region
}

# Ce provider va exécuter les actions "as" dataloader-sa
provider "google" {
  alias                        = "dataloader"
  project                      = var.project_id
  region                       = var.region
  impersonate_service_account  = var.dataloader_sa_email
}
