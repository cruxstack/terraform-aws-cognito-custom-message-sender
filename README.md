# Terraform Module: AWS Cognito Custom Message Sender

This Terraform module deploys a AWS Lambda function to serve as a custom SMS
sender for AWS Cognito. The module uses Open Policy Agent (OPA) policies to
determine whether to send an SMS message or not, and can be customized to fit
various use cases, such as throttling messages to specific users or phone
numbers, or preventing messages from being sent to phone numbers from specific
countries.

For more details about the custom message sender Lambda function, see [documentation](./assets/custom-message-sender/)
located within its directory.

## Features

- [Custom SMS sender Lambda function for AWS Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-sms-sender.html)
  - Customizable (OPA) policy to filter and throttle SMS sending
  - Ability to dynamically use SMS sender ID and short code
- [Custom Email sender Lambda function for AWS Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-email-sender.html)
  - Dyanmic decided which SES template to use based on context of request.

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

| Name                                    | Description                                                                                                                            |   Type   |  Default   | Required |
|-----------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|:--------:|:----------:|:--------:|
| `kms_key_alias_prefix`                  | The prefix for the KMS key alias.                                                                                                      | `string` | `"alias"`  |    no    |
| `service_log_level`                     | The log level for the service. It must be one of 'debug', 'info', 'warn', 'error', 'panic' or 'fatal'.                                 | `string` | `"info"`   |    no    |
| `email_sender_version`                  | Version or git ref of the source code                                                                                                  | `string` | `"latest"` |    no    |
| `email_sender_enabled`                  | Whether or not the eamil sender is enabled.                                                                                            |  `bool`  |  `false`   |    no    |
| `email_sender_policy_content`           | The content of the Open Policy Agent policy for email sender. It must include the string 'package cognito_custom_sender_email_policy'. | `string` |    n/a     |   yes    |
| `sendgrid_api_key`                      | The SendGrid API key used to interact with its API.                                                                                    | `string` |   `""`     |   no     |
| `sendgrid_email_verification_enabled`   | Toggle to use email verification.                                                                                                      |  `bool`  |  `false`   |   no     |
| `sms_sender_enabled`                    | Whether or not the SMS sender is enabled.                                                                                              |  `bool`  |  `false`   |    no    |
| `sms_sender_policy_content`             | The content of the Open Policy Agent policy for SMS sender. It must include the string 'package cognito_custom_sender_sms_policy'.     | `string` |    n/a     |   yes    |
| `sms_sender_throttle_period_in_minutes` | The throttle period for the SMS sender, in minutes. It must be a positive integer.                                                     | `number` |   `15`     |    no    |
| `aws_account_id`                        | The AWS account ID that the module will be deployed in.                                                                                | `string` |   `""`     |    no    |
| `aws_region_name`                       | The AWS region name where the module will be deployed.                                                                                 | `string` |   `""`     |    no    |

## Outputs

| Name            | Description                                                        |
|-----------------|--------------------------------------------------------------------|
| `kms_key_arn`   | The ARN of the KMS key.                                            |
| `lambda_fn_arn` | The ARN of the Lambda function, or null if the module is disabled. |

## Contributing

We welcome contributions to the project! For information on setting up a
development environment and how to make contribution, see [CONTRIBUTING](./CONTRIBUTING.md)
documentation.
