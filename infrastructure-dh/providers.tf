terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  is_local = var.target_env != "aws"
  endpoint = local.is_local ? var.tf_endpoint : null
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = local.is_local ? "test" : null
  secret_key                  = local.is_local ? "test" : null
  skip_credentials_validation = local.is_local
  skip_metadata_api_check     = local.is_local
  skip_requesting_account_id  = local.is_local
  s3_use_path_style           = local.is_local

  dynamic "endpoints" {
    for_each = local.is_local ? [1] : []
    content {
      s3      = local.endpoint
      sqs     = local.endpoint
      iam     = local.endpoint
      lambda  = local.endpoint
      ecr     = local.endpoint
      logs    = local.endpoint
    }
  }
}
