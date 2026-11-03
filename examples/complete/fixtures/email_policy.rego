package cognito_custom_sender_email_policy

import rego.v1

# one SES template per message type; the code is added as templateData.code
templates := {
	"CustomEmailSender_SignUp": "example-welcome",
	"CustomEmailSender_ResendCode": "example-welcome",
	"CustomEmailSender_ForgotPassword": "example-reset-password",
	"CustomEmailSender_AdminCreateUser": "example-invitation",
}

default template := "example-code"

template := templates[input.trigger]

result := {
	"action": "allow",
	"allow": {
		"srcAddress": "Example <no-reply@example.com>",
		"providers": {"ses": {"templateId": template, "templateData": {"appName": "Example"}}},
	},
}
