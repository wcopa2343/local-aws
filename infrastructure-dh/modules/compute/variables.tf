variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "lambda_execution_role_arn" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "sqs_arns" {
  type = map(string)
}

variable "sqs_urls" {
  type = map(string)
}

variable "ecr_urls" {
  type = map(string)
}
