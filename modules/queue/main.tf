# Generate a random id for the secret
resource "random_id" "queue_id" {
  byte_length = 4
}

resource "google_pubsub_topic" "queue_topic" {
  project    = var.project_id
  name = "${var.queue_name}-queue-${random_id.queue_id.hex}"

  labels = {
    "x-nitric-${var.stack_id}-type" = "queue"
    "x-nitric-${var.stack_id}-name" = var.queue_name
  }
}

resource "google_pubsub_subscription" "queue_subscription" {
  project    = var.project_id
  name  = "${var.queue_name}-nitricqueue-${random_id.queue_id.hex}"
  topic = google_pubsub_topic.queue_topic.name

  labels = {
    "x-nitric-${var.stack_id}-type" = "queue"
    "x-nitric-${var.stack_id}-name" = var.queue_name
  }

  expiration_policy {
    ttl = ""
  }
}
