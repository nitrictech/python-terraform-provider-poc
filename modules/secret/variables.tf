variable "project_id" {
  description = "The ID of the project in which the resource belongs."
  type        = string
}

variable "stack_name" {
  description = "The name of the stack, used as a prefix in resource names to ensure uniqueness."
  type        = string
}

variable "stack_id" {
  description = "The stack identifier, used for labeling resources."
  type        = string
}

variable "secret_name" {
  description = "The base name of the secret, used in creating the full secret identifier."
  type        = string
}
