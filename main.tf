locals {
  name            = coalesce(module.this.name, var.name, "cognito-custom-message-sender")
  enabled         = module.this.enabled
  aws_account_id  = try(coalesce(var.aws_account_id, data.aws_caller_identity.current[0].account_id), "")
  aws_region_name = try(coalesce(var.aws_region_name, data.aws_region.current[0].name), "")

  email_sender_enabled = false

  sms_sender_enabled                    = local.enabled && var.sms_sender_enabled
  sms_sender_policy_path                = "./policy.wasm"
  sms_sender_policy_content             = var.sms_sender_policy_content
  sms_sender_throttle_period_in_minutes = 15
}

data "aws_caller_identity" "current" {
  count = local.enabled && var.aws_account_id == "" ? 1 : 0
}

data "aws_region" "current" {
  count = local.enabled && var.aws_region_name == "" ? 1 : 0
}

# ============================================================ message-sender ===

module "message_sender_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name    = local.name
  context = module.this.context
}

module "message_sender_code" {
  source  = "sgtoj/artifact-packager/docker"
  version = "1.3.1"

  artifact_src_path    = "/tmp/package.zip"
  docker_build_context = abspath("${path.module}/assets/custom-message-sender")
  docker_build_target  = "package"

  docker_build_args = {
    SERVICE_OPA_POLICY_ENCODED = base64encode(local.sms_sender_policy_content)
  }

  context = module.message_sender_label.context
}

resource "aws_cloudwatch_log_group" "message_sender" {
  count = local.enabled ? 1 : 0

  name              = "/aws/lambda/${module.message_sender_label.id}"
  retention_in_days = 90
  tags              = module.message_sender_label.tags
}

resource "aws_lambda_function" "message_sender" {
  count = module.message_sender_label.enabled ? 1 : 0

  function_name = module.message_sender_label.id
  filename      = module.message_sender_code.artifact_package_path
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 45
  role          = aws_iam_role.this[0].arn
  layers        = []

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      LOG_LEVEL                      = var.service_log_level
      KMS_KEY_ID                     = module.kms_key.key_arn
      DDB_TABLE_HISTORY_NAME         = aws_dynamodb_table.history[0].name
      DDB_TABLE_HISTORY_TTL          = 43200
      EMAIL_SENDER_ENABLED           = local.email_sender_enabled
      SMS_SENDER_ENABLED             = local.sms_sender_enabled
      SMS_SENDER_POLICY_PATH         = local.sms_sender_policy_path
      SMS_THROTTLE_PERIOD_IN_MINUTES = local.sms_sender_throttle_period_in_minutes
    }
  }

  tags = module.message_sender_label.tags

  depends_on = [
    module.message_sender_code,
    aws_cloudwatch_log_group.message_sender,
  ]
}

resource "aws_lambda_permission" "message_sender" {
  count = module.message_sender_label.enabled ? 1 : 0

  statement_id  = "allow-cognito-trigger"
  function_name = aws_lambda_function.message_sender[0].function_name
  action        = "lambda:InvokeFunction"
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${local.aws_region_name}:${local.aws_account_id}:userpool/*"
}

# ---------------------------------------------------------------------- ddb ---

module "history_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["history"]
  context    = module.message_sender_label.context
}

resource "aws_dynamodb_table" "history" {
  count = module.message_sender_label.enabled ? 1 : 0

  name         = module.history_label.id
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "historyId"
  range_key = "sentAtEpoch"

  attribute {
    name = "historyId"
    type = "S"
  }

  attribute {
    name = "sentAtEpoch"
    type = "N"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "userPhoneNumber"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  global_secondary_index {
    name            = "userSid-index"
    hash_key        = "userId"
    range_key       = "sentAtEpoch"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "userPhoneNumber-index"
    hash_key        = "userPhoneNumber"
    range_key       = "sentAtEpoch"
    projection_type = "ALL"
  }

  tags = module.history_label.tags
}

# ---------------------------------------------------------------------- kms ---

module "kms_key" {
  source  = "cloudposse/kms-key/aws"
  version = "0.12.1"

  alias                   = "${var.kms_key_alias_prefix}/${module.message_sender_label.name}"
  deletion_window_in_days = 7

  context = module.message_sender_label.context
}

# ---------------------------------------------------------------------- iam ---

resource "aws_iam_role" "this" {
  count = local.enabled ? 1 : 0

  name        = module.message_sender_label.id
  description = ""

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { "Service" : "lambda.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  inline_policy {
    name   = "message-sender-access"
    policy = data.aws_iam_policy_document.this[0].json
  }

  tags = module.message_sender_label.tags
}

data "aws_iam_policy_document" "this" {
  count = local.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      module.kms_key.key_arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ses:GetTemplate",
      "ses:SendEmail"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:*Item*",
    ]
    resources = [
      aws_dynamodb_table.history[0].arn,
      "${aws_dynamodb_table.history[0].arn}/*"
    ]
  }

  depends_on = [
    module.kms_key
  ]
}
