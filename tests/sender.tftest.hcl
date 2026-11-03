# Plans the module with mocked providers, so these tests need no AWS account
# and build nothing. Run with: terraform test

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/test"
    }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = {
      arn = "arn:aws:dynamodb:us-east-1:111122223333:table/test"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:111122223333:key/example"
    }
  }
}

mock_provider "buildkit" {}

variables {
  name                        = "test"
  aws_account_id              = "111122223333"
  aws_region_name             = "us-east-1"
  email_sender_policy_content = "package cognito_custom_sender_email_policy\nresult := {}"
  sms_sender_policy_content   = "# a comment first\npackage cognito_custom_sender_sms_policy\nresult := {}"
}

run "email_only" {
  command = plan

  variables {
    email_sender_enabled = true
  }

  assert {
    condition     = length(aws_lambda_function.email_msg_sender) == 1 && length(aws_lambda_function.sms_msg_sender) == 0
    error_message = "only the email sender lambda should be planned"
  }

  assert {
    condition     = length(buildkit_artifact.sender) == 1 && buildkit_artifact.sender[0].build_args.SMS_POLICY_ENCODED == ""
    error_message = "one artifact should be built, without an sms policy"
  }

  assert {
    condition     = aws_lambda_function.email_msg_sender[0].runtime == "provided.al2023" && aws_lambda_function.email_msg_sender[0].architectures[0] == "arm64"
    error_message = "the email sender should run the go binary on arm64"
  }

  assert {
    condition = alltrue([
      aws_lambda_function.email_msg_sender[0].environment[0].variables.APP_EMAIL_PROVIDERS == "ses",
      aws_lambda_function.email_msg_sender[0].environment[0].variables.APP_EMAIL_SENDER_POLICY_PATH == "./policy.rego",
      aws_lambda_function.email_msg_sender[0].environment[0].variables.APP_EMAIL_HEALTH_CHECK_TTL == "30s",
      !contains(keys(aws_lambda_function.email_msg_sender[0].environment[0].variables), "APP_EMAIL_RATE_LIMIT_ENABLED"),
    ])
    error_message = "the email sender environment should follow the v3 sender contract"
  }

  assert {
    condition = length(setintersection(keys(aws_lambda_function.email_msg_sender[0].environment[0].variables), [
      "APP_DEBUG_MODE", "APP_EMAIL_PROVIDER", "APP_EMAIL_FAILOVER_ENABLED", "APP_EMAIL_FAILOVER_PROVIDERS",
      "APP_EMAIL_FAILOVER_CACHE_TTL", "APP_EMAIL_VERIFICATION_WHITELIST",
    ])) == 0
    error_message = "the email sender environment must not set variables the v3 sender rejects"
  }

  assert {
    condition     = length(aws_dynamodb_table.rate_limit) == 0 && length(aws_dynamodb_table.sms_history) == 0
    error_message = "no tables should be created"
  }
}

run "email_and_sms_with_rate_limits" {
  command = plan

  variables {
    email_sender_enabled   = true
    email_sender_providers = ["ses", "sendgrid"]
    sms_sender_enabled     = true
    lambda_architecture    = "x86_64"

    sendgrid_email_send_api_key = "SG.example"

    email_sender_rate_limit = { enabled = true }
    sms_sender_rate_limit = {
      enabled = true
      classes = { authentication = { global = [{ window = "1h", max = 100 }] } }
    }
  }

  assert {
    condition     = length(aws_dynamodb_table.rate_limit) == 1
    error_message = "email and sms should share one rate limit table"
  }

  assert {
    condition     = buildkit_artifact.sender[0].build_args.GOARCH == "amd64" && aws_lambda_function.sms_msg_sender[0].architectures[0] == "x86_64"
    error_message = "x86_64 should build an amd64 binary"
  }

  assert {
    condition     = aws_lambda_function.email_msg_sender[0].environment[0].variables.APP_EMAIL_PROVIDERS == "ses,sendgrid"
    error_message = "providers should be passed in order"
  }

  assert {
    condition = alltrue([
      aws_lambda_function.sms_msg_sender[0].runtime == "provided.al2023",
      aws_lambda_function.sms_msg_sender[0].handler == "bootstrap",
      aws_lambda_function.sms_msg_sender[0].environment[0].variables.APP_EMAIL_SENDER_ENABLED == "false",
      aws_lambda_function.sms_msg_sender[0].environment[0].variables.APP_SMS_SENDER_ENABLED == "true",
      aws_lambda_function.sms_msg_sender[0].environment[0].variables.APP_SMS_SENDER_POLICY_PATH == "./sms-policy.rego",
      aws_lambda_function.sms_msg_sender[0].environment[0].variables.APP_SMS_THROTTLE_PERIOD == "15m",
      aws_lambda_function.sms_msg_sender[0].environment[0].variables.APP_SMS_RATE_LIMIT_ENABLED == "true",
    ])
    error_message = "the sms sender should run the go binary with sms settings"
  }

  assert {
    condition     = jsondecode(aws_lambda_function.sms_msg_sender[0].environment[0].variables.APP_SMS_RATE_LIMIT_CONFIG).classes.authentication.global[0].max == 100
    error_message = "the sms rate limit config should be passed to the sender"
  }

  assert {
    condition     = !can(jsondecode(aws_lambda_function.sms_msg_sender[0].environment[0].variables.APP_SMS_RATE_LIMIT_CONFIG).normalize)
    error_message = "the sms rate limit config must not include email-only settings"
  }

  assert {
    condition     = length(aws_lambda_function_event_invoke_config.sms_msg_sender) == 1 && aws_lambda_function_event_invoke_config.sms_msg_sender[0].maximum_retry_attempts == 1
    error_message = "the sms sender should get the async invocation defaults"
  }
}

run "sms_without_history" {
  command = plan

  variables {
    sms_sender_enabled         = true
    sms_sender_history_enabled = false
  }

  assert {
    condition     = length(aws_dynamodb_table.sms_history) == 0
    error_message = "the history table should not be created"
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.sms_msg_sender[0].environment[0].variables), "APP_SMS_HISTORY_TABLE_NAME")
    error_message = "the sms sender should not get a history table"
  }
}

run "sendgrid_requires_a_key" {
  command = plan

  variables {
    email_sender_enabled   = true
    email_sender_providers = ["ses", "sendgrid"]
  }

  expect_failures = [terraform_data.email_msg_sender_policy]
}

run "rejects_unknown_providers" {
  command = plan

  variables {
    email_sender_enabled   = true
    email_sender_providers = ["ses", "mailgun"]
  }

  expect_failures = [var.email_sender_providers]
}

run "rejects_email_only_settings_for_sms" {
  command = plan

  variables {
    sms_sender_enabled = true
    sms_sender_rate_limit = {
      enabled = true
      exempt  = { classes = ["notification"] }
    }
  }

  expect_failures = [var.sms_sender_rate_limit]
}
