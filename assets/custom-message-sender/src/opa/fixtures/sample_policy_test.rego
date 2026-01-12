package sample
import rego.v1

test_sample if {
	request := {"message": "world"}
	response = validate with input as request
	print(response)
	response == true
}
