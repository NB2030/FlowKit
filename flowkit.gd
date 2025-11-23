@tool
extends EditorPlugin

var action_registry
var editor

func _enable_plugin() -> void:
	# Add autoloads here if needed later.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here if needed later.
	pass

func _enter_tree() -> void:
	# Load UI
	editor = preload("res://addons/flowkit/ui/editor.tscn").instantiate()

	# Load registry
	action_registry = preload("res://addons/flowkit/registry.gd").new()
	action_registry.load_providers()

	# Pass editor interface and registry to the editor UI
	editor.set_editor_interface(get_editor_interface())
	editor.set_registry(action_registry)

	# Add runtime autoloads
	add_autoload_singleton(
		"FlowKitSystem",
		"res://addons/flowkit/runtime/flowkit_system.gd"
	)
	
	add_autoload_singleton(
		"FlowKit",
		"res://addons/flowkit/runtime/flowkit_engine.gd"
	)

	# Add editor panel
	add_control_to_bottom_panel(editor, "FlowKit")

func _exit_tree() -> void:
	action_registry.free()

	remove_autoload_singleton("FlowKitSystem")
	remove_autoload_singleton("FlowKit")
	remove_control_from_bottom_panel(editor)
	editor.free()