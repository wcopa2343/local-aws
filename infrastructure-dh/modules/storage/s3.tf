resource "aws_s3_bucket" "main" {
  bucket        = "s3-demo-sds-dh-${var.environment}"
  force_destroy = true
  tags          = var.common_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "delete-after-7-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}
