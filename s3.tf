############################################
# S3
############################################
# s3の作成
resource "aws_s3_bucket" "tf_s3_demo" {
  bucket = "tf-rikuya-ssan-demo"
}

# バージョニングの有効化
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.tf_s3_demo.id
  versioning_configuration {
    status = "Enabled"
  }
}

# パブリックアクセスの無効化
resource "aws_s3_bucket_public_access_block" "access-example" {
  bucket = aws_s3_bucket.tf_s3_demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
