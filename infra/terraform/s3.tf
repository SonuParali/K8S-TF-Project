resource "aws_s3_bucket" "static" {
  bucket        = "${var.project_name}-static-assets"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

output "s3_bucket_name" {
  value = aws_s3_bucket.static.id
}