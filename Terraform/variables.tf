variable "project_id" {
  type        = string
  description = "ID du projet GCP"
}

variable "region" {
  type        = string
  description = "Région GCP (ex: europe-west1)"
}

variable "location" {
  type        = string
  description = "Même que region pour Composer"
}

variable "data_bucket" {
  type        = string
  description = "Nom du bucket GCS où arrivent les CSV"
}

variable "function_bucket" {
  type        = string
  description = "Nom du bucket pour stocker les zips de Cloud Functions"
}

variable "bq_dataset_id" {
  type        = string
  description = "ID du dataset BigQuery à créer"
}

variable "terraform_user_email" {
  type        = string
  description = "Ton user ou SA exécutant Terraform (email)"
}

variable "dataloader_sa_email" {
  type        = string
  description = "Email du service account dataloader-sa (runtime)"
}
