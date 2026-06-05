output "lambda_arns" {
  value = {
    generate_thumbnails_from_image = aws_lambda_function.generate_thumbnails_from_image.arn
    generate_thumbnails_from_pdf   = aws_lambda_function.generate_thumbnails_from_pdf.arn
    convert_html_to_pdf            = aws_lambda_function.convert_html_to_pdf.arn
    convert_msdoc_to_pdf           = aws_lambda_function.convert_msdoc_to_pdf.arn
    split_pdf_to_images            = aws_lambda_function.split_pdf_to_images.arn
  }
}
