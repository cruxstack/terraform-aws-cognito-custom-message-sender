package cognito_custom_sender_sms_policy

default results = {
	"action": "allow",
	"allow": {
		"message": "Your code is: {####}",
		"messageType": "Transactional",
		"senderId": "",
		"shortCode": "",
	},
}

result = {
	"action": "block",
	"block": {"reason": "rate limit exceeded"},
} {
	input.history.recentAttempts > 5
}
