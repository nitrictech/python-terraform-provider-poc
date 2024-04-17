variable "project_id" {
  description = "The google project id"
  type        = string
}

variable "image_uri" {
  description = "The location of the docker image to deploy"
  type        = string
}

variable "service_name" {
  description = "The name of the cloud run service"
  type        = string
}

variable "region" {
  description = "The region of the cloud run service"
  type        = string
}

variable "cmd" {
  description = "The command that will be executed in the container"
  type        = list(string)
}
