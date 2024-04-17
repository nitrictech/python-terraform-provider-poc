# Generate a set of known custom IAM roles
# That translate to nitric permissions
# For a given project this would only need to be done once for all nitric stacks deployed to that project

# Generate a random id for the bucket
resource "random_id" "role_id" {
  byte_length = 8

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    project_id = var.project_id
  }
}

# Permissions required for compute units to operate
resource "google_project_iam_custom_role" "base_compute_role" {
  role_id     = "NitricBaseCompute_${random_id.role_id.hex}"
  title       = "Nitric Base Compute"
  description = "Custom role for base nitric compute permissions"
  project     = var.project_id
  permissions = [
    "storage.buckets.list",
    "storage.buckets.get",
    # "cloudtasks.queues.get",
    # "cloudtasks.tasks.create",
    # "cloudtrace.traces.patch",
    # "monitoring.timeSeries.create",
    "iam.serviceAccounts.signBlob",
    // Basic list permissions
    # "pubsub.topics.list",
    # "pubsub.topics.get",
    # "pubsub.snapshots.list",
    # "pubsub.subscriptions.get",
    "resourcemanager.projects.get",
    "apigateway.gateways.list",
  ]
}

# Implement least priveledge
# Permissions required for reading from a bucket
# resource "google_project_iam_custom_role" "bucket_reader_role" {
#   role_id     = "NitricBucketReader"
#   title       = "Nitric Bucket Reader"
#   description = "Custom role that only allows reading from a bucket"
#   project     = var.project_id
#   permissions = ["storage.objects.get", "storage.objects.list"]
# }

# # Permissions required to write to a bucket
# resource "google_project_iam_custom_role" "bucket_writer_role" {
#   role_id     = "NitricBucketWriter"
#   title       = "Nitric Bucket Writer"
#   description = "Custom role that only allows writing to a bucket"
#   project     = var.project_id
#   permissions = ["storage.objects.create", "storage.objects.delete"]
# }

# # Permissions required to delete an item from a bucket
# resource "google_project_iam_custom_role" "bucket_deleter_role" {
#   role_id     = "NitricBucketDeleter"
#   title       = "Nitric Bucket Deleter"
#   description = "Custom role that only allows deleting from a bucket"
#   project     = var.project_id
#   permissions = ["storage.objects.delete"]
# }
