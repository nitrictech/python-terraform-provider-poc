output "stack_id" {
  value = random_id.stack_id.hex
  description = "A unique id for this deployment"
}

output "container_registry_uri" {
  value = "${var.region}-docker.pkg.dev/${data.google_project.project.project_id}/${google_artifact_registry_repository.service-image-repo.name}"
  description = "The name of the container registry repository"
}