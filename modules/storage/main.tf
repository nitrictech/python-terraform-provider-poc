
# Generate a random id for the bucket
resource "random_id" "bucket_id" {
  byte_length = 8

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    bucket_name = var.bucket_name
  }
}

# A Google cloud storage bucket
resource "google_storage_bucket" "bucket" {
  name          = "${var.bucket_name}-${random_id.bucket_id.hex}"
  location      = var.bucket_location
  project       = var.project_id
  storage_class = var.storage_class
  labels = {
    "x-nitric-${var.stack_id}-name" = var.bucket_name
  }
}