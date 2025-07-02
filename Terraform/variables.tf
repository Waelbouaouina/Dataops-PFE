variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région (ex: europe-west1)"
  type        = string
}

variable "location" {
  description = "Même valeur que region pour Composer"
  type        = string
}

variable "data_bucket" {
  description = "Bucket GCS existant pour les CSV"
  type        = string
}

variable "function_bucket" {
  description = "Bucket GCS pour stocker les archives de Functions"
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
  description = "Email du service account dataloader (déjà créé)"
  type        = string
}
