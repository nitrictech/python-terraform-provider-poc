# Generate a random id for the bucket
resource "random_id" "stack_id" {
  byte_length = 4

  prefix = "${var.stack_name}-"

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    stack_name = var.stack_name
  }

  depends_on = [ time_sleep.wait_after_services ]
}

# Service enabling API is async, so we want to wait a reasonable amount of time
# for the services to be enabled before proceeding
resource "time_sleep" "wait_after_services" {
  create_duration = "120s"
  depends_on = [
    google_project_service.services
  ]
}

data "google_project" "project" {
}

# Ensure required Google services are enabled
resource "google_project_service" "services" {
  for_each = toset(var.required_services)

  service  = each.key
  project  = data.google_project.project.project_id
  disable_on_destroy = false
  disable_dependent_services = false
}
resource "google_artifact_registry_repository" "service-image-repo" {
  location      = var.region
  repository_id = "${random_id.stack_id.hex}-services"
  description   = "service images for nitric stack ${var.stack_name}"
  format        = "DOCKER"
}