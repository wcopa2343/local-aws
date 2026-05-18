data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/placeholder.zip"
  source {
    content  = "def lambda_handler(event, context):\n    print('Hello from Terraform')\n    return {'statusCode': 200}"
    filename = "index.py"
  }
}

resource "aws_lambda_function" "generate_thumbnails_from_image" {
  function_name    = "generateThumbnailsFromImage-${var.environment}"
  role             = var.lambda_execution_role_arn
  handler          = "index.lambda_handler"
  runtime          = "python3.10"
  timeout          = 300
  memory_size      = 512
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256
  layers           = [aws_lambda_layer_version.thumbnail.arn]

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name
      ENVIRONMENT = var.environment
    }
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  tags = var.common_tags
}

resource "aws_lambda_event_source_mapping" "image_trigger" {
  event_source_arn = var.sqs_arns["generate_thumbnails_from_image"]
  function_name    = aws_lambda_function.generate_thumbnails_from_image.arn
  batch_size       = 10
}

resource "aws_lambda_function" "generate_thumbnails_from_pdf" {
  function_name    = "generateThumbnailsFromPdf-${var.environment}"
  role             = var.lambda_execution_role_arn
  handler          = "index.lambda_handler"
  runtime          = "python3.10"
  timeout          = 300
  memory_size      = 512
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256
  layers           = [aws_lambda_layer_version.thumbnail.arn]

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name
      ENVIRONMENT = var.environment
    }
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  tags = var.common_tags
}

resource "aws_lambda_event_source_mapping" "pdf_trigger" {
  event_source_arn = var.sqs_arns["generate_thumbnails_from_pdf"]
  function_name    = aws_lambda_function.generate_thumbnails_from_pdf.arn
  batch_size       = 10
}
