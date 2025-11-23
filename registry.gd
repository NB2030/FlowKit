extends Node
class_name FKRegistry

# Preload the expression evaluator
const FKExpressionEvaluator = preload("res://addons/flowkit/runtime/expression_evaluator.gd")

var action_providers: Array = []
var condition_providers: Array = []
var event_providers: Array = []

func load_all() -> void:
	_load_folder("actions", action_providers)
	_load_folder("conditions", condition_providers)
	_load_folder("events", event_providers)
	
	print("[FlowKit Registry] Loaded %d actions, %d conditions, %d events" % [
		action_providers.size(),
		condition_providers.size(),
		event_providers.size()
	])

func load_providers() -> void:
	# Alias for load_all() for backward compatibility
	load_all()

func _load_folder(subpath: String, array: Array) -> void:
	var path: String = "res://addons/flowkit/" + subpath
	_scan_directory_recursive(path, array)

func _scan_directory_recursive(path: String, array: Array) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var file_path: String = path + "/" + file_name
		
		if dir.current_is_dir():
			# Recursively scan subdirectories
			_scan_directory_recursive(file_path, array)
		elif file_name.ends_with(".gd") and not file_name.ends_with(".uid"):
			# Load the script and instantiate it
			var script: GDScript = load(file_path)
			if script:
				var instance: Variant = script.new()
				array.append(instance)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func poll_event(event_id: String, node: Node, inputs: Dictionary = {}) -> bool:
	for provider in event_providers:
		if provider.has_method("get_id") and provider.get_id() == event_id:
			if provider.has_method("poll"):
				# Evaluate expressions in inputs before polling
				var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node)
				return provider.poll(node, evaluated_inputs)
	return false

func check_condition(condition_id: String, node: Node, inputs: Dictionary, negated: bool = false) -> bool:
	for provider in condition_providers:
		if provider.has_method("get_id") and provider.get_id() == condition_id:
			if provider.has_method("check"):
				# Evaluate expressions in inputs before checking
				var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node)
				var result = provider.check(node, evaluated_inputs)
				return not result if negated else result
	return false

func execute_action(action_id: String, node: Node, inputs: Dictionary) -> void:
	for provider in action_providers:
		if provider.has_method("get_id") and provider.get_id() == action_id:
			if provider.has_method("execute"):
				# Evaluate expressions in inputs before executing
				var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node)
				provider.execute(node, evaluated_inputs)
				return
