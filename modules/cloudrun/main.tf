
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
  }
}

resource "random_id" "service_account_id" {
  byte_length = 2

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    project_id = var.service_name
  }
}

# FIXME: This is a workaround to get the access token for the Docker registry
# This should be properly configured by impersonating a known service account with GAR access
data "external" "gcloud_access_token" {
  program = ["bash", "-c", "gcloud auth print-access-token --format json"]
}

provider "docker" {
  registry_auth {
    address  = "gcr.io"
    username = "oauth2accesstoken"
    password = data.external.gcloud_access_token.result.token
  }
}

resource "docker_tag" "new_tag" {
  source_image = var.image_uri
  target_image = "gcr.io/${var.project_id}/${var.service_name}"
}

# Push the Docker image to a Docker registry
resource "docker_registry_image" "repo_image" {
  name     = "gcr.io/${var.project_id}/${var.service_name}"
  triggers = {
    build_id = docker_tag.new_tag.source_image_id
  }
}

# Create a new GCP service account
resource "google_service_account" "service_account" {
  account_id   = substr(replace("acct-${random_id.service_account_id.hex}-${var.service_name}", "_", ""), 0, 30)
  project      = var.project_id
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
  account_id   = substr(replace("inv-${random_id.service_account_id.hex}-${var.service_name}", "_", ""), 0, 30)
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
