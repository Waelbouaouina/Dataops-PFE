variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "Zone / multi-région pour Composer/Dataflow"
  type        = string
  default     = "us-central1"
}

variable "alert_emails" {
  description = "Liste d’emails pour les alertes"
  type        = list(string)
}

variable "data_bucket" {
  description = "Bucket GCS existant pour l’inventaire"
  type        = string
}

variable "function_bucket" {
  description = "Bucket GCS existant pour stocker le zip de la Function"
  type        = string
}

variable "bq_dataset_id" {
  description = "ID du dataset BigQuery existant"
  type        = string
}

// variables.tf

variable "terraform_sa_email" {
  description = "Email du compte (user ou service account) exécutant Terraform"
  type        = string
  default     = "wael.bouaouina@gmail.com"
}

variable "dataloader_sa_email" {
  description = "Email du Service Account dataloader"
  type        = string
}


