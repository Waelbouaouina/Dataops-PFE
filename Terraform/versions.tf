// versions.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.70.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.70.0"
    }
  }
}
