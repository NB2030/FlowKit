extends FKCondition

func get_id() -> String:
	return "compare_variable"

func get_name() -> String:
	return "Compare Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Name", "type": "String"},
		{"name": "Comparison", "type": "String"},  # ==, !=, <, >, <=, >=
		{"name": "Value", "type": "Variant"}
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func check(node: Node, inputs: Dictionary) -> bool:
	var name: String = str(inputs.get("Name", ""))
	var comparison: String = str(inputs.get("Comparison", "=="))
	var compare_value: Variant = inputs.get("Value", null)
	
	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if not system or not system.has_method("get_var"):
		return false
	
	var var_value: Variant = system.get_var(name, null)
	
	match comparison:
		"==": return var_value == compare_value
		"!=": return var_value != compare_value
		"<": return var_value < compare_value
		">": return var_value > compare_value
		"<=": return var_value <= compare_value
		">=": return var_value >= compare_value
		_: return var_value == compare_value
