# Terraform Module: AWS Cognito Custom Message Sender

:warning: **This module is not ready for use. Wait until v1.x.x release.**

This Terraform module deploys a AWS Lambda function to serve as a custom SMS
sender for AWS Cognito. The module uses Open Policy Agent (OPA) policies to
determine whether to send an SMS message or not, and can be customized to fit
various use cases, such as throttling messages to specific users or phone
numbers, or preventing messages from being sent to phone numbers from specific
countries.

For more details about the custom message sender Lambda function, see [documentation](./assets/custom-message-sender/)
located within its directory.

## Features

- Deploy a [custom SMS sender Lambda function for AWS Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-sms-sender.html)
- Customizable Open Policy Agent (OPA) policy to filter and throttle SMS sending
- Ability to dynamically use SMS sender ID and short code

## Usage

```hcl
module "cognito_custom_sms_sender" {
  source  = "sgtoj/cognito-custom-message-sender/aws"
  version = "1.x.x"

  sms_sender_enabled                    = true
  sms_sender_policy_content             = "<OPA policy content>"
  sms_sender_throttle_period_in_minutes = 15
}
```

## Requirements

- Terraform 0.13.0 or later
- AWS provider 5.0.0 or later
- Docker installed and running on the machine where Terraform is executed

## Inputs

| Name                                    | Description                                                                                                                                                                  |   Type   |  Default  | Required |
|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------:|:---------:|:--------:|
| `kms_key_alias_prefix`                  | The prefix for the KMS key alias. It must start with 'alias' and only include alphanumeric characters, dashes, underscores, colons or slashes, but doesn't end with a slash. | `string` | `"alias"` |    no    |
| `service_log_level`                     | The log level for the service. It must be one of 'debug', 'info', 'warn', 'error', 'panic' or 'fatal'.                                                                       | `string` | `"info"`  |    no    |
| `sms_sender_enabled`                    | Whether or not the SMS sender is enabled.                                                                                                                                    |  `bool`  |  `false`  |    no    |
| `sms_sender_policy_content`             | The content of the Open Policy Agent policy for SMS sender. It must include the string 'package cognito_custom_sender_sms_policy'.                                           | `string` |    n/a    |   yes    |
| `sms_sender_throttle_period_in_minutes` | The throttle period for the SMS sender, in minutes. It must be a positive integer.                                                                                           | `number` |   `15`    |    no    |
| `aws_account_id`                        | The AWS account ID that the module will be deployed in.                                                                                                                      | `string` |   `""`    |    no    |
| `aws_region_name`                       | The AWS region name where the module will be deployed.                                                                                                                       | `string` |   `""`    |    no    |

### Note

This module uses the `cloudposse/label/null` module for naming and tagging
resources. As such, it also includes a `context.tf` file with additional
optional variables you can set. Refer to the [`cloudposse/label` documentation](https://registry.terraform.io/modules/cloudposse/label/null/latest)
for more details on these variables.

## Outputs

| Name            | Description                                                        |
|-----------------|--------------------------------------------------------------------|
| `kms_key_arn`   | The ARN of the KMS key.                                            |
| `lambda_fn_arn` | The ARN of the Lambda function, or null if the module is disabled. |

## Contributing

We welcome contributions to the project! For information on setting up a
development environment and how to make contribution, see [CONTRIBUTING](./CONTRIBUTING.md)
documentation.
