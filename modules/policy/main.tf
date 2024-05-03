locals {
  is_bucket = var.resource_type == "Bucket"
}

# Apply the IAM policy to the resource
resource "google_storage_bucket_iam_member" "bucket_iam_member_read" {
  count  = local.is_bucket && (contains(var.actions, "BucketFileGet") || contains(var.actions, "BucketFileList")) ? 1 : 0
  bucket = var.resource_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account_email}"
}

resource "google_storage_bucket_iam_member" "bucket_iam_member_write" {
  count  = local.is_bucket && contains(var.actions, "BucketFilePut") ? 1 : 0
  bucket = var.resource_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}

resource "google_storage_bucket_iam_member" "bucket_iam_member_delete" {
  count  = local.is_bucket && contains(var.actions, "BucketFileDelete") ? 1 : 0
  bucket = var.resource_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}
