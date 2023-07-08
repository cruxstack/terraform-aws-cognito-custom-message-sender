# Terraform Module: AWS Cognito Custom Message Sender (Under Development)

This Terraform module deploys Lambda functions for Cognito's custom message
sender. It enables sending custom messages for user authentication,
verification, and other use cases via SMS and email. The module creates the
necessary AWS resources, including Lambda functions, CloudWatch log groups,
DynamoDB tables, and IAM roles.

## Usage

```hcl
module "cognito_custom_message_sender" {
  source = "github.com/sgtoj/terraform-aws-cognito-custom-message-sender.git?ref=main"

  # TBD
}
```

### Note

This module uses the `cloudposse/label/null` module for naming and tagging
resources. As such, it also includes a `context.tf` file with additional
optional variables you can set. Refer to the [`cloudposse/label` documentation](https://registry.terraform.io/modules/cloudposse/label/null/latest)
for more details on these variables.

## Requirements

- Terraform 0.13 and above
- Docker installed and running on the machine where Terraform is executed

## Inputs

| Name   | Description                                         | Type          | Default | Required |
|--------|-----------------------------------------------------|:-------------:|:-------:|:--------:|
| `name` | Name of the service                                 | `string`      | n/a     | yes      |

## Outputs

| Name            | Description                     |
|-----------------|---------------------------------|
| `kms_key_arn`   | The ARN to the KMS key.         |
| `lambda_fn_arn` | The ARN to the Lambda function. |

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
