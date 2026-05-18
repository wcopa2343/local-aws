output "s3_bucket_name" {
  value = module.storage.bucket_name
}

output "sqs_arns" {
  value = module.messaging.sqs_arns
}

output "ecr_urls" {
  value = module.registry.ecr_urls
}

output "lambda_execution_role_arn" {
  value = module.security.lambda_execution_role_arn
}
