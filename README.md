# Terraform Module: AWS Cognito Custom Message Sender

This module deploys AWS Lambda functions for the Amazon Cognito
[custom email](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-email-sender.html)
and [custom SMS](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-sms-sender.html)
sender triggers. A [Rego](https://www.openpolicyagent.org/docs/policy-language)
policy you write decides, for every message Cognito sends, whether to send it
and with which template, sender, and provider.

Both Lambdas run [cognito-custom-message-sender-go](https://github.com/cruxstack/cognito-custom-message-sender-go),
built from source at a pinned version. Its documentation covers the
[policy input and result](https://github.com/cruxstack/cognito-custom-message-sender-go/blob/main/docs/policies.md)
in detail.

## Features

- **Email** through Amazon SES or SendGrid, with ordered failover when a
  provider fails or SES sending is paused, and optional address verification
  (offline syntax check or SendGrid Email Address Validation).
- **SMS** through Amazon SNS, with an optional per-number history for
  policies written for the earlier Node.js sender.
- **Rate limiting** for email and SMS per destination, per user, and per
  message class, in one DynamoDB table, to stop code floods and SMS pumping.
- **Policy-driven messages:** templates, branding, and sender addresses by app
  client, trigger, user attribute, or client metadata.
- **Asynchronous retries** tuned for short-lived codes, with an optional
  failure destination.

## Usage

```hcl
module "cognito_message_sender" {
  source  = "cruxstack/cognito-custom-message-sender/aws"
  version = "x.x.x"

  email_sender_enabled        = true
  email_sender_policy_content = file("${path.module}/email-policy.rego")

  sms_sender_enabled        = true
  sms_sender_policy_content = file("${path.module}/sms-policy.rego")

  email_sender_rate_limit = { enabled = true }
  sms_sender_rate_limit   = { enabled = true }
}

module "user_pool" {
  source  = "cruxstack/cognito-userpool/aws"
  version = "1.10.0"

  lambda_config = {
    kms_key_id          = module.cognito_message_sender.kms_key_arn
    custom_email_sender = { lambda_arn = module.cognito_message_sender.email_lambda_fn_arn }
    custom_sms_sender   = { lambda_arn = module.cognito_message_sender.sms_lambda_fn_arn }
  }
}
```

A minimal email policy:

```rego
package cognito_custom_sender_email_policy

import rego.v1

result := {
	"action": "allow",
	"allow": {
		"srcAddress": "ACME <no-reply@example.com>",
		"providers": {"ses": {"templateId": "acme-code", "templateData": {"appName": "ACME"}}},
	},
}
```

The decrypted code is added to the template data as `code`. See the
[example policies](https://github.com/cruxstack/cognito-custom-message-sender-go/tree/main/examples/policies)
and [`examples/complete`](examples/complete).

Building the sender needs Docker (through the
[buildkit provider](https://registry.terraform.io/providers/cruxstack/buildkit))
and network access to GitHub on the machine that runs Terraform.

## Inputs

In addition to the variables below, this module accepts the
[`cloudposse/label/null`](https://registry.terraform.io/modules/cloudposse/label/null/latest)
context variables (`name`, `tags`, and so on).

### General

| Name                      | Description                                                                                       | Type     | Default    |
| ------------------------- | ------------------------------------------------------------------------------------------------- | -------- | ---------- |
| `sender_version`          | Git tag of the Go sender to build. `"latest"` builds its default branch, which can include breaking changes. | `string` | `"v3.0.0"` |
| `lambda_architecture`     | `arm64` (Graviton, lower cost) or `x86_64`.                                                       | `string` | `"arm64"`  |
| `service_log_level`       | `debug`, `info`, `warn`, or `error`. `debug` logs every event, including user attributes.         | `string` | `"info"`   |
| `sender_force_rebuild_id` | Change to force a rebuild of the sender artifact.                                                 | `string` | `""`       |
| `kms_key_alias_prefix`    | Prefix of the KMS key alias.                                                                      | `string` | `"alias"`  |
| `aws_account_id`          | AWS account ID; looked up when empty.                                                             | `string` | `""`       |
| `aws_region_name`         | AWS region; looked up when empty.                                                                 | `string` | `""`       |

### Email sender

| Name                               | Description                                                                                          | Type           | Default         |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------- | -------------- | --------------- |
| `email_sender_enabled`             | Create the email sender.                                                                             | `bool`         | `false`         |
| `email_sender_policy_content`      | The email policy. Must declare `package cognito_custom_sender_email_policy`.                         | `string`       | required        |
| `email_sender_providers`           | Providers in order: `ses`, `sendgrid`. More than one enables [failover](#provider-failover).         | `list(string)` | `["ses"]`       |
| `email_health_check_ttl`           | How long an SES account health check is cached (Go duration).                                        | `string`       | `"30s"`         |
| `email_verification_enabled`       | Verify the address before the policy runs.                                                           | `bool`         | `true`          |
| `email_verification_provider`      | `offline` or `sendgrid`.                                                                             | `string`       | `"offline"`     |
| `email_verification_allowlist`     | Domains treated as valid without verification.                                                       | `list(string)` | `[]`            |
| `email_sender_rate_limit`          | See [rate limiting](#rate-limiting).                                                                 | `object`       | disabled        |
| `email_sender_event_invoke_config` | See [asynchronous invocation](#asynchronous-invocation). `null` uses the AWS defaults.               | `object`       | 300s, 1 retry   |

### SendGrid

| Name                                  | Description                                                                         | Type     | Default                      |
| ------------------------------------- | ----------------------------------------------------------------------------------- | -------- | ---------------------------- |
| `sendgrid_api_host`                   | API host for sending and verification. EU accounts use `https://api.eu.sendgrid.com`. | `string` | `"https://api.sendgrid.com"` |
| `sendgrid_email_send_api_key`         | Mail Send API key. Required when `sendgrid` is in `email_sender_providers`.         | `string` | `""`                         |
| `sendgrid_email_verification_api_key` | Email Address Validation API key. Required when the verification provider is `sendgrid`. | `string` | `""`                  |

The keys are stored as Lambda environment variables, which anyone who can
read the function's configuration can see.

### SMS sender

| Name                                    | Description                                                                                       | Type     | Default       |
| --------------------------------------- | ------------------------------------------------------------------------------------------------- | -------- | ------------- |
| `sms_sender_enabled`                    | Create the SMS sender.                                                                            | `bool`   | `false`       |
| `sms_sender_policy_content`             | The SMS policy. Must declare `package cognito_custom_sender_sms_policy`. Rego v0 is accepted.     | `string` | required      |
| `sms_sender_rate_limit`                 | See [rate limiting](#rate-limiting).                                                              | `object` | disabled      |
| `sms_sender_history_enabled`            | Record SMS in a history table and pass `input.history.recentAttempts` to the policy.              | `bool`   | `true`        |
| `sms_sender_throttle_period_in_minutes` | The window `input.history.recentAttempts` counts over.                                            | `number` | `15`          |
| `sms_sender_event_invoke_config`        | See [asynchronous invocation](#asynchronous-invocation). `null` uses the AWS defaults.            | `object` | 300s, 1 retry |

## Outputs

| Name                    | Description                                                                      |
| ----------------------- | -------------------------------------------------------------------------------- |
| `kms_key_arn`           | KMS key Cognito encrypts codes with; the user pool's `kms_key_id`.               |
| `email_lambda_fn_arn`   | The email sender Lambda (empty when disabled).                                   |
| `sms_lambda_fn_arn`     | The SMS sender Lambda (empty when disabled).                                     |
| `rate_limit_table_arn`  | The rate limit table shared by email and SMS (empty when both are disabled).     |
| `sms_history_table_arn` | The SMS history table (empty when disabled).                                     |

## Provider failover

AWS can pause SES sending for an account at any time. With more than one
provider in `email_sender_providers`, each email is sent with the first
provider that succeeds. SES is moved to the end of the list while its account
reports sending paused, and if every provider fails, the Lambda returns an
error so the event is retried (and, with a failure destination, kept).

```hcl
email_sender_providers      = ["ses", "sendgrid"]
sendgrid_email_send_api_key = var.sendgrid_email_send_api_key
```

The policy must return a template for each provider that should be able to
send:

```rego
result := {
	"action": "allow",
	"allow": {
		"srcAddress": "ACME <no-reply@example.com>",
		"providers": {
			"ses": {"templateId": "acme-code", "templateData": {}},
			"sendgrid": {"templateId": "d-0123456789abcdef", "templateData": {}},
		},
	},
}
```

## Rate limiting

Rate limiting caps how many emails or SMS one destination, one user, or one
message class can receive in a time window. Anyone with a public app client
ID can make Cognito send codes, for example with passwordless sign-in, and
Cognito's own caps are per requester IP. For SMS, every message costs money
and SMS pumping targets exactly these flows.

```hcl
email_sender_rate_limit = { enabled = true }
sms_sender_rate_limit   = { enabled = true }
```

With only `enabled = true`, these limits apply per destination:

| Class             | Cognito triggers                                  | Email                 | SMS                   |
| ----------------- | ------------------------------------------------- | --------------------- | --------------------- |
| `authentication`  | `Authentication`                                  | 5 per 15m, 20 per 24h | 5 per 15m, 10 per 24h |
| `signup`          | `SignUp`, `ResendCode`                            | 3 per 1h, 10 per 24h  | 3 per 1h, 5 per 24h   |
| `forgot_password` | `ForgotPassword`                                  | 5 per 1h              | 3 per 1h, 5 per 24h   |
| `attribute`       | `UpdateUserAttribute`, `VerifyUserAttribute`      | 5 per 1h              | 3 per 1h              |
| `notification`    | `AccountTakeOverNotification` (email only)        | 3 per 1h              | n/a                   |
| `admin`           | `AdminCreateUser`                                 | exempt                | exempt                |

Every field is optional, and omitted fields keep their defaults, including
fields inside a class:

| Field              | Description                                                                         | Default                        |
| ------------------ | ----------------------------------------------------------------------------------- | ------------------------------ |
| `enabled`          | Turn rate limiting on.                                                              | `false`                        |
| `fail_mode`        | `open` sends when DynamoDB fails; `closed` drops the message.                       | `"open"`                       |
| `timeout`          | Deadline for all rate limit calls per message (`ms` or `s`, at most `10s`).         | `"1s"`                         |
| `dedupe_ttl`       | How long retry markers are kept (`m` or `h`).                                       | `"6h"`                         |
| `metric_namespace` | CloudWatch namespace for metrics.                                                   | `"CognitoCustomMessageSender"` |
| `user_key`         | Key for per-user limits: `sub` or `userName`.                                       | `"sub"`                        |
| `normalize`        | Email only: `strip_plus_tag` and `strip_gmail_dots` address normalization.          | both `true`                    |
| `exempt`           | `classes` that are never counted; for email also `domains`.                         | `classes = ["admin"]`          |
| `global`           | `mode` (`count` or `enforce`), `shards` (1-100), `degrade_fraction` (0-1].          | `count`, `4`, `0.8`            |
| `classes.<class>`  | `destination`, `user`, and `global` lists of `{ window, max }`, plus `global_mode`. | see table above                |

A window is a positive integer followed by `s`, `m`, `h`, or `d` (for example
`15m` or `24h`), and `max` is a positive integer.

```hcl
sms_sender_rate_limit = {
  enabled = true
  global  = { mode = "enforce" }
  classes = {
    authentication = {
      destination = [{ window = "15m", max = 3 }, { window = "24h", max = 10 }]
      global      = [{ window = "1h", max = 2000 }]
    }
  }
}
```

Global limits count every message in a class and have no defaults, because
they depend on normal traffic. They are the main defense against SMS pumping,
which spreads across many numbers. In `count` mode they only log and emit a
metric; set a max above the observed peak before switching to `enforce`.

When either channel is enabled, the module creates one DynamoDB table
(`PAY_PER_REQUEST`, string hash key `pk`, TTL on `ttl`) and grants the
Lambdas `dynamodb:BatchGetItem`, `dynamodb:PutItem`, and
`dynamodb:UpdateItem` on it. Things to know:

- A throttled recipient gets no message, but the Cognito API call still
  succeeds, because Cognito invokes the senders asynchronously.
- Lambda retries of the same event are counted once.
- The senders emit CloudWatch Embedded Metric Format metrics
  (`EmailRateLimitDecision`, `SMSRateLimitDecision`, and the matching
  `...GlobalExceeded`) with `class` and `decision` dimensions. No metric or
  table item contains an address or phone number.

See the sender's
[rate limiting documentation](https://github.com/cruxstack/cognito-custom-message-sender-go/blob/main/docs/rate-limiting.md)
for decisions, the policy input, and trade-offs.

## Asynchronous invocation

Cognito invokes custom sender triggers asynchronously, so Lambda retries
failed invocations. By default AWS retries twice and keeps events for up to 6
hours, but Cognito codes expire within minutes, so both senders default to
keeping events for 5 minutes and retrying once.

```hcl
email_sender_event_invoke_config = {
  maximum_event_age_in_seconds = 300 # 60-21600
  maximum_retry_attempts       = 1   # 0-2
  on_failure_destination_arn   = "arn:aws:sqs:us-east-1:123456789012:example-dlq"
}
```

`on_failure_destination_arn` sends events that exhaust their retries or expire
to an SQS queue, SNS topic, S3 bucket, Lambda function, or EventBridge event
bus. The module grants the execution role permission to deliver to it. Set
the variable to `null` to use the AWS defaults.

## Upgrading to v4

v4 runs v3 of the Go sender for both Lambdas. The SMS Lambda moves from the
Node.js sender to the Go sender, in place: the function, its name, its log
group, and its history table are kept, so the user pool needs no changes.

Renamed and removed variables:

| v3                                                         | v4                                                              |
| ---------------------------------------------------------- | --------------------------------------------------------------- |
| `email_sender_version`                                     | `sender_version` (now a pinned tag, not `"latest"`)             |
| `email_sender_force_rebuild_id`, `sms_sender_force_rebuild_id` | `sender_force_rebuild_id`                                   |
| `email_failover_enabled`, `email_failover_providers`       | `email_sender_providers = ["ses", "sendgrid"]`                  |
| `email_failover_cache_ttl`                                 | `email_health_check_ttl`                                        |
| `email_verification_whitelist`                             | `email_verification_allowlist`                                  |
| `email_sender_debug_mode`                                  | removed; use `service_log_level = "debug"`                      |
| `sendgrid_api_key`                                         | `sendgrid_email_verification_api_key`                           |
| `sendgrid_email_verification_enabled`                      | `email_verification_enabled`                                    |
| `sendgrid_email_verification_allowlist`                    | `email_verification_allowlist`                                  |

Other changes:

- **Email policies:** results that use the v1 top-level `templateID` must move
  it under `providers.ses`, and actions other than `allow`, `deny`, or `block`
  are errors. See the sender's
  [upgrade guide](https://github.com/cruxstack/cognito-custom-message-sender-go/blob/main/docs/upgrading-to-v3.md).
  Run your policy through its `devtool eval` command before you apply.
- **SMS policies** written for the Node.js sender keep working, including
  Rego v0 syntax. The module no longer compiles them to WebAssembly.
- **Architecture:** both Lambdas default to `arm64`. Set
  `lambda_architecture = "x86_64"` to keep x86.
- **SMS retries:** the SMS Lambda now defaults to keeping events for 5 minutes
  and retrying once, like the email Lambda.
- **Rate limiting:** the table is shared by both channels and named
  `<name>-rate-limit`; an existing email rate limit table is replaced, so its
  counters start from zero. The output is now `rate_limit_table_arn`.
- **Logs:** `service_log_level` accepts `debug`, `info`, `warn`, or `error`.
- **Failed deliveries** now return an error from the email Lambda, so they
  are retried and reach the failure destination.

## Contributing

We welcome contributions to the project! For information on setting up a
development environment and how to make contribution, see [CONTRIBUTING](./CONTRIBUTING.md)
documentation.
