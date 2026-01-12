package cognito_custom_sender_sms_policy
import rego.v1

# default to sending message
default result := {
	"action": "allow",
	"allow": {
		"message": "Your code is: {####}",
		"messageType": "Transactional",
		"senderId": "",
		"shortCode": "",
	},
}

# block if rate limit exceeded
result := {
	"action": "block",
	"block": {"reason": "rate limit exceeded"},
} if {
	input.history.recentAttempts > 5
}
