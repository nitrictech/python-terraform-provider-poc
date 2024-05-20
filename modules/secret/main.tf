# Generate a random id for the secret
resource "random_id" "secret_id" {
  byte_length = 4
}

resource "google_secret_manager_secret" "secret" {
  project    = var.project_id
  secret_id  = "${var.stack_name}-${var.secret_name}-${random_id.secret_id.hex}"
  replication {
    auto {}
  }
  labels = {
    "x-nitric-${var.stack_id}-name" = var.secret_name
    "x-nitric-${var.stack_id}-type" = "secret"
  }
}
