resource "aws_lambda_function" "convert_html_to_pdf" {
  function_name = "SET-${var.environment}-Doodle-ConvertHtmlToPdf"
  role          = var.lambda_execution_role_arn
  package_type  = "Image"
  image_uri     = "public.ecr.aws/lambda/python:3.10"
  timeout       = 300
  memory_size   = 1024

  environment {
    variables = {
      BUCKET_NAME                = var.s3_bucket_name
      ENVIRONMENT                = var.environment
      CONVERSION_TIMEOUT_SECONDS = "120"
      MAX_FILE_SIZE_MB           = "50"
    }
  }

  lifecycle {
    ignore_changes = [image_uri]
  }

  tags = var.common_tags
}

resource "aws_lambda_event_source_mapping" "html_trigger" {
  event_source_arn = var.sqs_arns["html_conversion"]
  function_name    = aws_lambda_function.convert_html_to_pdf.arn
  batch_size       = 10
}

resource "aws_lambda_function" "convert_msdoc_to_pdf" {
  function_name = "SET-${var.environment}-Doodle-ConvertMsDocToPdf"
  role          = var.lambda_execution_role_arn
  package_type  = "Image"
  image_uri     = "public.ecr.aws/lambda/python:3.10"
  timeout       = 300
  memory_size   = 2048

  environment {
    variables = {
      BUCKET_NAME                = var.s3_bucket_name
      ENVIRONMENT                = var.environment
      CONVERSION_TIMEOUT_SECONDS = "180"
      MAX_FILE_SIZE_MB           = "60"
    }
  }

  lifecycle {
    ignore_changes = [image_uri]
  }

  tags = var.common_tags
}

resource "aws_lambda_event_source_mapping" "office_trigger" {
  event_source_arn = var.sqs_arns["office_conversion"]
  function_name    = aws_lambda_function.convert_msdoc_to_pdf.arn
  batch_size       = 10
}
