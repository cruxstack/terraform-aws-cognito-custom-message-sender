output "kms_key_arn" {
  value = module.kms_key.key_arn
}

output "lambda_fn_arn" {
  value = local.enabled ? aws_lambda_function.message_sender[0].arn : ""
}
