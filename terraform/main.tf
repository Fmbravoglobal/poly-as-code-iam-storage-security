terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

############################################
# KMS KEY FOR S3 ENCRYPTION
############################################
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for secure S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "s3-kms-key"
    Environment = "dev"
    Project     = "poly-as-code-iam-storage-security"
  }
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/secure-s3-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

############################################
# MAIN SECURE S3 BUCKET
############################################
#checkov:skip=CKV_AWS_144:Cross-region replication is outside the scope of this demo governance project
resource "aws_s3_bucket" "secure_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = "dev"
    Project     = "poly-as-code-iam-storage-security"
  }
}

resource "aws_s3_bucket_public_access_block" "secure_bucket" {
  bucket                  = aws_s3_bucket.secure_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "default-lifecycle"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  depends_on = [aws_s3_bucket_versioning.secure_bucket]
}

############################################
# LOGGING BUCKET
############################################
#checkov:skip=CKV_AWS_144:Cross-region replication is outside the scope of this demo governance project
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.bucket_name}-logs"

  tags = {
    Name        = "${var.bucket_name}-logs"
    Environment = "dev"
    Project     = "poly-as-code-iam-storage-security"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.log_bucket]
}

resource "aws_s3_bucket_logging" "secure_bucket_logging" {
  bucket        = aws_s3_bucket.secure_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}

############################################
# SNS TOPIC FOR S3 EVENT NOTIFICATIONS
############################################
resource "aws_sns_topic" "bucket_events" {
  name              = "${var.bucket_name}-events"
  kms_master_key_id = aws_kms_key.s3_key.arn

  tags = {
    Name        = "${var.bucket_name}-events"
    Environment = "dev"
    Project     = "poly-as-code-iam-storage-security"
  }
}

data "aws_iam_policy_document" "bucket_events_policy" {
  statement {
    sid    = "AllowS3Publish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.bucket_events.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.secure_bucket.arn]
    }
  }

  statement {
    sid    = "AllowLogBucketPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.bucket_events.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.log_bucket.arn]
    }
  }
}

resource "aws_sns_topic_policy" "bucket_events" {
  arn    = aws_sns_topic.bucket_events.arn
  policy = data.aws_iam_policy_document.bucket_events_policy.json
}

resource "aws_s3_bucket_notification" "secure_bucket_notification" {
  bucket = aws_s3_bucket.secure_bucket.id

  topic {
    topic_arn = aws_sns_topic.bucket_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.bucket_events]
}

resource "aws_s3_bucket_notification" "log_bucket_notification" {
  bucket = aws_s3_bucket.log_bucket.id

  topic {
    topic_arn = aws_sns_topic.bucket_events.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.bucket_events]
}

############################################
# IAM ROLE
############################################
resource "aws_iam_role" "app_role" {
  name = "secure-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "secure-app-role"
    Environment = "dev"
    Project     = "poly-as-code-iam-storage-security"
  }
}

############################################
# LEAST-PRIVILEGE IAM POLICY
############################################
resource "aws_iam_policy" "s3_readonly_policy" {
  name        = "secure-s3-readonly-policy"
  description = "Least privilege policy for reading from secure S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.secure_bucket.arn
        ]
      },
      {
        Sid    = "AllowGetObject"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.secure_bucket.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "secure-s3-readonly-policy"
    Environment = "dev"
    Project     = "poly-as-code-iam-storage-security"
  }
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.s3_readonly_policy.arn
}
