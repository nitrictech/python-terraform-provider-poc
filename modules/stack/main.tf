# Generate a random id for the bucket
resource "random_id" "stack_id" {
  byte_length = 8

  prefix = var.stack_name

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    bucket_name = var.stack_name
  }
}