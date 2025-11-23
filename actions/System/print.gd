extends FKAction

func get_id() -> String:
	return "print"

func get_name() -> String:
	return "Print"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Message", "type": "String"},
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary) -> void:
	var message: Variant = inputs.get("Message", "")
	print(message)
