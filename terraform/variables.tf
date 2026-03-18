variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "env" {
  description = "Environment name (e.g. devops-test)"
  type        = string
  default     = "devops-test"
}

variable "project" {
  description = "Project name for resource naming"
  type        = string
  default     = "lambda-s3-api"
}

variable "image_tag" {
  description = "Docker image tag used for the Lambda container (from workflow)"
  type        = string
  default     = "latest"
}
