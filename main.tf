locals {
  name            = coalesce(module.this.name, var.name, "cognito-custom-message-sender")
  enabled         = module.this.enabled
  aws_account_id  = try(coalesce(var.aws_account_id, data.aws_caller_identity.current[0].account_id), "")
  aws_region_name = try(coalesce(var.aws_region_name, data.aws_region.current[0].region), "")
  aws_partition   = one(data.aws_partition.current[*].partition)

  email_sender_enabled = local.enabled && var.email_sender_enabled
  sms_sender_enabled   = local.enabled && var.sms_sender_enabled
  sender_enabled       = local.email_sender_enabled || local.sms_sender_enabled

  # both lambdas run the same go binary; each is packaged with its policy
  email_sender_policy_path = "./policy.rego"
  sms_sender_policy_path   = "./sms-policy.rego"
  sender_goarch            = var.lambda_architecture == "arm64" ? "arm64" : "amd64"

  sms_history_enabled = local.sms_sender_enabled && var.sms_sender_history_enabled

  email_rate_limit         = var.email_sender_rate_limit
  email_rate_limit_enabled = local.email_sender_enabled && local.email_rate_limit.enabled
  sms_rate_limit           = var.sms_sender_rate_limit
  sms_rate_limit_enabled   = local.sms_sender_enabled && local.sms_rate_limit.enabled
  rate_limit_enabled       = local.email_rate_limit_enabled || local.sms_rate_limit_enabled

  # mirror the APP_EMAIL_RATE_LIMIT_CONFIG and APP_SMS_RATE_LIMIT_CONFIG
  # schemas of the go sender
  email_rate_limit_config = {
    failMode        = local.email_rate_limit.fail_mode
    timeout         = local.email_rate_limit.timeout
    dedupeTtl       = local.email_rate_limit.dedupe_ttl
    metricNamespace = local.email_rate_limit.metric_namespace
    userKey         = local.email_rate_limit.user_key
    normalize = {
      stripPlusTag   = local.email_rate_limit.normalize.strip_plus_tag
      stripGmailDots = local.email_rate_limit.normalize.strip_gmail_dots
    }
    exempt = local.email_rate_limit.exempt
    global = {
      mode            = local.email_rate_limit.global.mode
      shards          = local.email_rate_limit.global.shards
      degradeFraction = local.email_rate_limit.global.degrade_fraction
    }
    classes = { for name, c in local.email_rate_limit.classes : name => {
      destination = c.destination
      user        = c.user
      global      = c.global
      globalMode  = c.global_mode
    } }
  }

  sms_rate_limit_config = {
    failMode        = local.sms_rate_limit.fail_mode
    timeout         = local.sms_rate_limit.timeout
    dedupeTtl       = local.sms_rate_limit.dedupe_ttl
    metricNamespace = local.sms_rate_limit.metric_namespace
    userKey         = local.sms_rate_limit.user_key
    exempt          = local.sms_rate_limit.exempt
    global = {
      mode            = local.sms_rate_limit.global.mode
      shards          = local.sms_rate_limit.global.shards
      degradeFraction = local.sms_rate_limit.global.degrade_fraction
    }
    classes = { for name, c in local.sms_rate_limit.classes : name => {
      destination = c.destination
      user        = c.user
      global      = c.global
      globalMode  = c.global_mode
    } }
  }

  # settings shared by both lambdas
  sender_environment = {
    APP_LOG_LEVEL    = var.service_log_level
    APP_SEND_ENABLED = true
    APP_KMS_KEY_ID   = module.kms_key.key_arn
  }

  # actions the execution role needs to deliver failed async events
  failure_destination_actions = {
    events = ["events:PutEvents"]
    lambda = ["lambda:InvokeFunction"]
    s3     = ["s3:ListBucket", "s3:PutObject"]
    sns    = ["sns:Publish"]
    sqs    = ["sqs:SendMessage"]
  }
  failure_destination_arns = toset(compact([
    local.email_sender_enabled ? try(var.email_sender_event_invoke_config.on_failure_destination_arn, null) : null,
    local.sms_sender_enabled ? try(var.sms_sender_event_invoke_config.on_failure_destination_arn, null) : null,
  ]))

  iam_role_policies = {
    access = one(data.aws_iam_policy_document.this[*].json)
  }
}

data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
}

data "aws_region" "current" {
  count = local.enabled ? 1 : 0
}

data "aws_partition" "current" {
  count = module.this.enabled ? 1 : 0
}


# ============================================================ message-sender ===

module "message_sender_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name    = local.name
  context = module.this.context
}

# ---------------------------------------------------------------------- kms ---

module "kms_key" {
  source  = "cloudposse/kms-key/aws"
  version = "0.12.2"

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

  tags = module.message_sender_label.tags
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  count = module.this.enabled ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:${local.aws_partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "this" {
  for_each = { for k, v in local.iam_role_policies : k => v if module.this.enabled }

  name   = each.key
  role   = resource.aws_iam_role.this[0].name
  policy = each.value
}

data "aws_iam_policy_document" "this" {
  count = local.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      module.kms_key.key_arn,
    ]
  }

  dynamic "statement" {
    for_each = local.email_sender_enabled ? [true] : []
    content {
      effect = "Allow"
      actions = [
        "ses:GetAccount",
        "ses:GetTemplate",
        "ses:SendEmail",
        "ses:SendTemplatedEmail",
      ]
      resources = [
        "*"
      ]
    }
  }

  dynamic "statement" {
    for_each = local.sms_sender_enabled ? [true] : []
    content {
      effect = "Allow"
      actions = [
        "sns:Publish"
      ]
      resources = [
        "*"
      ]
    }
  }

  dynamic "statement" {
    for_each = local.sms_history_enabled ? [true] : []
    content {
      effect = "Allow"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:Query",
      ]
      resources = [
        aws_dynamodb_table.sms_history[0].arn,
        "${aws_dynamodb_table.sms_history[0].arn}/index/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = local.rate_limit_enabled ? [true] : []
    content {
      effect = "Allow"
      actions = [
        "dynamodb:BatchGetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
      ]
      resources = [
        aws_dynamodb_table.rate_limit[0].arn,
      ]
    }
  }

  dynamic "statement" {
    for_each = local.failure_destination_arns
    content {
      effect    = "Allow"
      actions   = local.failure_destination_actions[split(":", statement.value)[2]]
      resources = split(":", statement.value)[2] == "s3" ? [statement.value, "${statement.value}/*"] : [statement.value]

      # keeps records from reaching a same-named bucket in another account
      dynamic "condition" {
        for_each = split(":", statement.value)[2] == "s3" ? [true] : []
        content {
          test     = "StringEquals"
          variable = "s3:ResourceAccount"
          values   = [local.aws_account_id]
        }
      }
    }
  }

  depends_on = [
    module.kms_key
  ]
}

# ------------------------------------------------------------------ artifact ---

resource "terraform_data" "email_msg_sender_policy" {
  count = local.email_sender_enabled ? 1 : 0

  input = base64encode(var.email_sender_policy_content)

  lifecycle {
    precondition {
      condition     = can(regex("(?m)^package cognito_custom_sender_email_policy\\b", var.email_sender_policy_content))
      error_message = "The email sender policy content must declare 'package cognito_custom_sender_email_policy'."
    }

    precondition {
      condition     = !contains(var.email_sender_providers, "sendgrid") || var.sendgrid_email_send_api_key != ""
      error_message = "sendgrid_email_send_api_key is required when 'sendgrid' is in email_sender_providers."
    }

    precondition {
      condition     = !var.email_verification_enabled || var.email_verification_provider != "sendgrid" || var.sendgrid_email_verification_api_key != ""
      error_message = "sendgrid_email_verification_api_key is required when email_verification_provider is 'sendgrid'."
    }
  }
}

resource "terraform_data" "sms_msg_sender_policy" {
  count = local.sms_sender_enabled ? 1 : 0

  input = base64encode(var.sms_sender_policy_content)

  lifecycle {
    precondition {
      condition     = can(regex("(?m)^package cognito_custom_sender_sms_policy\\b", var.sms_sender_policy_content))
      error_message = "The SMS sender policy content must declare 'package cognito_custom_sender_sms_policy'."
    }
  }
}

# transitional: forget pre-buildkit artifact modules from state on upgrade
removed {
  from = module.sms_msg_sender_code

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.email_msg_sender_code

  lifecycle {
    destroy = false
  }
}

# transitional: v3 built one artifact per sender; v4 builds one for both
removed {
  from = buildkit_artifact.sms_msg_sender

  lifecycle {
    destroy = false
  }
}

removed {
  from = buildkit_artifact.email_msg_sender

  lifecycle {
    destroy = false
  }
}

data "buildkit_context" "sender" {
  count = local.sender_enabled ? 1 : 0

  path = abspath("${path.module}/assets/sender")
}

# the go sender (cruxstack/cognito-custom-message-sender-go) built at
# sender_version, packaged with the email and sms policies
resource "buildkit_artifact" "sender" {
  count = local.sender_enabled ? 1 : 0

  build_context     = abspath("${path.module}/assets/sender")
  dockerfile        = "Dockerfile"
  target            = "package"
  artifact_src_path = "/tmp/package.zip"
  artifact_src_type = "zip"
  artifact_dst_path = "${path.module}/dist/sender/package.zip"

  build_args = {
    APP_VERSION          = var.sender_version
    GOARCH               = local.sender_goarch
    EMAIL_POLICY_ENCODED = try(terraform_data.email_msg_sender_policy[0].output, "")
    SMS_POLICY_ENCODED   = try(terraform_data.sms_msg_sender_policy[0].output, "")
  }

  triggers = {
    context          = data.buildkit_context.sender[0].digest
    app_version      = var.sender_version
    goarch           = local.sender_goarch
    force_rebuild_id = var.sender_force_rebuild_id
  }
}

# ---------------------------------------------------------------------- ddb ---

module "rate_limit_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["rate-limit"]
  context    = module.message_sender_label.context
}

moved {
  from = aws_dynamodb_table.email_rate_limit
  to   = aws_dynamodb_table.rate_limit
}

# counters and retry markers for email and sms rate limiting; the sender keys
# items by channel, and items expire via ttl
resource "aws_dynamodb_table" "rate_limit" {
  count = local.rate_limit_enabled ? 1 : 0

  name         = module.rate_limit_label.id
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = module.rate_limit_label.tags
}


# =============================================================== sms-sender ===

module "sms_msg_sender_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["sms"]
  context    = module.message_sender_label.context
}

resource "aws_cloudwatch_log_group" "sms_msg_sender" {
  count = local.sms_sender_enabled ? 1 : 0

  name              = "/aws/lambda/${module.sms_msg_sender_label.id}"
  retention_in_days = 90
  tags              = module.sms_msg_sender_label.tags
}

resource "aws_lambda_function" "sms_msg_sender" {
  count = local.sms_sender_enabled ? 1 : 0

  function_name    = module.sms_msg_sender_label.id
  filename         = buildkit_artifact.sender[0].artifact_path
  source_code_hash = buildkit_artifact.sender[0].artifact_sha256
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = [var.lambda_architecture]
  timeout          = 10
  role             = aws_iam_role.this[0].arn
  layers           = []

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = merge(local.sender_environment, {
      APP_EMAIL_SENDER_ENABLED   = false
      APP_SMS_SENDER_ENABLED     = true
      APP_SMS_SENDER_POLICY_PATH = local.sms_sender_policy_path
      APP_SMS_THROTTLE_PERIOD    = "${var.sms_sender_throttle_period_in_minutes}m"
      }, local.sms_history_enabled ? {
      APP_SMS_HISTORY_TABLE_NAME = aws_dynamodb_table.sms_history[0].name
      APP_SMS_HISTORY_TTL        = "720h"
      } : {}, local.sms_rate_limit_enabled ? {
      APP_SMS_RATE_LIMIT_ENABLED    = true
      APP_SMS_RATE_LIMIT_TABLE_NAME = aws_dynamodb_table.rate_limit[0].name
      APP_SMS_RATE_LIMIT_CONFIG     = jsonencode(local.sms_rate_limit_config)
    } : {})
  }

  tags = module.sms_msg_sender_label.tags

  depends_on = [
    buildkit_artifact.sender,
    aws_cloudwatch_log_group.sms_msg_sender,
  ]
}

resource "aws_lambda_function_event_invoke_config" "sms_msg_sender" {
  count = local.sms_sender_enabled && var.sms_sender_event_invoke_config != null ? 1 : 0

  function_name                = aws_lambda_function.sms_msg_sender[0].function_name
  maximum_event_age_in_seconds = var.sms_sender_event_invoke_config.maximum_event_age_in_seconds
  maximum_retry_attempts       = var.sms_sender_event_invoke_config.maximum_retry_attempts

  dynamic "destination_config" {
    for_each = var.sms_sender_event_invoke_config.on_failure_destination_arn != null ? [var.sms_sender_event_invoke_config.on_failure_destination_arn] : []
    content {
      on_failure {
        destination = destination_config.value
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.this,
  ]
}

resource "aws_lambda_permission" "sms_msg_sender" {
  count = local.sms_sender_enabled ? 1 : 0

  statement_id  = "allow-cognito-trigger"
  function_name = aws_lambda_function.sms_msg_sender[0].function_name
  action        = "lambda:InvokeFunction"
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${local.aws_region_name}:${local.aws_account_id}:userpool/*"
}

# ---------------------------------------------------------------------- ddb ---

module "sms_history_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["sms-history"]
  context    = module.sms_msg_sender_label.context
}

# the layout of the earlier node.js sender, which the go sender keeps
resource "aws_dynamodb_table" "sms_history" {
  count = local.sms_history_enabled ? 1 : 0

  name         = module.sms_history_label.id
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
    name = "userSid-index"
    key_schema {
      attribute_name = "userId"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "sentAtEpoch"
      key_type       = "RANGE"
    }
    projection_type = "ALL"
  }

  global_secondary_index {
    name = "userPhoneNumber-index"
    key_schema {
      attribute_name = "userPhoneNumber"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "sentAtEpoch"
      key_type       = "RANGE"
    }
    projection_type = "ALL"
  }

  tags = module.sms_history_label.tags
}


# ============================================================= email-sender ===

module "email_msg_sender_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["email"]
  context    = module.message_sender_label.context
}

resource "aws_cloudwatch_log_group" "email_msg_sender" {
  count = local.email_sender_enabled ? 1 : 0

  name              = "/aws/lambda/${module.email_msg_sender_label.id}"
  retention_in_days = 90
  tags              = module.email_msg_sender_label.tags
}

resource "aws_lambda_function" "email_msg_sender" {
  count = local.email_sender_enabled ? 1 : 0

  function_name    = module.email_msg_sender_label.id
  filename         = buildkit_artifact.sender[0].artifact_path
  source_code_hash = buildkit_artifact.sender[0].artifact_sha256
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = [var.lambda_architecture]
  timeout          = 10
  role             = aws_iam_role.this[0].arn
  layers           = []

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = merge(local.sender_environment, {
      APP_EMAIL_SENDER_ENABLED                = true
      APP_EMAIL_SENDER_POLICY_PATH            = local.email_sender_policy_path
      APP_EMAIL_PROVIDERS                     = join(",", var.email_sender_providers)
      APP_EMAIL_HEALTH_CHECK_TTL              = var.email_health_check_ttl
      APP_EMAIL_VERIFICATION_ENABLED          = var.email_verification_enabled
      APP_EMAIL_VERIFICATION_PROVIDER         = var.email_verification_provider
      APP_EMAIL_VERIFICATION_ALLOWLIST        = join(",", var.email_verification_allowlist)
      APP_SENDGRID_API_HOST                   = var.sendgrid_api_host
      APP_SENDGRID_EMAIL_SEND_API_KEY         = var.sendgrid_email_send_api_key
      APP_SENDGRID_EMAIL_VERIFICATION_API_KEY = var.sendgrid_email_verification_api_key
      }, local.email_rate_limit_enabled ? {
      APP_EMAIL_RATE_LIMIT_ENABLED    = true
      APP_EMAIL_RATE_LIMIT_TABLE_NAME = aws_dynamodb_table.rate_limit[0].name
      APP_EMAIL_RATE_LIMIT_CONFIG     = jsonencode(local.email_rate_limit_config)
    } : {})
  }

  tags = module.email_msg_sender_label.tags

  depends_on = [
    buildkit_artifact.sender,
    aws_cloudwatch_log_group.email_msg_sender,
  ]
}

# cognito invokes custom sender triggers asynchronously; its codes expire within
# minutes, so a late retry rarely helps the user
resource "aws_lambda_function_event_invoke_config" "email_msg_sender" {
  count = local.email_sender_enabled && var.email_sender_event_invoke_config != null ? 1 : 0

  function_name                = aws_lambda_function.email_msg_sender[0].function_name
  maximum_event_age_in_seconds = var.email_sender_event_invoke_config.maximum_event_age_in_seconds
  maximum_retry_attempts       = var.email_sender_event_invoke_config.maximum_retry_attempts

  dynamic "destination_config" {
    for_each = var.email_sender_event_invoke_config.on_failure_destination_arn != null ? [var.email_sender_event_invoke_config.on_failure_destination_arn] : []
    content {
      on_failure {
        destination = destination_config.value
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.this,
  ]
}

resource "aws_lambda_permission" "email_msg_sender" {
  count = local.email_sender_enabled ? 1 : 0

  statement_id  = "allow-cognito-trigger"
  function_name = aws_lambda_function.email_msg_sender[0].function_name
  action        = "lambda:InvokeFunction"
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${local.aws_region_name}:${local.aws_account_id}:userpool/*"
}
