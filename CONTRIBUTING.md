# Contributing to Terraform AWS Cognito Custom Message Sender

We welcome contributions to the project. This document provides information and
guidelines for contributing.

## How the module fits together

Both Lambdas run [cognito-custom-message-sender-go](https://github.com/cruxstack/cognito-custom-message-sender-go).
`assets/sender/Dockerfile` clones it at `sender_version`, builds it, and
packages the binary with the email and SMS policies; the module passes its
settings as `APP_*` environment variables. Changes to that contract (new
settings, renamed variables) start in the Go repository, and the module pins
the sender version that matches its variables.

## Development environment

You need Terraform (1.7 or later), Docker, and optionally
[TFLint](https://github.com/terraform-linters/tflint) and the
[OPA CLI](https://www.openpolicyagent.org/docs/cli) for policies. A
[dev container](.devcontainer) with these tools is included.

```sh
terraform init
terraform fmt -check -recursive
terraform validate
terraform test   # plans the module with mocked providers; no AWS account needed
tflint
```

`tests/sender.tftest.hcl` checks the planned Lambdas, environment variables,
tables, and input validation. Add a run block when you add a variable or
change what the module passes to the sender. To deploy for real, use
`examples/complete`.

## Contribution Guidelines

We appreciate your interest in contributing to the project. Here are some
guidelines to help ensure your contributions are accepted.

### Issues

- Use the GitHub issue tracker to report bugs or propose new features.
- Before submitting a new issue, please search to make sure it has not already
  been reported. If it has, add a comment to the existing issue instead of
  creating a new one.
- When reporting a bug, include as much detail as you can. Include the version
  of the module you're using, what you expected to happen, what actually
  happened, and steps to reproduce the bug.

### Pull Requests

- Submit your changes as a pull request.
- All pull requests should be associated with an issue. If your change isn't
  associated with an existing issue, please create one before submitting a pull
  request.
- In your pull request, include a summary of the changes, the issue number it
  resolves, and any additional information that might be helpful for
  understanding your changes.
- Make sure your changes do not break any existing functionality. If your
  changes require updates to existing tests or the addition of new ones, include
  those in your pull request.
- Follow the existing code style. We use a linter to maintain code quality, so
  make sure your changes pass the linter checks.

Thank you for your contributions!
