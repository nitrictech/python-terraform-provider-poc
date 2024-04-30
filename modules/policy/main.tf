module "iam_roles" {
  source = "../roles"
}

locals {
  is_bucket = var.resource_type == "Bucket"
  is_secret = var.resource_type == "Secret"
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

resource "google_secret_manager_secret_iam_member" "secret_iam_member_put" {
  project = var.project_id
  count  = local.is_secret && contains(var.actions, "SecretPut") ? 1 : 0
  secret_id = var.resource_name
  role    = module.iam_roles.secret_put
  member = "serviceAccount:${var.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "secret_iam_member_access" {
  project = var.project_id
  count  = local.is_secret && contains(var.actions, "SecretAccess") ? 1 : 0
  secret_id = var.resource_name
  role    = module.iam_roles.secret_access
  member = "serviceAccount:${var.service_account_email}"
}

