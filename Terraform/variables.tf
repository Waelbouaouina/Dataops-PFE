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
  description = "Bucket GCS où arrivent les CSV"
}

variable "function_bucket" {
  type        = string
  description = "Bucket GCS pour stocker les zips de CF"
}

variable "bq_dataset_id" {
  type        = string
  description = "ID du dataset BigQuery (juste le nom, ex: inventory_dataset)"
}

variable "terraform_user_email" {
  type        = string
  description = "Email du compte utilisateur Terraform (uniquement si besoin)"
}

variable "function_name" {
  type        = string
  description = "Nom de la Cloud Function"
  default     = "csv-validator"
}

variable "function_runtime" {
  type    = string
  default = "python39"
}

variable "function_entry" {
  type    = string
  default = "validate_csv"
}
