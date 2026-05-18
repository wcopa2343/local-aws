variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "s3_bucket_arn" {
  type = string
}

variable "sqs_arns" {
  type = map(string)
}
