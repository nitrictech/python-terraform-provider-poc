variable "stack_name" {
  description = "The name of the nitric stack"
  type        = string
}

variable "region" {
  description = "The region to deploy the stack"
  type        = string
}

variable "required_services" {
  default = [    
    # Enable the IAM API
    "iam.googleapis.com",
    # Enable cloud run
    "run.googleapis.com",
    # Enable pubsub
    "pubsub.googleapis.com",
    # Enable cloud scheduler
    "cloudscheduler.googleapis.com",
    # Enable cloud scheduler
    "storage.googleapis.com",
    # Enable Compute API (Networking/Load Balancing)
    "compute.googleapis.com",
    # Enable Artifact Registry API and Container Registry API
    "containerregistry.googleapis.com",
    "artifactregistry.googleapis.com",
    # Enable firestore API
    "firestore.googleapis.com",
    # Enable ApiGateway API
    "apigateway.googleapis.com",
    # Enable SecretManager API
    "secretmanager.googleapis.com",
    # Enable Cloud Tasks API
    "cloudtasks.googleapis.com",
    # Enable monitoring API
    "monitoring.googleapis.com",
    # Enable service usage API
    "serviceusage.googleapis.com"
  ]
}