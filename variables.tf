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
  description = "The log level for the service. It must be one of 'debug', 'info', 'warn', 'error', 'panic' or 'fatal'."
  type        = string
  default     = "info"

  validation {
    condition     = contains(["debug", "info", "warn", "error", "panic", "fatal"], var.service_log_level)
    error_message = "Service log level must be one of 'debug', 'info', 'warn', 'error', 'panic' or 'fatal'"
  }
}

# ------------------------------------------------------------- email-sender ---

variable "email_sender_debug_mode" {
  type    = bool
  default = false
}

variable "email_sender_version" {
  type    = string
  default = "latest"
}

variable "email_sender_enabled" {
  description = "Whether or not the Email sender is enabled."
  type        = bool
  default     = false
}

variable "email_sender_policy_content" {
  description = "The content of the Open Policy Agent policy for email sender."
  type        = string
  default     = ""
}

variable "email_sender_force_rebuild_id" {
  description = "Change this value to force a rebuild of the email sender artifact."
  type        = string
  default     = ""
}

variable "email_sender_providers" {
  type        = list(string)
  description = "List of enabled email providers."
  default     = ["ses"]

  validation {
    condition     = length(var.email_sender_providers) == 1
    error_message = "Must define exactly one email provider. Support for more than one coming in the future."
  }

  validation {
    condition     = alltrue([for x in var.email_sender_providers : contains(["ses", "sendgrid"], x)])
    error_message = "Invalid email provider"
  }

  validation {
    condition     = !contains(var.email_sender_providers, "sendgrid") || (contains(var.email_sender_providers, "sendgrid") && try(length(var.sendgrid_email_send_api_key) > 0, false))
    error_message = "SendGrid is set as email provider but its API is not set."
  }
}

variable "email_verification_enabled" {
  type        = bool
  description = "Toggle to enable email verification before sending."
  default     = true
}

variable "email_verification_provider" {
  type        = string
  description = "Email verification provider: 'offline' (RFC 5322 format validation) or 'sendgrid' (advanced checks)."
  default     = "offline"

  validation {
    condition     = contains(["offline", "sendgrid"], var.email_verification_provider)
    error_message = "Email verification provider must be 'offline' or 'sendgrid'."
  }
}

variable "email_verification_whitelist" {
  type        = list(string)
  description = "Comma-separated domains that skip email verification."
  default     = []
}

variable "email_failover_enabled" {
  type        = bool
  description = "Enable automatic provider failover when primary provider is unavailable."
  default     = false
}

variable "email_failover_providers" {
  type        = list(string)
  description = "List of failover providers to try when primary provider fails (e.g., ['sendgrid'])."
  default     = []

  validation {
    condition     = alltrue([for x in var.email_failover_providers : contains(["ses", "sendgrid"], x)])
    error_message = "Invalid failover provider. Must be 'ses' or 'sendgrid'."
  }
}

variable "email_failover_cache_ttl" {
  type        = string
  description = "Health check cache duration for failover (Go duration format, e.g., '30s')."
  default     = "30s"
}

variable "sendgrid_api_key" {
  type        = string
  description = "Deprecated: Use sendgrid_email_send_api_key"
  default     = ""
}

variable "sendgrid_api_host" {
  type        = string
  description = "SendGrid API base URL."
  default     = "https://api.sendgrid.com"
}

variable "sendgrid_email_send_api_key" {
  type        = string
  description = "The SendGrid API key used to interact with its Mail Send API."
  default     = ""
}

variable "sendgrid_email_verification_api_key" {
  type        = string
  description = "The SendGrid API key used to interact with its Email Verification API."
  default     = ""

  validation {
    condition     = !(var.email_verification_provider == "sendgrid") || (var.email_verification_provider == "sendgrid" && try(length("${var.sendgrid_email_verification_api_key}${var.sendgrid_api_key}") > 0, false))
    error_message = "SendGrid Email Verification provider is selected but API Key is not set."
  }
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
  description = "Email rate limiting per destination address, per user, and per message class. Disabled by default. Requires email sender v2.6.0 or later. See the README for each field."
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

# Deprecated - kept for backwards compatibility
variable "sendgrid_email_verification_allowlist" {
  type        = list(string)
  description = "Deprecated: Use email_verification_whitelist instead."
  default     = []
}

# Deprecated - kept for backwards compatibility
variable "sendgrid_email_verification_enabled" {
  type        = bool
  description = "Deprecated: Use email_verification_enabled instead."
  default     = null
}

# --------------------------------------------------------------- sms-sender ---

variable "sms_sender_enabled" {
  description = "Whether or not the SMS sender is enabled."
  type        = bool
  default     = false
}

variable "sms_sender_policy_content" {
  description = "The content of the Open Policy Agent policy for SMS sender."
  type        = string
  default     = ""
}

variable "sms_sender_force_rebuild_id" {
  description = "Change this value to force a rebuild of the SMS sender artifact."
  type        = string
  default     = ""
}

variable "sms_sender_throttle_period_in_minutes" {
  description = "The throttle period for the SMS sender, in minutes. It must be a positive integer."
  type        = number
  default     = 15

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.sms_sender_throttle_period_in_minutes))
    error_message = "SMS sender throttle period must be a positive integer"
  }
}

variable "sms_sender_event_invoke_config" {
  description = "Asynchronous invocation settings for the SMS sender Lambda. Defaults to null, which uses the AWS defaults (2 retries, events kept for up to 6 hours)."
  type = object({
    maximum_event_age_in_seconds = optional(number, 300)
    maximum_retry_attempts       = optional(number, 1)
    on_failure_destination_arn   = optional(string)
  })
  default = null

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
