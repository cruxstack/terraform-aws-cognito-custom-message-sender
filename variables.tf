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

variable "sendgrid_api_key" {
  type        = string
  description = "The SendGrid API key used to interact with its API."
  default     = ""
}

variable "sendgrid_email_verification_enabled" {
  type        = bool
  description = "Toggle to use email verification."
  default     = false
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
