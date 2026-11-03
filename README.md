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
  - Email rate limiting per destination address, per user, and per message
    class, backed by DynamoDB

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
| `email_sender_rate_limit`       | Email rate limiting settings. See [Email Rate Limiting](#email-rate-limiting).                                                           |  `object`   | disabled    |    no    |
| `email_sender_event_invoke_config` | Async retry settings for the email Lambda. `null` uses the AWS defaults. See [Asynchronous Invocation](#asynchronous-invocation).     |  `object`   | 300s, 1 retry |  no    |

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
| `sms_sender_event_invoke_config`        | Async retry settings for the SMS Lambda. `null` uses the AWS defaults. See [Asynchronous Invocation](#asynchronous-invocation).   | `object` | `null`  |    no    |

## Outputs

| Name                 | Description                                                             |
|----------------------|-------------------------------------------------------------------------|
| `kms_key_arn`        | The ARN of the KMS key.                                                 |
| `email_lambda_fn_arn`| The ARN of the email sender Lambda function (empty if disabled).        |
| `email_rate_limit_table_arn` | The ARN of the email rate limit DynamoDB table (empty if disabled). |
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

## Email Rate Limiting

The email sender can cap how many emails one address, one user, or one message
class receives in a time window. It's disabled by default and requires
`email_sender_version` `v2.6.0` or later (or `latest`). Older sender versions
ignore the settings.

With passwordless sign-in (`USER_AUTH` with `EMAIL_OTP`), anyone who has a
public app client ID can make Cognito send a code to any registered address.
Cognito's built-in cap is per requester IP ("Email MFA messages sent to one
email address hourly per requester IP address: 5-20",
[quotas](https://docs.aws.amazon.com/cognito/latest/developerguide/quotas.html)),
and AWS WAF rate-based rules can't count by a field in a JSON request body. The
custom email sender sees every email with its destination address, so it
counts there.

```hcl
module "cognito_custom_message_sender" {
  source = "cruxstack/cognito-custom-message-sender/aws"

  email_sender_enabled        = true
  email_sender_policy_content = file("policy.rego")

  email_sender_rate_limit = {
    enabled = true
  }
}
```

With only `enabled = true`, these limits apply per destination address:

| Class             | Cognito triggers                                       | Default limits        |
|-------------------|--------------------------------------------------------|-----------------------|
| `authentication`  | `CustomEmailSender_Authentication`                     | 5 per 15m, 20 per 24h |
| `signup`          | `CustomEmailSender_SignUp`, `_ResendCode`              | 3 per 1h, 10 per 24h  |
| `forgot_password` | `CustomEmailSender_ForgotPassword`                     | 5 per 1h              |
| `attribute`       | `CustomEmailSender_UpdateUserAttribute`, `_VerifyUserAttribute` | 5 per 1h     |
| `notification`    | `CustomEmailSender_AccountTakeOverNotification`        | 3 per 1h              |
| `admin`           | `CustomEmailSender_AdminCreateUser`                    | exempt                |

Every field is optional, and omitted fields keep their defaults, including
fields inside a class:

| Field                      | Description                                                                         | Default                        |
|----------------------------|-------------------------------------------------------------------------------------|--------------------------------|
| `enabled`                  | Turn rate limiting on.                                                              | `false`                        |
| `fail_mode`                | `open` sends when DynamoDB fails; `closed` drops the email.                         | `"open"`                       |
| `timeout`                  | Deadline for all rate limit calls per email (`ms` or `s`, at most `10s`).           | `"1s"`                         |
| `dedupe_ttl`               | How long retry markers are kept (`m` or `h`).                                       | `"6h"`                         |
| `metric_namespace`         | CloudWatch namespace for metrics.                                                   | `"CognitoCustomMessageSender"` |
| `user_key`                 | Key for per-user limits: `sub` or `userName`.                                       | `"sub"`                        |
| `normalize`                | `strip_plus_tag` and `strip_gmail_dots` address normalization.                      | both `true`                    |
| `exempt`                   | `domains` and `classes` that are never counted.                                     | `classes = ["admin"]`          |
| `global`                   | `mode` (`count` or `enforce`), `shards` (1-100), `degrade_fraction` (0-1].          | `count`, `4`, `0.8`            |
| `classes.<class>`          | `destination`, `user`, and `global` lists of `{ window, max }`, plus `global_mode`.  | see table above                |

A window is a positive integer followed by `s`, `m`, `h`, or `d` (for example
`15m` or `24h`), and `max` is a positive integer.

```hcl
email_sender_rate_limit = {
  enabled = true
  exempt  = { domains = ["example.com"] }
  global  = { mode = "enforce" }
  classes = {
    authentication = {
      user   = [{ window = "1h", max = 10 }]
      global = [{ window = "1h", max = 5000 }]
    }
    signup = {
      global      = [{ window = "1h", max = 1000 }]
      global_mode = "count"
    }
  }
}
```

Global limits count all emails in a class and have no defaults, because they
depend on normal traffic. In `count` mode they only log and emit a metric; set
a max above the observed peak before switching to `enforce`. In `enforce` mode,
once a class passes `degrade_fraction` of its global max, unverified or
unconfirmed recipients are throttled first.

When enabled, the module creates:

- a DynamoDB table (`PAY_PER_REQUEST`, string hash key `pk`, TTL on `ttl`)
- an IAM statement allowing `dynamodb:BatchGetItem`, `dynamodb:PutItem`, and
  `dynamodb:UpdateItem` on that table only
- the `APP_EMAIL_RATE_LIMIT_ENABLED`, `APP_EMAIL_RATE_LIMIT_TABLE_NAME`, and
  `APP_EMAIL_RATE_LIMIT_CONFIG` environment variables on the email Lambda

Things to know:

- A throttled recipient gets no email, but the Cognito API call still
  succeeds, because Cognito invokes the sender asynchronously.
- Lambda retries of the same event are counted once.
- If DynamoDB fails or is slow, emails are sent (`fail_mode = "open"`).
- The sender emits CloudWatch Embedded Metric Format metrics
  `EmailRateLimitDecision` and `EmailRateLimitGlobalExceeded` with `class` and
  `decision` dimensions. No metric or table item contains an address.

See the [email sender documentation](https://github.com/cruxstack/cognito-custom-message-sender-go#email-rate-limiting)
for decisions, the policy input, and trade-offs.

## Asynchronous Invocation

Cognito invokes custom sender triggers asynchronously, so Lambda retries failed
invocations. By default it retries twice and keeps events for up to 6 hours
([error handling](https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-error-handling.html)).
Cognito codes expire within minutes, so a late email rarely helps.

> **Behavior change:** the email sender Lambda now keeps events for 5 minutes
> and retries once (`email_sender_event_invoke_config`). Previously it used the
> AWS defaults. Set `email_sender_event_invoke_config = null` to keep them.

```hcl
email_sender_event_invoke_config = {
  maximum_event_age_in_seconds = 300 # 60-21600
  maximum_retry_attempts       = 1   # 0-2
  on_failure_destination_arn   = "arn:aws:sqs:us-east-1:123456789012:example-dlq"
}
```

`on_failure_destination_arn` sends events that exhaust their retries or expire
to an SQS queue, SNS topic, S3 bucket, Lambda function, or EventBridge event
bus. The module grants the execution role permission to deliver to it. The SMS
sender keeps the AWS defaults unless `sms_sender_event_invoke_config` is set.

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
