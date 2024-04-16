variable "project_id" {
  description = "The google project id"
  type        = string
}

variable "api_name" {
  description = "The name of the deployed API"
  type        = string
}

variable "region" {
  description = "The region to deploy the API Gateway to"
  type        = string
}

variable "openapi_spec" {
  description = "The contents of the OpenAPI spec to use in yaml/json format"
  type        = string
}

variable "labels" {
  description = "Labels for the API resource"
  type        = map(string)
  default     = {}
}