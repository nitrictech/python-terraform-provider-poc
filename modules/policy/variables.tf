variable "resource_type" {
  description = "The type of the resource"
  type        = string
}

variable "resource_name" {
  description = "The name of the resource"
  type        = string
}

variable "roles" {
    description = "The custom roles to apply"
    type        = object({
        bucket_read       = string
        bucket_write      = string
        bucket_delete     = string
    })
}
