locals {
  common_tags = {
    Environment = var.environment
    Project     = "dh"
    ManagedBy   = "terraform"
  }
}

module "storage" {
  source      = "./modules/storage"
  environment = var.environment
  common_tags = local.common_tags
}

module "messaging" {
  source      = "./modules/messaging"
  environment = var.environment
  common_tags = local.common_tags
}

module "registry" {
  source      = "./modules/registry"
  environment = var.environment
  target_env  = var.target_env
  common_tags = local.common_tags
}

module "security" {
  source         = "./modules/security"
  environment    = var.environment
  aws_region     = var.aws_region
  common_tags    = local.common_tags
  s3_bucket_arn  = module.storage.bucket_arn
  sqs_arns       = module.messaging.sqs_arns
}

module "compute" {
  source                    = "./modules/compute"
  environment               = var.environment
  aws_region                = var.aws_region
  target_env                = var.target_env
  common_tags               = local.common_tags
  lambda_execution_role_arn = module.security.lambda_execution_role_arn
  s3_bucket_name            = module.storage.bucket_name
  sqs_arns                  = module.messaging.sqs_arns
  sqs_urls                  = module.messaging.sqs_urls
  ecr_urls                  = module.registry.ecr_urls
}
