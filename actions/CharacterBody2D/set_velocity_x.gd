extends FKAction

func get_id() -> String:
	return "set_velocity_x"

func get_name() -> String:
	return "Set X Velocity"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "X", "type": "Float"}
	]

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary) -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var x: float = float(inputs.get("X", 0))
	
	body.velocity.x = x
