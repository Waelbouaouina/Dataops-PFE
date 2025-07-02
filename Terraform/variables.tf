variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région (ex: europe-west1)"
  type        = string
}

variable "location" {
  description = "Même valeur que region, pour Composer"
  type        = string
}

variable "data_bucket" {
  description = "Nom du bucket de données existant"
  type        = string
}

variable "function_bucket" {
  description = "Nom du bucket où stocker les archives de Cloud Functions"
  type        = string
}

variable "bq_dataset_id" {
  description = "ID du dataset BigQuery"
  type        = string
}

variable "terraform_sa_email" {
  description = "Email du compte (user ou SA) exécutant Terraform"
  type        = string
}

variable "dataloader_sa_email" {
  description = "Email du service account dataloader à impersonner"
  type        = string
}
