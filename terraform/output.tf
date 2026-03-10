output "bucket_name" {
  description = "Name of the secure S3 bucket"
  value       = aws_s3_bucket.secure_bucket.bucket
}

output "bucket_arn" {
  description = "ARN of the secure S3 bucket"
  value       = aws_s3_bucket.secure_bucket.arn
}

output "log_bucket_name" {
  description = "Name of the logging bucket"
  value       = aws_s3_bucket.log_bucket.bucket
}

output "log_bucket_arn" {
  description = "ARN of the logging bucket"
  value       = aws_s3_bucket.log_bucket.arn
}

output "iam_role_name" {
  description = "IAM role for secure application access"
  value       = aws_iam_role.app_role.name
}

output "policy_arn" {
  description = "ARN of the least privilege IAM policy"
  value       = aws_iam_policy.s3_readonly_policy.arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for S3 event notifications"
  value       = aws_sns_topic.bucket_events.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for S3 encryption"
  value       = aws_kms_key.s3_key.arn
}
