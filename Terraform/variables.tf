// variables.tf
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
  description = "Zone/Multi-région pour Composer/Dataflow"
  type        = string
  default     = "us-central1"
}

variable "alert_emails" {
  description = "Liste d’adresses e-mail pour recevoir les alertes (succès et erreur)"
  type        = list(string)
}
