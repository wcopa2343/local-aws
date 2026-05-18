resource "aws_ecr_repository" "html_conversion" {
  count        = var.target_env != "localstack" ? 1 : 0
  name         = "pdf-converter-${var.environment}/document.conversion.html"
  force_delete = true
  tags         = var.common_tags
}

resource "aws_ecr_repository" "office_conversion" {
  count        = var.target_env != "localstack" ? 1 : 0
  name         = "pdf-converter-${var.environment}/document.conversion.office"
  force_delete = true
  tags         = var.common_tags
}
