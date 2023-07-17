module "aws_cognito_user_pool_simple" {
  source  = "lgallard/cognito-user-pool/aws"
  version = "0.22.0"

  user_pool_name = "example-user-pool-with-custom-sms-sender"

  lambda_config = {
    kms_key_id        = module.cognito_custom_sms_sender.kms_key_arn
    custom_sms_sender = { lambda_arn = module.cognito_custom_sms_sender.lambda_fn_arn, lambda_version = "V1_0" }
  }
}

module "cognito_custom_sms_sender" {
  source = "../.."

  sms_sender_enabled                    = true
  sms_sender_policy_content             = file("${path.module}/fixtures/policy.rego")
  sms_sender_throttle_period_in_minutes = 15
}
