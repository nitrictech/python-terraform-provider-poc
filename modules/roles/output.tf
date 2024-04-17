output "base_compute_role" {
  value = google_project_iam_custom_role.base_compute_role.id
  description = "The role ID for the Nitric base compute role"
}
# TODO: Implement least priveledge
# output "bucket_read" {
#   value = google_project_iam_custom_role.bucket_reader_role.id
#   description = "The role ID for the Nitric bucket read role"
# }

# output "bucket_write" {
#   value = google_project_iam_custom_role.bucket_writer_role.id
#   description = "The role ID for the Nitric bucket write role"
# }

# output "bucket_delete" {
#   value = google_project_iam_custom_role.bucket_deleter_role.id
#   description = "The role ID for the Nitric bucket delete role"
# }