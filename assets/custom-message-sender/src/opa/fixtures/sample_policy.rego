package sample
import rego.v1

default validate := false

validate if input.message == "world"
