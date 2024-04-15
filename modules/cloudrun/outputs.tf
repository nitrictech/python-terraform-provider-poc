output "url" {
  value       = google_cloud_run_service.nitric_compute.statuses[0].url
  description = "The URL of the Google Cloud Run instance"
}