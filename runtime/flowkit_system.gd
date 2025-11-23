extends Node

## The System object - a global singleton accessible in every scene
## Similar to Clickteam Fusion's System object

# Signals that can be used with events
signal on_ready_triggered
signal on_process_triggered

var _ready_fired: bool = false

# Global variable storage
var variables: Dictionary = {}

func _ready() -> void:
	if not _ready_fired:
		_ready_fired = true
		on_ready_triggered.emit()

func _process(_delta: float) -> void:
	on_process_triggered.emit()

# Global print function
func print_message(message: String) -> void:
	print("[System]: %s" % message)

# Variable management
func set_var(name: String, value: Variant) -> void:
	variables[name] = value

func get_var(name: String, default: Variant = null) -> Variant:
	return variables.get(name, default)

func has_var(name: String) -> bool:
	return variables.has(name)

func clear_var(name: String) -> void:
	variables.erase(name)

func clear_all_vars() -> void:
	variables.clear()
