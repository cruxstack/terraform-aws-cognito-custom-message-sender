locals {
  name = "tf-example-${random_string.example_random_suffix.result}"
  tags = { tf_module = "cruxstack/cognito-custom-message-sender/aws", tf_module_example = "complete" }
}

# ================================================================== example ===

module "cognito_custom_message_sender" {
  source = "../.."

  # email sender
  email_sender_enabled        = true
  email_sender_policy_content = file("${path.module}/fixtures/email_policy.rego")
  email_sender_providers      = ["ses"]

  # sms sender
  sms_sender_enabled        = true
  sms_sender_policy_content = file("${path.module}/fixtures/sms_policy.rego")

  # rate limiting; both channels share one table
  email_sender_rate_limit = { enabled = true }
  sms_sender_rate_limit = {
    enabled = true
    global  = { mode = "count" }
    classes = {
      authentication = { global = [{ window = "1h", max = 1000 }] }
    }
  }

  # failover to sendgrid (uncomment; the policy must return a sendgrid template)
  # email_sender_providers      = ["ses", "sendgrid"]
  # sendgrid_email_send_api_key = var.sendgrid_email_send_api_key

  # async retries (defaults shown, plus an optional failure destination)
  # email_sender_event_invoke_config = {
  #   maximum_event_age_in_seconds = 300
  #   maximum_retry_attempts       = 1
  #   on_failure_destination_arn   = "arn:aws:sqs:us-east-1:123456789012:example-dlq"
  # }

  context = module.example_label.context
}

module "cognito_userpool" {
  source  = "cruxstack/cognito-userpool/aws"
  version = "1.10.0"

  deletion_protection      = false
  admin_create_user_config = { allow_admin_create_user_only = true }

  lambda_config = {
    kms_key_id          = module.cognito_custom_message_sender.kms_key_arn
    custom_sms_sender   = { lambda_arn = module.cognito_custom_message_sender.sms_lambda_fn_arn, lambda_version = "V1_0" }
    custom_email_sender = { lambda_arn = module.cognito_custom_message_sender.email_lambda_fn_arn, lambda_version = "V1_0" }
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
