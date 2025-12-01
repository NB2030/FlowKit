extends FKCondition

func get_description() -> String:
	return "Compares a property of the node against a specified value using the given comparison operator."

func get_id() -> String:
	return "compare_node_variable"

func get_name() -> String:
	return "Compare Node Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Property", "type": "String", "description": "The property path of the node to compare (e.g., 'position/x', 'velocity/y')."},
		{"name": "Comparison", "type": "String", "description": "The comparison operator to use (e.g., '==', '!=', '<', '>', '<=', '>=')."},
		{"name": "Value", "type": "Variant", "description": "The value to compare the property against."}
	]

func get_supported_types() -> Array[String]:
	return ["Node"]

func check(node: Node, inputs: Dictionary) -> bool:
	var property_path: String = str(inputs.get("Property", ""))
	var comparison: String = str(inputs.get("Comparison", "=="))
	var compare_value: Variant = inputs.get("Value", null)
	
	if property_path.is_empty():
		return false
	
	# Get the property value from the node using indexed access
	# Supports nested properties like "velocity/x" or "position/y"
	var current_value: Variant = get_property_value(node, property_path)
	if current_value == null:
		return false
	
	match comparison:
		"==": return current_value == compare_value
		"!=": return current_value != compare_value
		"<": return current_value < compare_value
		">": return current_value > compare_value
		"<=": return current_value <= compare_value
		">=": return current_value >= compare_value
		_: return current_value == compare_value

func get_property_value(obj: Variant, path: String) -> Variant:
	if path.is_empty():
		return null

	# Split by dots OR slashes
	var parts = path.split("/", false)
	if parts.size() == 1:
		parts = path.split(".", false)

	# First: Godot-level property access
	var base = parts[0]
	var value = obj.get_indexed(base)
	if value == null:
		return null

	# If only one property, return it
	if parts.size() == 1:
		return value

	# Remaining parts = struct fields or dictionary entries
	for i in range(1, parts.size()):
		var key = parts[i]

		# Vector2, Vector3, Rect2, etc. → field access
		if typeof(value) == TYPE_VECTOR2:
			if key == "x": value = value.x
			elif key == "y": value = value.y
			else: return null

		elif typeof(value) == TYPE_VECTOR3:
			if key in ["x","y","z"]:
				value = value[key]
			else:
				return null

		# Dictionaries
		elif typeof(value) == TYPE_DICTIONARY:
			if value.has(key):
				value = value[key]
			else:
				return null

		# Arrays
		elif typeof(value) == TYPE_ARRAY:
			var idx = int(key)
			if idx >= 0 and idx < value.size():
				value = value[idx]
			else:
				return null

		# For other types, no deeper traversal
		else:
			return null

	return value
