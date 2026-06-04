variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "target_env" {
  description = "Target environment provider: floci or aws"
  type        = string
  default     = "floci"
}

variable "tf_endpoint" {
  description = "floci endpoint URL (empty for AWS real)"
  type        = string
  default     = "http://floci:4566"
}
