// A Google Cloud Api Gateway Resource

resource "random_id" "api_rand_id" {
  byte_length = 2

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    project_id = var.api_name
  }
}

resource "google_api_gateway_api" "api" {
  provider = google-beta
  project  = var.project_id
  api_id   = "${var.api_name}${random_id.api_rand_id.hex}"
  display_name = "example-api"
}

resource "google_api_gateway_api_config" "api_config" {
  project = var.project_id
  provider = google-beta
  api      = google_api_gateway_api.api.api_id
  api_config_id = "${var.api_name}${random_id.api_rand_id.hex}conf"
  openapi_documents {
    document {
      path     = "spec.yaml"
      contents =  base64encode(var.openapi_spec)
    }
  }
  # dynamic "labels" {
  #       for_each = var.labels

  #       content {
  #         name  = env.key
  #         value = env.value
  #       }
  # }
}

resource "google_api_gateway_gateway" "gateway" {
  provider = google-beta
  project  = var.project_id
  gateway_id = "${var.api_name}${random_id.api_rand_id.hex}"
  api_config = google_api_gateway_api_config.api_config.id
  region = var.region
}
