extends FKAction

func get_id() -> String:
	return "set_node_variable"

func get_name() -> String:
	return "Set Node Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Variable Name", "type": "String"},
		{"name": "Value", "type": "String"},
	]

func get_supported_types() -> Array[String]:
	return ["Node"]

func execute(node: Node, inputs: Dictionary) -> void:
	var var_name: String = inputs.get("Variable Name", "")
	var value: Variant = inputs.get("Value", "")
	
	if var_name.is_empty():
		push_error("[FlowKit] Set Node Variable: Variable name is empty")
		return
	
	# Use FlowKitSystem to set the node variable
	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("set_node_var"):
		system.set_node_var(node, var_name, value)
	else:
		push_error("[FlowKit] Set Node Variable: FlowKitSystem not found or method unavailable")
