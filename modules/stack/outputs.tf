output "stack_id" {
  value = random_id.stack_id.hex
  description = "A unique id for this deployment"
}
