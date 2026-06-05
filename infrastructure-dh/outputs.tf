output "s3_bucket_name" {
  value = module.storage.bucket_name
}

output "s3_bucket_arn" {
  value = module.storage.bucket_arn
}

output "sqs_arns" {
  value = module.messaging.sqs_arns
}

output "sqs_urls" {
  value = module.messaging.sqs_urls
}

output "ecr_urls" {
  value = module.registry.ecr_urls
}

output "lambda_arns" {
  value = module.compute.lambda_arns
}

output "lambda_execution_role_arn" {
  value = module.security.lambda_execution_role_arn
}
