output "secret_name" {
  description = "The Secret ID of the created Google Cloud Secret Manager secret."
  value       = google_secret_manager_secret.secret.secret_id
}
