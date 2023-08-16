package cognito_custom_sender_sms_policy

# default to sending message
default result = {
	"action": "allow",
	"allow": {
		"message": "Your code is: {####}",
		"messageType": "Transactional",
		"senderId": "",
		"shortCode": "",
	},
}

# block if rate limit exceeded
result = {
	"action": "block",
	"block": {"reason": "rate limit exceeded"},
} {
	input.history.recentAttempts > 5
}
