output "ecr_urls" {
  value = {
    html_conversion   = var.target_env != "localstack" ? aws_ecr_repository.html_conversion[0].repository_url : ""
    office_conversion = var.target_env != "localstack" ? aws_ecr_repository.office_conversion[0].repository_url : ""
  }
}
