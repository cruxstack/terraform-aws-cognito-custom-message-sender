# Terraform Module: AWS Cognito Custom SMS Sender

This Terraform module deploys a AWS Lambda function to serve as a custom SMS
sender for AWS Cognito. The module uses Open Policy Agent (OPA) policies to
determine whether to send an SMS message or not, and can be customized to fit
various use cases, such as throttling messages to specific users or phone
numbers, or preventing messages from being sent to phone numbers from specific
countries.

For more details about the custom message sender Lambda function, see [documentation](./assets/custom-message-sender/)
located within its directory.

## Features

- Customizable Open Policy Agent (OPA) policy to filter and throttle SMS sending
- Ability to dynamically use SMS sender ID and short code

## Usage

```hcl
module "cognito_custom_sms_sender" {
  source = "sgtoj/cognito-custom-message-sender/aws"

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

## Development Environment

This repository includes a configuration for a development container using the
[VS Code Remote - Containers extension](https://code.visualstudio.com/docs/remote/containers).
This setup allows you to develop within a Docker container that already has all
the necessary tools and dependencies installed.

The development container is based on Ubuntu 20.04 (Focal) and includes the
following tools:

- AWS CLI
- Node.js
- TypeScript
- Docker CLI
- Terraform
- Open Policy Agent

### Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop) installed on your
  local machine.
- [Visual Studio Code](https://code.visualstudio.com/) installed on your
  local machine.
- [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  for Visual Studio Code.

### Usage

1. Clone this repository:

    ```bash
    git clone https://github.com/sgtoj/terraform-docker-artifact-packager.git
    ```

2. Open the repository in Visual Studio Code:

    ```bash
    code terraform-docker-artifact-packager
    ```

3. When prompted to "Reopen in Container", click "Reopen in Container". This
   will start building the Docker image for the development container. If you're
   not prompted, you can open the Command Palette (F1 or Ctrl+Shift+P), and run
   the "Remote-Containers: Reopen Folder in Container" command.

4. After the development container is built and started, you can use the
   Terminal in Visual Studio Code to interact with the container. All commands
  you run in the Terminal will be executed inside the container.

### Troubleshooting

If you encounter any issues while using the development container, you can try
rebuilding the container. To do this, open the Command Palette and run the
"Remote-Containers: Rebuild Container" command.
