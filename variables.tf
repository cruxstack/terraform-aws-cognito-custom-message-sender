# ================================================================== general ===

variable "kms_key_alias_prefix" {
  description = "The prefix for the KMS key alias. It must start with 'alias' and only include alphanumeric characters, dashes, underscores, colons or slashes, but doesn't end with a slash."
  type        = string
  default     = "alias"

  validation {
    condition     = can(regex("^alias[a-zA-Z0-9/_-]*[^/]*$", var.kms_key_alias_prefix))
    error_message = "KMS key alias prefix must start with 'alias' and only have alphanumeric, dashes, underscores, colons or slashes but doesn't end with a slash"
  }
}

variable "service_log_level" {
  description = "The log level of the sender Lambdas: 'debug', 'info', 'warn', or 'error'. 'debug' logs every event, including user attributes."
  type        = string
  default     = "info"

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.service_log_level)
    error_message = "service_log_level must be 'debug', 'info', 'warn', or 'error'."
  }
}

variable "sender_version" {
  description = "Git tag of cruxstack/cognito-custom-message-sender-go to build for both sender Lambdas. 'latest' builds its default branch, which can include breaking changes."
  type        = string
  default     = "v3.0.0"
  nullable    = false
}

variable "sender_force_rebuild_id" {
  description = "Change this value to force a rebuild of the sender artifact."
  type        = string
  default     = ""
  nullable    = false
}

variable "lambda_architecture" {
  description = "Instruction set of the sender Lambdas: 'arm64' (Graviton, lower cost) or 'x86_64'."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "lambda_architecture must be 'arm64' or 'x86_64'."
  }
}

# ------------------------------------------------------------- email-sender ---

variable "email_sender_enabled" {
  description = "Whether or not the email sender is enabled."
  type        = bool
  default     = false
}

variable "email_sender_policy_content" {
  description = "The content of the Rego policy for the email sender. It must declare 'package cognito_custom_sender_email_policy'."
  type        = string
  default     = ""
  nullable    = false
}

variable "email_sender_providers" {
  description = "Email providers to send with, in order: 'ses' and 'sendgrid'. With more than one, an email that the first provider can't send is sent with the next."
  type        = list(string)
  default     = ["ses"]
  nullable    = false

  validation {
    condition     = length(var.email_sender_providers) > 0 && length(distinct(var.email_sender_providers)) == length(var.email_sender_providers)
    error_message = "email_sender_providers must list at least one provider, each once."
  }

  validation {
    condition     = alltrue([for x in var.email_sender_providers : contains(["ses", "sendgrid"], x)])
    error_message = "email_sender_providers can contain only 'ses' and 'sendgrid'."
  }
}

variable "email_health_check_ttl" {
  description = "How long an SES account health check is cached, as a Go duration (for example '30s'). Used when 'ses' is followed by another provider."
  type        = string
  default     = "30s"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]*(ms|s|m|h)$", var.email_health_check_ttl))
    error_message = "email_health_check_ttl must be a positive duration in ms, s, m, or h (for example '30s')."
  }
}

variable "email_verification_enabled" {
  description = "Verify the address before the policy runs and pass the result as input.emailVerification."
  type        = bool
  default     = true
}

variable "email_verification_provider" {
  description = "Email verification provider: 'offline' (syntax check) or 'sendgrid' (SendGrid Email Address Validation)."
  type        = string
  default     = "offline"

  validation {
    condition     = contains(["offline", "sendgrid"], var.email_verification_provider)
    error_message = "email_verification_provider must be 'offline' or 'sendgrid'."
  }
}

variable "email_verification_allowlist" {
  description = "Email domains that are treated as valid without verification."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "email_sender_event_invoke_config" {
  description = "Asynchronous invocation settings for the email sender Lambda. Cognito invokes custom sender triggers asynchronously and its codes expire within minutes, so the default keeps events for 5 minutes and retries once. Set to null to use the AWS defaults (2 retries, events kept for up to 6 hours)."
  type = object({
    maximum_event_age_in_seconds = optional(number, 300)
    maximum_retry_attempts       = optional(number, 1)
    on_failure_destination_arn   = optional(string)
  })
  default = {}

  validation {
    condition     = var.email_sender_event_invoke_config == null || try(var.email_sender_event_invoke_config.maximum_event_age_in_seconds >= 60 && var.email_sender_event_invoke_config.maximum_event_age_in_seconds <= 21600 && floor(var.email_sender_event_invoke_config.maximum_event_age_in_seconds) == var.email_sender_event_invoke_config.maximum_event_age_in_seconds, false)
    error_message = "email_sender_event_invoke_config.maximum_event_age_in_seconds must be an integer between 60 and 21600."
  }

  validation {
    condition     = var.email_sender_event_invoke_config == null || try(contains([0, 1, 2], var.email_sender_event_invoke_config.maximum_retry_attempts), false)
    error_message = "email_sender_event_invoke_config.maximum_retry_attempts must be 0, 1, or 2."
  }

  validation {
    condition     = var.email_sender_event_invoke_config == null || try(var.email_sender_event_invoke_config.on_failure_destination_arn == null || can(regex("^arn:[^:]+:(sqs|sns|lambda|events|s3):", var.email_sender_event_invoke_config.on_failure_destination_arn)), false)
    error_message = "email_sender_event_invoke_config.on_failure_destination_arn must be an SQS queue, SNS topic, S3 bucket, Lambda function, or EventBridge event bus ARN."
  }
}

variable "email_sender_rate_limit" {
  description = "Email rate limiting per destination address, per user, and per message class. Disabled by default. See the README for each field."
  type = object({
    enabled          = optional(bool, false)
    fail_mode        = optional(string, "open")
    timeout          = optional(string, "1s")
    dedupe_ttl       = optional(string, "6h")
    metric_namespace = optional(string, "CognitoCustomMessageSender")
    user_key         = optional(string, "sub")
    normalize = optional(object({
      strip_plus_tag   = optional(bool, true)
      strip_gmail_dots = optional(bool, true)
    }), {})
    exempt = optional(object({
      domains = optional(list(string), [])
      classes = optional(list(string), ["admin"])
    }), {})
    global = optional(object({
      mode             = optional(string, "count")
      shards           = optional(number, 4)
      degrade_fraction = optional(number, 0.8)
    }), {})
    classes = optional(object({
      authentication = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "15m", max = 5 }, { window = "24h", max = 20 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      signup = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "1h", max = 3 }, { window = "24h", max = 10 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      forgot_password = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "1h", max = 5 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      attribute = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "1h", max = 5 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      notification = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "1h", max = 3 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      admin = optional(object({
        destination = optional(list(object({ window = string, max = number })), [])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
    }), {})
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["open", "closed"], var.email_sender_rate_limit.fail_mode)
    error_message = "email_sender_rate_limit.fail_mode must be 'open' or 'closed'."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*(ms|s)$", var.email_sender_rate_limit.timeout))
    error_message = "email_sender_rate_limit.timeout must be a duration in ms or s (for example '500ms' or '1s'), at most 10s."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*(m|h)$", var.email_sender_rate_limit.dedupe_ttl))
    error_message = "email_sender_rate_limit.dedupe_ttl must be a duration in m or h (for example '6h'), at least 1m."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9._/#: -]{1,255}$", var.email_sender_rate_limit.metric_namespace)) && !startswith(var.email_sender_rate_limit.metric_namespace, "AWS/")
    error_message = "email_sender_rate_limit.metric_namespace must be a valid custom CloudWatch namespace."
  }

  validation {
    condition     = contains(["sub", "userName"], var.email_sender_rate_limit.user_key)
    error_message = "email_sender_rate_limit.user_key must be 'sub' or 'userName'."
  }

  validation {
    condition     = alltrue([for c in var.email_sender_rate_limit.exempt.classes : contains(["authentication", "signup", "forgot_password", "attribute", "admin", "notification"], c)])
    error_message = "email_sender_rate_limit.exempt.classes must contain only authentication, signup, forgot_password, attribute, admin, or notification."
  }

  validation {
    condition     = contains(["count", "enforce"], var.email_sender_rate_limit.global.mode) && alltrue([for c in values(var.email_sender_rate_limit.classes) : contains(["count", "enforce"], coalesce(c.global_mode, "count"))])
    error_message = "email_sender_rate_limit global.mode and classes.*.global_mode must be 'count' or 'enforce'."
  }

  validation {
    condition     = var.email_sender_rate_limit.global.shards >= 1 && var.email_sender_rate_limit.global.shards <= 100 && floor(var.email_sender_rate_limit.global.shards) == var.email_sender_rate_limit.global.shards
    error_message = "email_sender_rate_limit.global.shards must be an integer between 1 and 100."
  }

  validation {
    condition     = var.email_sender_rate_limit.global.degrade_fraction > 0 && var.email_sender_rate_limit.global.degrade_fraction <= 1
    error_message = "email_sender_rate_limit.global.degrade_fraction must be greater than 0 and at most 1."
  }

  validation {
    condition     = alltrue([for l in flatten([for c in values(var.email_sender_rate_limit.classes) : concat(c.destination, c.user, c.global)]) : can(regex("^[1-9][0-9]{0,8}[smhd]$", l.window))])
    error_message = "email_sender_rate_limit windows must be a positive integer followed by s, m, h, or d (for example '15m' or '24h')."
  }

  validation {
    condition     = alltrue([for l in flatten([for c in values(var.email_sender_rate_limit.classes) : concat(c.destination, c.user, c.global)]) : l.max >= 1 && floor(l.max) == l.max])
    error_message = "email_sender_rate_limit limits must have a positive integer max."
  }

  validation {
    condition     = alltrue(flatten([for c in values(var.email_sender_rate_limit.classes) : [for ls in [c.destination, c.user, c.global] : length(distinct([for l in ls : l.window])) == length(ls)]]))
    error_message = "email_sender_rate_limit windows must not repeat within one list."
  }
}

# ----------------------------------------------------------------- sendgrid ---

variable "sendgrid_api_host" {
  description = "SendGrid API host for sending and verification. Accounts with EU data residency use 'https://api.eu.sendgrid.com'."
  type        = string
  default     = "https://api.sendgrid.com"
  nullable    = false
}

variable "sendgrid_email_send_api_key" {
  description = "SendGrid API key with Mail Send access. Required when 'sendgrid' is in email_sender_providers."
  type        = string
  default     = ""
  nullable    = false
  sensitive   = true
}

variable "sendgrid_email_verification_api_key" {
  description = "SendGrid API key with Email Address Validation access. Required when email_verification_provider is 'sendgrid'."
  type        = string
  default     = ""
  nullable    = false
  sensitive   = true
}

# --------------------------------------------------------------- sms-sender ---

variable "sms_sender_enabled" {
  description = "Whether or not the SMS sender is enabled."
  type        = bool
  default     = false
}

variable "sms_sender_policy_content" {
  description = "The content of the Rego policy for the SMS sender. It must declare 'package cognito_custom_sender_sms_policy'. Rego v0 policies written for the earlier Node.js sender are accepted."
  type        = string
  default     = ""
  nullable    = false
}

variable "sms_sender_history_enabled" {
  description = "Record each SMS in a DynamoDB history table and pass recent attempts to the policy as input.history.recentAttempts."
  type        = bool
  default     = true
}

variable "sms_sender_throttle_period_in_minutes" {
  description = "The window, in minutes, that input.history.recentAttempts counts over. It must be a positive integer."
  type        = number
  default     = 15

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.sms_sender_throttle_period_in_minutes))
    error_message = "SMS sender throttle period must be a positive integer"
  }
}

variable "sms_sender_event_invoke_config" {
  description = "Asynchronous invocation settings for the SMS sender Lambda. The default keeps events for 5 minutes and retries once. Set to null to use the AWS defaults (2 retries, events kept for up to 6 hours)."
  type = object({
    maximum_event_age_in_seconds = optional(number, 300)
    maximum_retry_attempts       = optional(number, 1)
    on_failure_destination_arn   = optional(string)
  })
  default = {}

  validation {
    condition     = var.sms_sender_event_invoke_config == null || try(var.sms_sender_event_invoke_config.maximum_event_age_in_seconds >= 60 && var.sms_sender_event_invoke_config.maximum_event_age_in_seconds <= 21600 && floor(var.sms_sender_event_invoke_config.maximum_event_age_in_seconds) == var.sms_sender_event_invoke_config.maximum_event_age_in_seconds, false)
    error_message = "sms_sender_event_invoke_config.maximum_event_age_in_seconds must be an integer between 60 and 21600."
  }

  validation {
    condition     = var.sms_sender_event_invoke_config == null || try(contains([0, 1, 2], var.sms_sender_event_invoke_config.maximum_retry_attempts), false)
    error_message = "sms_sender_event_invoke_config.maximum_retry_attempts must be 0, 1, or 2."
  }

  validation {
    condition     = var.sms_sender_event_invoke_config == null || try(var.sms_sender_event_invoke_config.on_failure_destination_arn == null || can(regex("^arn:[^:]+:(sqs|sns|lambda|events|s3):", var.sms_sender_event_invoke_config.on_failure_destination_arn)), false)
    error_message = "sms_sender_event_invoke_config.on_failure_destination_arn must be an SQS queue, SNS topic, S3 bucket, Lambda function, or EventBridge event bus ARN."
  }
}

variable "sms_sender_rate_limit" {
  description = "SMS rate limiting per phone number, per user, and per message class. Disabled by default. See the README for each field."
  type = object({
    enabled          = optional(bool, false)
    fail_mode        = optional(string, "open")
    timeout          = optional(string, "1s")
    dedupe_ttl       = optional(string, "6h")
    metric_namespace = optional(string, "CognitoCustomMessageSender")
    user_key         = optional(string, "sub")
    exempt = optional(object({
      classes = optional(list(string), ["admin"])
    }), {})
    global = optional(object({
      mode             = optional(string, "count")
      shards           = optional(number, 4)
      degrade_fraction = optional(number, 0.8)
    }), {})
    classes = optional(object({
      authentication = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "15m", max = 5 }, { window = "24h", max = 10 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      signup = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "1h", max = 3 }, { window = "24h", max = 5 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      forgot_password = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "1h", max = 3 }, { window = "24h", max = 5 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      attribute = optional(object({
        destination = optional(list(object({ window = string, max = number })), [{ window = "1h", max = 3 }])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
      admin = optional(object({
        destination = optional(list(object({ window = string, max = number })), [])
        user        = optional(list(object({ window = string, max = number })), [])
        global      = optional(list(object({ window = string, max = number })), [])
        global_mode = optional(string)
      }), {})
    }), {})
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["open", "closed"], var.sms_sender_rate_limit.fail_mode)
    error_message = "sms_sender_rate_limit.fail_mode must be 'open' or 'closed'."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*(ms|s)$", var.sms_sender_rate_limit.timeout))
    error_message = "sms_sender_rate_limit.timeout must be a duration in ms or s (for example '500ms' or '1s'), at most 10s."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*(m|h)$", var.sms_sender_rate_limit.dedupe_ttl))
    error_message = "sms_sender_rate_limit.dedupe_ttl must be a duration in m or h (for example '6h'), at least 1m."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9._/#: -]{1,255}$", var.sms_sender_rate_limit.metric_namespace)) && !startswith(var.sms_sender_rate_limit.metric_namespace, "AWS/")
    error_message = "sms_sender_rate_limit.metric_namespace must be a valid custom CloudWatch namespace."
  }

  validation {
    condition     = contains(["sub", "userName"], var.sms_sender_rate_limit.user_key)
    error_message = "sms_sender_rate_limit.user_key must be 'sub' or 'userName'."
  }

  validation {
    condition     = alltrue([for c in var.sms_sender_rate_limit.exempt.classes : contains(["authentication", "signup", "forgot_password", "attribute", "admin"], c)])
    error_message = "sms_sender_rate_limit.exempt.classes must contain only authentication, signup, forgot_password, attribute, or admin."
  }

  validation {
    condition     = contains(["count", "enforce"], var.sms_sender_rate_limit.global.mode) && alltrue([for c in values(var.sms_sender_rate_limit.classes) : contains(["count", "enforce"], coalesce(c.global_mode, "count"))])
    error_message = "sms_sender_rate_limit global.mode and classes.*.global_mode must be 'count' or 'enforce'."
  }

  validation {
    condition     = var.sms_sender_rate_limit.global.shards >= 1 && var.sms_sender_rate_limit.global.shards <= 100 && floor(var.sms_sender_rate_limit.global.shards) == var.sms_sender_rate_limit.global.shards
    error_message = "sms_sender_rate_limit.global.shards must be an integer between 1 and 100."
  }

  validation {
    condition     = var.sms_sender_rate_limit.global.degrade_fraction > 0 && var.sms_sender_rate_limit.global.degrade_fraction <= 1
    error_message = "sms_sender_rate_limit.global.degrade_fraction must be greater than 0 and at most 1."
  }

  validation {
    condition     = alltrue([for l in flatten([for c in values(var.sms_sender_rate_limit.classes) : concat(c.destination, c.user, c.global)]) : can(regex("^[1-9][0-9]{0,8}[smhd]$", l.window))])
    error_message = "sms_sender_rate_limit windows must be a positive integer followed by s, m, h, or d (for example '15m' or '24h')."
  }

  validation {
    condition     = alltrue([for l in flatten([for c in values(var.sms_sender_rate_limit.classes) : concat(c.destination, c.user, c.global)]) : l.max >= 1 && floor(l.max) == l.max])
    error_message = "sms_sender_rate_limit limits must have a positive integer max."
  }

  validation {
    condition     = alltrue(flatten([for c in values(var.sms_sender_rate_limit.classes) : [for ls in [c.destination, c.user, c.global] : length(distinct([for l in ls : l.window])) == length(ls)]]))
    error_message = "sms_sender_rate_limit windows must not repeat within one list."
  }
}

# ------------------------------------------------------------------ context ---

variable "aws_account_id" {
  description = "The AWS account ID that the module will be deployed in."
  type        = string
  default     = ""
}

variable "aws_region_name" {
  description = "The AWS region name where the module will be deployed."
  type        = string
  default     = ""
}
