output "ecr_urls" {
  value = {
    html_conversion   = aws_ecr_repository.html_conversion.repository_url
    office_conversion = aws_ecr_repository.office_conversion.repository_url
  }
}
