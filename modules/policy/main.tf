

locals {
  is_bucket = var.resource_type == "bucket"
}

module "custom_roles" {
  source = "../roles"
}

# Apply the IAM policy to the resource
resource "google_storage_bucket_iam_member" "bucket_iam_member_read" {
  count  = local.is_bucket ? 1 : 0
  bucket = var.resource_name
  role   = var.roles.bucket_read
  member = "serviceAccount:${var.service_account.email}"
}

resource "google_storage_bucket_iam_member" "bucket_iam_member_write" {
  count  = local.is_bucket ? 1 : 0
  bucket = var.resource_name
  role   = var.roles.bucket_write
  member = "serviceAccount:${var.service_account.email}"
}

resource "google_storage_bucket_iam_member" "bucket_iam_member_delete" {
  count  = local.is_bucket ? 1 : 0
  bucket = var.resource_name
  role   = var.roles.bucket_delete
  member = "serviceAccount:${var.service_account.email}"
}
