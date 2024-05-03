output "url" {
  value       = google_cloud_run_service.nitric_compute.status[0].url
  description = "The URL of the Google Cloud Run instance"
}

output "service_account_email" {
  value       = google_service_account.service_account.email
  description = "The service account email of the Google Cloud Run instance"
}