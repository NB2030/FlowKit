@tool
extends EditorInspectorPlugin

## FlowKit Custom Inspector Plugin
## Adds FlowKit section to all nodes in the inspector

var registry: FKRegistry = null
var editor_interface: EditorInterface = null

func _can_handle(object: Object) -> bool:
	# Handle all Node types
	return object is Node

func _parse_begin(object: Object) -> void:
	if not object is Node:
		return
	
	var node: Node = object as Node
	
	# Create the FlowKit inspector section
	var inspector: Control = preload("res://addons/flowkit/ui/inspector/flowkit_inspector_section.gd").new()
	inspector.set_node(node)
	if registry:
		inspector.set_registry(registry)
	if editor_interface:
		inspector.set_editor_interface(editor_interface)
	
	add_custom_control(inspector)

func set_registry(p_registry: FKRegistry) -> void:
	registry = p_registry

func set_editor_interface(p_editor_interface: EditorInterface) -> void:
	editor_interface = p_editor_interface
