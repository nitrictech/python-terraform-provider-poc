output "queue_name" {
  description = "The name of the Pub/Sub topic for the queue"
  value       = google_pubsub_topic.queue_topic.name
}

output "queue_subscription_name" {
  description = "The name of the created Pub/Sub subscription for the queue"
  value       = google_pubsub_subscription.queue_subscription.name
}