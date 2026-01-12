locals {
  name = "tf-example-${random_string.example_random_suffix.result}"
  tags = { tf_module = "cruxstack/cognito-custom-message-sender/aws", tf_module_example = "complete" }
}

# ================================================================== example ===

module "cognito_custom_message_sender" {
  source = "../.."

  # SMS sender configuration
  sms_sender_enabled                    = true
  sms_sender_policy_content             = file("${path.module}/fixtures/policy.rego")
  sms_sender_throttle_period_in_minutes = 15

  # Email sender configuration (uncomment to enable)
  # email_sender_enabled        = true
  # email_sender_policy_content = file("${path.module}/fixtures/email_policy.rego")
  # email_sender_providers      = ["ses"]

  # Email verification (enabled by default with offline RFC 5322 validation)
  # email_verification_enabled  = true
  # email_verification_provider = "offline"

  # Provider failover configuration (uncomment to enable)
  # email_failover_enabled   = true
  # email_failover_providers = ["sendgrid"]
  # sendgrid_email_send_api_key = var.sendgrid_api_key

  context = module.example_label.context
}

module "cognito_userpool" {
  source  = "cruxstack/cognito-userpool/aws"
  version = "0.1.2"

  deletion_protection      = false
  admin_create_user_config = { allow_admin_create_user_only = true }

  lambda_config = {
    kms_key_id        = module.cognito_custom_message_sender.kms_key_arn
    custom_sms_sender = { lambda_arn = module.cognito_custom_message_sender.sms_lambda_fn_arn, lambda_version = "V1_0" }
    # Uncomment to use email sender
    # custom_email_sender = { lambda_arn = module.cognito_custom_message_sender.email_lambda_fn_arn, lambda_version = "V1_0" }
  }

  context = module.example_label.context
}

# ===================================================== supporting-resources ===

module "example_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = true
  name    = local.name
  tags    = local.tags
  context = module.this.context
}

resource "random_string" "example_random_suffix" {
  length  = 6
  special = false
  upper   = false
}
