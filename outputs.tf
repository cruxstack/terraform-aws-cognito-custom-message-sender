output "kms_key_arn" {
  value = module.kms_key.key_arn
}

output "email_lambda_fn_arn" {
  value = local.email_sender_enabled ? aws_lambda_function.email_msg_sender[0].arn : ""
}

output "sms_lambda_fn_arn" {
  value = local.sms_sender_enabled ? aws_lambda_function.sms_msg_sender[0].arn : ""
}
