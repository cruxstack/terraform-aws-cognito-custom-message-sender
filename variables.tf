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

variable "sms_sender_throttle_period_in_minutes" {
  description = "The throttle period for the SMS sender, in minutes. It must be a positive integer."
  type        = number
  default     = 15

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.sms_sender_throttle_period_in_minutes))
    error_message = "SMS sender throttle period must be a positive integer"
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
