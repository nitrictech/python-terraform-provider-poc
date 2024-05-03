output "hostname" {
  value       = google_api_gateway_gateway.gateway.default_hostname
  description = "The hostname of the deployed api gateway"
}