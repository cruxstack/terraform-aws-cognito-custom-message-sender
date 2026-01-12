# Terraform Module: AWS Cognito Custom Message Sender

This Terraform module deploys AWS Lambda functions to serve as custom SMS and
email senders for AWS Cognito. The module uses Open Policy Agent (OPA) policies
to determine whether to send messages, and can be customized to fit various use
cases, such as throttling messages, routing emails by client ID, or preventing
messages from being sent to specific destinations.

For more details about the custom message sender Lambda function, see [documentation](./assets/custom-message-sender/)
located within its directory.

## Features

- [Custom SMS sender Lambda function for AWS Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-sms-sender.html)
  - Customizable (OPA) policy to filter and throttle SMS sending
  - Ability to dynamically use SMS sender ID and short code
- [Custom Email sender Lambda function for AWS Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-email-sender.html)
  - Dynamic template selection based on context (client ID, trigger type, etc.)
  - Multiple email providers: AWS SES or SendGrid
  - Automatic provider failover (SES to SendGrid) when primary provider is unavailable
  - Email verification support (offline RFC 5322 validation or SendGrid API)

## Usage

```hcl
module "cognito_custom_sms_sender" {
  source  = "cruxstack/cognito-custom-message-sender/aws"
  version = "x.x.x"

  email_sender_enabled                    = true
  email_sender_policy_content             = "<OPA policy content>"

  sms_sender_enabled                    = true
  sms_sender_policy_content             = "<OPA policy content>"
  sms_sender_throttle_period_in_minutes = 15
}
```

## Inputs

In addition to the variables documented below, this module includes several
other optional variables (e.g., `name`, `tags`, etc.) provided by the
`cloudposse/label/null` module. Please refer to its [documentation](https://registry.terraform.io/modules/cloudposse/label/null/latest)
for more details on these variables.

### General

| Name                   | Description                                                                            |   Type   | Default   | Required |
|------------------------|----------------------------------------------------------------------------------------|:--------:|:---------:|:--------:|
| `kms_key_alias_prefix` | The prefix for the KMS key alias.                                                      | `string` | `"alias"` |    no    |
| `service_log_level`    | The log level for the service. Must be 'debug', 'info', 'warn', 'error', or 'fatal'.   | `string` | `"info"`  |    no    |
| `aws_account_id`       | The AWS account ID that the module will be deployed in.                                | `string` | `""`      |    no    |
| `aws_region_name`      | The AWS region name where the module will be deployed.                                 | `string` | `""`      |    no    |

### Email Sender

| Name                            | Description                                                                                                                              |    Type     |   Default   | Required |
|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|:-----------:|:-----------:|:--------:|
| `email_sender_enabled`          | Whether or not the email sender is enabled.                                                                                              |   `bool`    |   `false`   |    no    |
| `email_sender_version`          | Version or git ref of the source code.                                                                                                   |  `string`   |  `"latest"` |    no    |
| `email_sender_policy_content`   | The content of the Open Policy Agent policy for email sender. Must include 'package cognito_custom_sender_email_policy'.                 |  `string`   |     n/a     |   yes    |
| `email_sender_providers`        | List of enabled email providers.                                                                                                         | `list(str)` |  `["ses"]`  |    no    |
| `email_verification_enabled`    | Toggle to enable email verification before sending.                                                                                      |   `bool`    |   `true`    |    no    |
| `email_verification_provider`   | Email verification provider: 'offline' (RFC 5322 format) or 'sendgrid' (advanced checks).                                                |  `string`   | `"offline"` |    no    |
| `email_verification_whitelist`  | List of email domains that skip email verification.                                                                                      | `list(str)` |    `[]`     |    no    |
| `email_failover_enabled`        | Enable automatic provider failover when primary provider is unavailable.                                                                 |   `bool`    |   `false`   |    no    |
| `email_failover_providers`      | List of failover providers to try when primary fails (e.g., `["sendgrid"]`).                                                             | `list(str)` |    `[]`     |    no    |
| `email_failover_cache_ttl`      | Health check cache duration for failover (Go duration format, e.g., '30s').                                                              |  `string`   |   `"30s"`   |    no    |

### SendGrid

| Name                                | Description                                                  |   Type   |          Default            | Required |
|-------------------------------------|--------------------------------------------------------------|:--------:|:---------------------------:|:--------:|
| `sendgrid_api_host`                 | SendGrid API base URL.                                       | `string` | `"https://api.sendgrid.com"`|    no    |
| `sendgrid_email_send_api_key`       | The SendGrid API key for sending emails.                     | `string` |            `""`             |    no    |
| `sendgrid_email_verification_api_key` | The SendGrid API key for email verification.               | `string` |            `""`             |    no    |

### SMS Sender

| Name                                    | Description                                                                                                                        |   Type   | Default | Required |
|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|:--------:|:-------:|:--------:|
| `sms_sender_enabled`                    | Whether or not the SMS sender is enabled.                                                                                          |  `bool`  | `false` |    no    |
| `sms_sender_policy_content`             | The content of the Open Policy Agent policy for SMS sender. Must include 'package cognito_custom_sender_sms_policy'.               | `string` |   n/a   |   yes    |
| `sms_sender_throttle_period_in_minutes` | The throttle period for the SMS sender, in minutes. Must be a positive integer.                                                    | `number` |  `15`   |    no    |

## Outputs

| Name                 | Description                                                             |
|----------------------|-------------------------------------------------------------------------|
| `kms_key_arn`        | The ARN of the KMS key.                                                 |
| `email_lambda_fn_arn`| The ARN of the email sender Lambda function (empty if disabled).        |
| `sms_lambda_fn_arn`  | The ARN of the SMS sender Lambda function (empty if disabled).          |

## Provider Failover

AWS can suspend SES sending at any time for compliance reasons. Enable automatic
failover to ensure emails continue to be delivered via an alternative provider.

```hcl
module "cognito_custom_message_sender" {
  source  = "cruxstack/cognito-custom-message-sender/aws"

  email_sender_enabled        = true
  email_sender_providers      = ["ses"]
  email_sender_policy_content = file("policy.rego")

  # Enable failover with SendGrid as backup
  email_failover_enabled  = true
  email_failover_providers = ["sendgrid"]

  # SendGrid credentials (required when in failover chain)
  sendgrid_email_send_api_key = "SG.xxxx"
}
```

When failover is enabled, your OPA policy **must** return template configurations
for all providers in the failover chain:

```rego
result := {
  "action": "allow",
  "allow": {
    "srcAddress": "noreply@example.com",
    "dstAddress": input.userAttributes.email,
    "providers": {
      "ses": {
        "templateId": "ses-verification-template",
        "templateData": {"appName": "MyApp"}
      },
      "sendgrid": {
        "templateId": "d-abc123def456",
        "templateData": {"appName": "MyApp"}
      }
    }
  }
}
```

## Migration to v1.x (Breaking Changes)

The upstream Go application has upgraded to v2.x which requires:

### 1. Rego v1 Syntax

OPA policies must use v1 syntax with `import rego.v1` and explicit `if` keyword:

```rego
# Before (v0.x)
package cognito_custom_sender_email_policy

result := allow_result {
  not deny_result
}

# After (v1.x)
package cognito_custom_sender_email_policy
import rego.v1

result := allow_result if {
  not deny_result
}
```

### 2. Environment Variable Changes

| Deprecated Variable                         | New Variable                       |
|---------------------------------------------|------------------------------------|
| `sendgrid_email_verification_enabled`       | `email_verification_enabled`       |
| `sendgrid_email_verification_allowlist`     | `email_verification_whitelist`     |

The deprecated variables still work for backwards compatibility but will be
removed in a future version.

## Contributing

We welcome contributions to the project! For information on setting up a
development environment and how to make contribution, see [CONTRIBUTING](./CONTRIBUTING.md)
documentation.
