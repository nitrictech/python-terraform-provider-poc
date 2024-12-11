
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.7"
    }
  }
}

resource "random_id" "service_account_id" {
  byte_length = 2

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    project_id = var.service_name
  }
}

data "google_client_config" "default" {}

resource "google_project_service" "service_usage" {
  service = "serviceusage.googleapis.com"
  project  = var.project_id
  disable_on_destroy = false
  disable_dependent_services = false
}

locals {
  service_image_url = "${var.artifact_registry_repository}/${var.service_name}"
}

provider "docker" {
  registry_auth {
    address  = "${var.region}-docker.pkg.dev"
    username = "oauth2accesstoken"
    password = data.google_client_config.default.access_token
  }
}

resource "docker_tag" "new_tag" {
  source_image = var.image_uri
  target_image = local.service_image_url
}

# Push the Docker image to a Docker registry
resource "docker_registry_image" "repo_image" {
  name = local.service_image_url

  triggers = {
    digest = docker_tag.new_tag.source_image_id
  }
}

# Create a new GCP service account
resource "google_service_account" "service_account" {
  # FIXME: improve the account_id generation
  account_id   = substr(replace(replace("acct${random_id.service_account_id.hex}${var.service_name}", "_", ""), "-", ""), 0, 30)
  project      = var.project_id
}

resource "google_project_iam_member" "pubsub_token_creator" {
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.service_account.email}"
  project = var.project_id
}

# TODO: is this too permissive?
resource "google_project_iam_member" "realtime_db_admin" {
  project = var.project_id
  role    = "roles/firebase.admin"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

# Create a Cloud Run IAM member for the service account
# resource "google_cloud_run_service_iam_member" "iam_member" {
#   location    = var.region
#   project     = var.project_id
#   service     = var.cloud_run_service_name
#   role        = "roles/run.invoker"
#   member      = "serviceAccount:${google_service_account.service_account.email}"
# }

# Grant the service account the 'roles/iam.serviceAccountUser' role
resource "google_project_iam_member" "iam_member_self" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

# Grant the service account the 'Nitric base compute role' role
resource "google_project_iam_member" "base_compute_role" {
  project = var.project_id
  role    = var.base_compute_role
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

# A Google CloudRun resource
resource "google_cloud_run_service" "nitric_compute" {
  name     = replace("${var.service_name}", "_", "-")
  location = var.region
  project  = var.project_id
  autogenerate_revision_name = true

  template {
    spec {
      service_account_name = google_service_account.service_account.email
      
      containers {
        image = "gcr.io/${var.project_id}/${var.service_name}"
        ports {
          container_port = 9001
        }
        args = var.cmd

        env {
          name = "NITRIC_STACK_ID"
          value = var.stack_id
        }

        env {
          name = "NITRIC_ENVIRONMENT"
          value = "cloud"
        }

        env {
          name = "GCP_REGION"
          value = var.region
        }

        env {
          name = "SERVICE_ACCOUNT_EMAIL"
          value = google_service_account.service_account.email
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    docker_registry_image.repo_image,
    # Add other dependencies here
  ]
}

# Create a new GCP service account
resource "google_service_account" "invoker_account" {
  # FIXME: improve the account_id generation
  account_id   = substr(replace(replace("inv${random_id.service_account_id.hex}${var.service_name}", "_", ""), "-", ""), 0, 30)
  project      = var.project_id
}

# Create a Cloud Run IAM member for the service account
resource "google_cloud_run_service_iam_member" "iam_member" {
  location    = var.region
  project     = var.project_id
  service     = google_cloud_run_service.nitric_compute.name
  role        = "roles/run.invoker"
  member      = "serviceAccount:${google_service_account.invoker_account.email}"
}

# Provision the Firestore database instance.
resource "google_firestore_database" "default" {
  provider                    = google-beta

  project                     = var.project_id
  name                        = "(default)"
  location_id                 = var.region
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"

  depends_on = [ var.stack_id ]
}

# TODO: restrict to svc_email
resource "google_firebaserules_ruleset" "firestore" {
  source {
    files {
      content = "service cloud.firestore {match /databases/{database}/documents { match /{document=**} { allow read, write: if true; } } }"
      name    = "firestore.rules"
    }
  }

  project  = var.project_id

  depends_on = [
    google_firestore_database.default,
  ]
}

# Release the ruleset for the Firestore instance.
resource "google_firebaserules_release" "firestore" {
  provider     = google-beta

  name         = "cloud.firestore"  # must be cloud.firestore
  ruleset_name = google_firebaserules_ruleset.firestore.name
  project      = var.project_id

  # Wait for Firestore to be provisioned before releasing the ruleset.
  depends_on = [
    google_firestore_database.default,
  ]

  lifecycle {
    replace_triggered_by = [
      google_firebaserules_ruleset.firestore
    ]
  }
}