resource "aws_sqs_queue" "generate_thumbnails_from_image" {
  name                       = "doodle-${var.environment}-generateThumbnailsFromImage"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  tags                       = var.common_tags
}

resource "aws_sqs_queue" "generate_thumbnails_from_pdf" {
  name                       = "doodle-${var.environment}-generateThumbnailsFromPdf"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  tags                       = var.common_tags
}

resource "aws_sqs_queue" "html_conversion" {
  name                       = "pdf-converter-${var.environment}-html-conversion-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  tags                       = var.common_tags
}

resource "aws_sqs_queue" "office_conversion" {
  name                       = "pdf-converter-${var.environment}-office-conversion-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  tags                       = var.common_tags
}
