
# Write the Dockerfile to the file system
# resource "null_resource" "copy_dockerfile" {
#   provisioner "local-exec" {
#      # Fix this build context
#     command = <<EOF
# mkdir -p ${path.module}/build-${var.service_name}
# echo -e "${var.dockerfile}" > ${path.module}/build-${var.service_name}/Dockerfile
# EOF
#   }
# }

# Build the Docker image
# resource "docker_image" "image" {
#   name = "gcr.io/${var.project_id}/${var.service_name}"
#   build {
#     # Fix this build context
#     context = "${path.module}/build-${var.service_name}"
#     build_args = {
#       RUNTIME_URI = var.runtime_uri
#       BASE_IMAGE = var.image_name
#     }
#   }
# }

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

provider "google" {
  credentials = file("~/gcp/key.json")
}

data "google_client_config" "default" {}

resource "google_project_service" "service_usage" {
  service = "serviceusage.googleapis.com"
  project  = var.project_id
  disable_on_destroy = false
  disable_dependent_services = false
}

variable "required_services" {
  default = [    
    "iam.googleapis.com",
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "cloudscheduler.googleapis.com",
    "storage.googleapis.com",
    "compute.googleapis.com",
    "containerregistry.googleapis.com",
    "firestore.googleapis.com",
    "apigateway.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudtasks.googleapis.com",
    "monitoring.googleapis.com",
    "firebaserules.googleapis.com",
  ]
}

# Ensure required Google services are enabled
resource "google_project_service" "services" {
  for_each = toset(var.required_services)

  service  = each.key
  project  = var.project_id
  disable_on_destroy = false
  disable_dependent_services = false
  depends_on = [
    google_project_service.service_usage
  ]
}

# Delay to ensure services are activated before usage
resource "time_sleep" "wait_after_services" {
  create_duration = "120s"
  depends_on = [
    google_project_service.services
  ]
}

provider "docker" {
  registry_auth {
    address  = "gcr.io"
    username = "_json_key"
    password = file("~/gcp/key.json")
  }
}

resource "docker_tag" "new_tag" {
  source_image = var.image_uri
  target_image = "gcr.io/${var.project_id}/${var.service_name}"
}

# Push the Docker image to a Docker registry
resource "docker_registry_image" "repo_image" {
  name = "gcr.io/${var.project_id}/${var.service_name}"

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

  depends_on = [
    google_project_service.services
  ]
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