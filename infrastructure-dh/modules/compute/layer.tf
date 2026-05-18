resource "aws_lambda_layer_version" "thumbnail" {
  layer_name          = "layer-thumbnail-${var.environment}"
  filename            = "${path.module}/../../externalResource/layer_thumbnail.zip"
  source_code_hash    = filebase64sha256("${path.module}/../../externalResource/layer_thumbnail.zip")
  compatible_runtimes = ["python3.10"]
}
