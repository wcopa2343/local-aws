output "sqs_arns" {
  value = {
    generate_thumbnails_from_image = aws_sqs_queue.generate_thumbnails_from_image.arn
    generate_thumbnails_from_pdf   = aws_sqs_queue.generate_thumbnails_from_pdf.arn
    html_conversion                = aws_sqs_queue.html_conversion.arn
    office_conversion              = aws_sqs_queue.office_conversion.arn
  }
}

output "sqs_urls" {
  value = {
    generate_thumbnails_from_image = aws_sqs_queue.generate_thumbnails_from_image.url
    generate_thumbnails_from_pdf   = aws_sqs_queue.generate_thumbnails_from_pdf.url
    html_conversion                = aws_sqs_queue.html_conversion.url
    office_conversion              = aws_sqs_queue.office_conversion.url
  }
}
