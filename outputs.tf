output "kms_key_arn" {
  description = "ARN of the KMS key Cognito encrypts codes with. Set it as the user pool's lambda_config.kms_key_id."
  value       = module.kms_key.key_arn
}

output "email_lambda_fn_arn" {
  description = "ARN of the email sender Lambda (empty when disabled). Set it as the user pool's custom email sender."
  value       = local.email_sender_enabled ? aws_lambda_function.email_msg_sender[0].arn : ""
}

output "sms_lambda_fn_arn" {
  description = "ARN of the SMS sender Lambda (empty when disabled). Set it as the user pool's custom SMS sender."
  value       = local.sms_sender_enabled ? aws_lambda_function.sms_msg_sender[0].arn : ""
}

output "rate_limit_table_arn" {
  description = "ARN of the DynamoDB table shared by email and SMS rate limiting (empty when both are disabled)."
  value       = local.rate_limit_enabled ? aws_dynamodb_table.rate_limit[0].arn : ""
}

output "sms_history_table_arn" {
  description = "ARN of the SMS history table (empty when the SMS history is disabled)."
  value       = local.sms_history_enabled ? aws_dynamodb_table.sms_history[0].arn : ""
}
