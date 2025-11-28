@tool
extends Control

var editor_interface: EditorInterface
var registry: Node
var generator
var current_scene_name: String = ""

# Scene preloads
const EVENT_SCENE = preload("res://addons/flowkit/ui/workspace/event.tscn")
const CONDITION_SCENE = preload("res://addons/flowkit/ui/workspace/condition.tscn")
const ACTION_SCENE = preload("res://addons/flowkit/ui/workspace/action.tscn")

# UI References
@onready var blocks_container := $OuterVBox/ScrollContainer/MarginContainer/BlocksContainer
@onready var empty_label := $OuterVBox/ScrollContainer/MarginContainer/BlocksContainer/EmptyLabel
@onready var add_event_btn := $OuterVBox/BottomMargin/ButtonContainer/AddEventButton
@onready var add_condition_btn := $OuterVBox/BottomMargin/ButtonContainer/AddConditionButton
@onready var add_action_btn := $OuterVBox/BottomMargin/ButtonContainer/AddActionButton

# Modals
@onready var select_node_modal := $SelectNodeModal
@onready var select_event_modal := $SelectEventModal
@onready var select_condition_modal := $SelectConditionModal
@onready var select_action_modal := $SelectActionModal
@onready var expression_modal := $ExpressionModal

# Workflow state
var pending_block_type: String = ""  # "event", "condition", "action"
var pending_node_path: String = ""
var pending_id: String = ""
var pending_target_node = null  # For insert/replace operations

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize UI state."""
	_show_empty_state()

func set_editor_interface(interface: EditorInterface) -> void:
	editor_interface = interface
	# Pass to modals (deferred in case they're not ready yet)
	if select_node_modal:
		select_node_modal.set_editor_interface(interface)
	if select_event_modal:
		select_event_modal.set_editor_interface(interface)
	if select_condition_modal:
		select_condition_modal.set_editor_interface(interface)
	if select_action_modal:
		select_action_modal.set_editor_interface(interface)
	if expression_modal:
		expression_modal.set_editor_interface(interface)
	else:
		# If modal isn't ready yet, defer it
		call_deferred("_set_expression_interface", interface)

func set_registry(reg: Node) -> void:
	registry = reg
	# Pass to modals (deferred in case they're not ready yet)
	if select_event_modal:
		select_event_modal.set_registry(reg)
	if select_condition_modal:
		select_condition_modal.set_registry(reg)
	if select_action_modal:
		select_action_modal.set_registry(reg)

func set_generator(gen) -> void:
	generator = gen

func _set_expression_interface(interface: EditorInterface) -> void:
	if expression_modal:
		expression_modal.set_editor_interface(interface)

func _process(_delta: float) -> void:
	if not editor_interface:
		return
	
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		if current_scene_name != "":
			current_scene_name = ""
			_clear_all_blocks()
			_show_empty_state()
		return
	
	var scene_path = scene_root.scene_file_path
	if scene_path == "":
		if current_scene_name != "":
			current_scene_name = ""
			_clear_all_blocks()
			_show_empty_state()
		return
	
	var scene_name = scene_path.get_file().get_basename()
	if scene_name != current_scene_name:
		current_scene_name = scene_name
		_load_scene_sheet()

# === Block Management ===

func _get_blocks() -> Array:
	"""Get all block nodes (excluding empty label)."""
	var blocks = []
	for child in blocks_container.get_children():
		if child != empty_label:
			blocks.append(child)
	return blocks

func _clear_all_blocks() -> void:
	"""Remove all blocks from the container."""
	for child in blocks_container.get_children():
		if child != empty_label:
			blocks_container.remove_child(child)
			child.queue_free()

func _show_empty_state() -> void:
	"""Show empty state UI (no scene loaded)."""
	empty_label.visible = true
	add_event_btn.visible = false
	add_condition_btn.visible = false
	add_action_btn.visible = false

func _show_empty_blocks_state() -> void:
	"""Show state when scene is loaded but has no blocks."""
	empty_label.visible = false
	add_event_btn.visible = true
	add_condition_btn.visible = true
	add_action_btn.visible = true

func _show_content_state() -> void:
	"""Show content state UI."""
	empty_label.visible = false
	add_event_btn.visible = true
	add_condition_btn.visible = true
	add_action_btn.visible = true

# === File Operations ===

func _get_sheet_path() -> String:
	"""Get the file path for current scene's event sheet."""
	if current_scene_name == "":
		return ""
	return "res://addons/flowkit/saved/event_sheet/%s.tres" % current_scene_name

func _load_scene_sheet() -> void:
	"""Load event sheet for current scene."""
	_clear_all_blocks()
	
	var sheet_path = _get_sheet_path()
	if sheet_path == "" or not FileAccess.file_exists(sheet_path):
		_show_empty_blocks_state()
		return
	
	var sheet = ResourceLoader.load(sheet_path)
	if not (sheet is FKEventSheet):
		_show_empty_blocks_state()
		return
	
	_populate_from_sheet(sheet)
	_show_content_state()

func _populate_from_sheet(sheet: FKEventSheet) -> void:
	"""Create block nodes from event sheet data."""
	# Add standalone conditions
	for condition_data in sheet.standalone_conditions:
		var condition_node = _create_condition_block(condition_data)
		blocks_container.add_child(condition_node)
		
		# Add its actions
		for action_data in condition_data.actions:
			var action_node = _create_action_block(action_data)
			blocks_container.add_child(action_node)
	
	# Add events
	for event_data in sheet.events:
		var event_node = _create_event_block(event_data)
		blocks_container.add_child(event_node)
		
		# Add its conditions
		for condition_data in event_data.conditions:
			var condition_node = _create_condition_block(condition_data)
			blocks_container.add_child(condition_node)
		
		# Add its actions
		for action_data in event_data.actions:
			var action_node = _create_action_block(action_data)
			blocks_container.add_child(action_node)

func _save_sheet() -> void:
	"""Generate and save event sheet from current blocks."""
	if current_scene_name == "":
		push_warning("No scene open to save event sheet.")
		return
	
	var sheet = _generate_sheet_from_blocks()
	
	var dir_path = "res://addons/flowkit/saved/event_sheet"
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	var sheet_path = _get_sheet_path()
	var error = ResourceSaver.save(sheet, sheet_path)
	
	if error == OK:
		print("✓ Event sheet saved: ", sheet_path)
	else:
		push_error("Failed to save event sheet: ", error)

func _generate_sheet_from_blocks() -> FKEventSheet:
	"""Build event sheet from block nodes in order."""
	var sheet = FKEventSheet.new()
	var events: Array[FKEventBlock] = []
	var standalone_conditions: Array[FKEventCondition] = []
	
	var current_event: FKEventBlock = null
	var current_standalone: FKEventCondition = null
	
	for block in _get_blocks():
		if block.has_method("get_event_data"):
			# Save previous context
			if current_event:
				events.append(current_event)
			if current_standalone:
				standalone_conditions.append(current_standalone)
			
			# Start new event
			var data = block.get_event_data()
			current_event = FKEventBlock.new()
			current_event.event_id = data.event_id
			current_event.target_node = data.target_node
			current_event.inputs = data.inputs.duplicate()
			current_event.conditions = [] as Array[FKEventCondition]
			current_event.actions = [] as Array[FKEventAction]
			current_standalone = null
			
		elif block.has_method("get_condition_data"):
			var data = block.get_condition_data()
			var new_cond = FKEventCondition.new()
			new_cond.condition_id = data.condition_id
			new_cond.target_node = data.target_node
			new_cond.inputs = data.inputs.duplicate()
			new_cond.negated = data.negated
			new_cond.actions = [] as Array[FKEventAction]
			
			if current_event:
				# Belongs to event
				current_event.conditions.append(new_cond)
			else:
				# Standalone condition
				if current_standalone:
					standalone_conditions.append(current_standalone)
				current_standalone = new_cond
			
		elif block.has_method("get_action_data"):
			var data = block.get_action_data()
			var new_action = FKEventAction.new()
			new_action.action_id = data.action_id
			new_action.target_node = data.target_node
			new_action.inputs = data.inputs.duplicate()
			
			if current_standalone:
				current_standalone.actions.append(new_action)
			elif current_event:
				current_event.actions.append(new_action)
	
	# Save final context
	if current_event:
		events.append(current_event)
	if current_standalone:
		standalone_conditions.append(current_standalone)
	
	sheet.events = events
	sheet.standalone_conditions = standalone_conditions
	return sheet

func _new_sheet() -> void:
	"""Create new empty sheet."""
	if current_scene_name == "":
		push_warning("No scene open to create event sheet.")
		return
	
	_clear_all_blocks()
	_show_content_state()

# === Block Creation ===

func _create_event_block(data: FKEventBlock) -> Control:
	"""Create event block node from data."""
	var node = EVENT_SCENE.instantiate()
	
	var copy = FKEventBlock.new()
	copy.event_id = data.event_id
	copy.target_node = data.target_node
	copy.inputs = data.inputs.duplicate()
	copy.conditions = [] as Array[FKEventCondition]
	copy.actions = [] as Array[FKEventAction]
	
	node.set_event_data(copy)
	node.set_registry(registry)
	_connect_event_signals(node)
	return node

func _create_condition_block(data: FKEventCondition) -> Control:
	"""Create condition block node from data."""
	var node = CONDITION_SCENE.instantiate()
	
	var copy = FKEventCondition.new()
	copy.condition_id = data.condition_id
	copy.target_node = data.target_node
	copy.inputs = data.inputs.duplicate()
	copy.negated = data.negated
	copy.actions = [] as Array[FKEventAction]
	
	node.set_condition_data(copy)
	node.set_registry(registry)
	_connect_condition_signals(node)
	return node

func _create_action_block(data: FKEventAction) -> Control:
	"""Create action block node from data."""
	var node = ACTION_SCENE.instantiate()
	
	var copy = FKEventAction.new()
	copy.action_id = data.action_id
	copy.target_node = data.target_node
	copy.inputs = data.inputs.duplicate()
	
	node.set_action_data(copy)
	node.set_registry(registry)
	_connect_action_signals(node)
	return node

# === Signal Connections ===

func _connect_event_signals(node) -> void:
	node.insert_condition_requested.connect(_on_event_insert_condition.bind(node))
	node.replace_event_requested.connect(_on_event_replace.bind(node))
	node.delete_event_requested.connect(_on_event_delete.bind(node))
	node.edit_event_requested.connect(_on_event_edit.bind(node))

func _connect_condition_signals(node) -> void:
	node.insert_condition_requested.connect(_on_condition_insert_condition.bind(node))
	node.replace_condition_requested.connect(_on_condition_replace.bind(node))
	node.delete_condition_requested.connect(_on_condition_delete.bind(node))
	node.negate_condition_requested.connect(_on_condition_negate.bind(node))
	node.edit_condition_requested.connect(_on_condition_edit.bind(node))

func _connect_action_signals(node) -> void:
	node.insert_action_requested.connect(_on_action_insert_action.bind(node))
	node.replace_action_requested.connect(_on_action_replace.bind(node))
	node.delete_action_requested.connect(_on_action_delete.bind(node))
	node.edit_action_requested.connect(_on_action_edit.bind(node))

# === Menu Button Handlers ===

func _on_new_sheet() -> void:
	_new_sheet()

func _on_save_sheet() -> void:
	_save_sheet()

func _on_generate_providers() -> void:
	if not generator:
		print("[FlowKit] Generator not available")
		return
	
	print("[FlowKit] Starting provider generation...")
	
	var result = generator.generate_all()
	
	var message = "Generation complete!\n"
	message += "Actions: %d\n" % result.actions
	message += "Conditions: %d\n" % result.conditions
	message += "Events: %d\n" % result.events
	
	if result.errors.size() > 0:
		message += "\nErrors:\n"
		for error in result.errors:
			message += "- " + error + "\n"
	
	message += "\nRestart Godot editor to load new providers?"
	
	print(message)
	
	# Show confirmation dialog with restart option
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "FlowKit Generator"
	dialog.ok_button_text = "Restart Editor"
	dialog.cancel_button_text = "Not Now"
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		# Restart the editor
		if editor_interface:
			editor_interface.restart_editor()
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		# Just reload registry without restart
		if registry:
			registry.load_all()
		dialog.queue_free()
	)

func _on_add_event_button_pressed() -> void:
	if not editor_interface:
		return
	_start_add_workflow("event")

func _on_add_condition_button_pressed() -> void:
	if not editor_interface:
		return
	_start_add_workflow("condition")

func _on_add_action_button_pressed() -> void:
	if not editor_interface:
		return
	_start_add_workflow("action")

# === Workflow System ===

func _start_add_workflow(block_type: String) -> void:
	"""Start workflow to add a new block."""
	pending_block_type = block_type
	pending_target_node = null
	
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.set_editor_interface(editor_interface)
	select_node_modal.populate_from_scene(scene_root)
	select_node_modal.popup_centered()

func _on_node_selected(node_path: String, node_class: String) -> void:
	"""Node selected in workflow."""
	pending_node_path = node_path
	select_node_modal.hide()
	
	match pending_block_type:
		"event", "event_replace":
			select_event_modal.populate_events(node_path, node_class)
			select_event_modal.popup_centered()
		"condition", "condition_replace":
			select_condition_modal.populate_conditions(node_path, node_class)
			select_condition_modal.popup_centered()
		"action", "action_replace":
			select_action_modal.populate_actions(node_path, node_class)
			select_action_modal.popup_centered()

func _on_event_selected(node_path: String, event_id: String, inputs: Array) -> void:
	"""Event type selected."""
	pending_id = event_id
	select_event_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, event_id, inputs)
		expression_modal.popup_centered()
	else:
		if pending_block_type == "event_replace":
			_replace_event({})
		else:
			_finalize_event_creation({})

func _on_condition_selected(node_path: String, condition_id: String, inputs: Array) -> void:
	"""Condition type selected."""
	pending_id = condition_id
	select_condition_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, condition_id, inputs)
		expression_modal.popup_centered()
	else:
		if pending_block_type == "condition_replace":
			_replace_condition({})
		else:
			_finalize_condition_creation({})

func _on_action_selected(node_path: String, action_id: String, inputs: Array) -> void:
	"""Action type selected."""
	pending_id = action_id
	select_action_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, action_id, inputs)
		expression_modal.popup_centered()
	else:
		if pending_block_type == "action_replace":
			_replace_action({})
		else:
			_finalize_action_creation({})

func _on_expressions_confirmed(_node_path: String, _id: String, expressions: Dictionary) -> void:
	"""Expressions entered."""
	expression_modal.hide()
	
	match pending_block_type:
		"event":
			_finalize_event_creation(expressions)
		"condition":
			_finalize_condition_creation(expressions)
		"action":
			_finalize_action_creation(expressions)
		"event_edit":
			_update_event_inputs(expressions)
		"condition_edit":
			_update_condition_inputs(expressions)
		"action_edit":
			_update_action_inputs(expressions)
		"event_replace":
			_replace_event(expressions)
		"condition_replace":
			_replace_condition(expressions)
		"action_replace":
			_replace_action(expressions)

func _finalize_event_creation(inputs: Dictionary) -> void:
	"""Create and add event block."""
	var data = FKEventBlock.new()
	data.event_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	data.conditions = [] as Array[FKEventCondition]
	data.actions = [] as Array[FKEventAction]
	
	var node = _create_event_block(data)
	
	if pending_target_node:
		var insert_idx = pending_target_node.get_index() + 1
		blocks_container.add_child(node)
		blocks_container.move_child(node, insert_idx)
	else:
		blocks_container.add_child(node)
	
	_show_content_state()
	_reset_workflow()

func _finalize_condition_creation(inputs: Dictionary) -> void:
	"""Create and add condition block."""
	var data = FKEventCondition.new()
	data.condition_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	data.negated = false
	data.actions = [] as Array[FKEventAction]
	
	var node = _create_condition_block(data)
	
	if pending_target_node:
		var insert_idx = pending_target_node.get_index() + 1
		blocks_container.add_child(node)
		blocks_container.move_child(node, insert_idx)
	else:
		blocks_container.add_child(node)
	
	_show_content_state()
	_reset_workflow()

func _finalize_action_creation(inputs: Dictionary) -> void:
	"""Create and add action block."""
	var data = FKEventAction.new()
	data.action_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	
	var node = _create_action_block(data)
	
	if pending_target_node:
		var insert_idx = pending_target_node.get_index() + 1
		blocks_container.add_child(node)
		blocks_container.move_child(node, insert_idx)
	else:
		blocks_container.add_child(node)
	
	_show_content_state()
	_reset_workflow()

func _update_event_inputs(expressions: Dictionary) -> void:
	"""Update existing event block with new inputs."""
	if pending_target_node:
		var data = pending_target_node.get_event_data()
		if data:
			data.inputs = expressions
			pending_target_node.update_display()
	_reset_workflow()

func _update_condition_inputs(expressions: Dictionary) -> void:
	"""Update existing condition block with new inputs."""
	if pending_target_node:
		var data = pending_target_node.get_condition_data()
		if data:
			data.inputs = expressions
			pending_target_node.update_display()
	_reset_workflow()

func _update_action_inputs(expressions: Dictionary) -> void:
	"""Update existing action block with new inputs."""
	if pending_target_node:
		var data = pending_target_node.get_action_data()
		if data:
			data.inputs = expressions
			pending_target_node.update_display()
	_reset_workflow()

func _replace_event(expressions: Dictionary) -> void:
	"""Replace existing event block with new type."""
	if not pending_target_node:
		_reset_workflow()
		return
	
	# Get old block's position and conditions/actions
	var old_data = pending_target_node.get_event_data()
	var old_index = pending_target_node.get_index()
	
	# Create new event data
	var new_data = FKEventBlock.new()
	new_data.event_id = pending_id
	new_data.target_node = pending_node_path
	new_data.inputs = expressions
	new_data.conditions = old_data.conditions if old_data else ([] as Array[FKEventCondition])
	new_data.actions = old_data.actions if old_data else ([] as Array[FKEventAction])
	
	# Create new block
	var new_node = _create_event_block(new_data)
	
	# Remove old block and insert new one at same position
	blocks_container.remove_child(pending_target_node)
	pending_target_node.queue_free()
	blocks_container.add_child(new_node)
	blocks_container.move_child(new_node, old_index)
	
	_reset_workflow()

func _replace_condition(expressions: Dictionary) -> void:
	"""Replace existing condition block with new type."""
	if not pending_target_node:
		_reset_workflow()
		return
	
	# Get old block's position and actions
	var old_data = pending_target_node.get_condition_data()
	var old_index = pending_target_node.get_index()
	
	# Create new condition data
	var new_data = FKEventCondition.new()
	new_data.condition_id = pending_id
	new_data.target_node = pending_node_path
	new_data.inputs = expressions
	new_data.negated = old_data.negated if old_data else false
	new_data.actions = old_data.actions if old_data else ([] as Array[FKEventAction])
	
	# Create new block
	var new_node = _create_condition_block(new_data)
	
	# Remove old block and insert new one at same position
	blocks_container.remove_child(pending_target_node)
	pending_target_node.queue_free()
	blocks_container.add_child(new_node)
	blocks_container.move_child(new_node, old_index)
	
	_reset_workflow()

func _replace_action(expressions: Dictionary) -> void:
	"""Replace existing action block with new type."""
	if not pending_target_node:
		_reset_workflow()
		return
	
	# Get old block's position
	var old_index = pending_target_node.get_index()
	
	# Create new action data
	var new_data = FKEventAction.new()
	new_data.action_id = pending_id
	new_data.target_node = pending_node_path
	new_data.inputs = expressions
	
	# Create new block
	var new_node = _create_action_block(new_data)
	
	# Remove old block and insert new one at same position
	blocks_container.remove_child(pending_target_node)
	pending_target_node.queue_free()
	blocks_container.add_child(new_node)
	blocks_container.move_child(new_node, old_index)
	
	_reset_workflow()

func _reset_workflow() -> void:
	"""Clear workflow state."""
	pending_block_type = ""
	pending_node_path = ""
	pending_id = ""
	pending_target_node = null

# === Event Block Handlers ===

func _on_event_insert_condition(signal_node, bound_node) -> void:
	pending_target_node = bound_node
	_start_add_workflow("condition")

func _on_event_replace(signal_node, bound_node) -> void:
	pending_target_node = bound_node
	pending_block_type = "event_replace"
	
	# Get current node path from the block being replaced
	var data = bound_node.get_event_data()
	if data:
		pending_node_path = data.target_node
	
	# Open node selector
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.set_editor_interface(editor_interface)
	select_node_modal.populate_from_scene(scene_root)
	select_node_modal.popup_centered()

func _on_event_delete(signal_node, bound_node) -> void:
	blocks_container.remove_child(bound_node)
	bound_node.queue_free()

func _on_event_edit(signal_node, bound_node) -> void:
	var data = bound_node.get_event_data()
	if not data:
		return
	
	# Get event provider to check if it has inputs
	var provider_inputs = []
	if registry:
		for provider in registry.event_providers:
			if provider.has_method("get_id") and provider.get_id() == data.event_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break
	
	if provider_inputs.size() > 0:
		# Set up editing mode
		pending_target_node = bound_node
		pending_block_type = "event_edit"
		pending_id = data.event_id
		pending_node_path = data.target_node
		
		# Open expression modal with current values
		expression_modal.populate_inputs(data.target_node, data.event_id, provider_inputs, data.inputs)
		expression_modal.popup_centered()
	else:
		print("Event has no inputs to edit")

# === Condition Block Handlers ===

func _on_condition_insert_condition(signal_node, bound_node) -> void:
	pending_target_node = bound_node
	_start_add_workflow("condition")

func _on_condition_replace(signal_node, bound_node) -> void:
	pending_target_node = bound_node
	pending_block_type = "condition_replace"
	
	# Get current node path from the block being replaced
	var data = bound_node.get_condition_data()
	if data:
		pending_node_path = data.target_node
	
	# Open node selector
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.set_editor_interface(editor_interface)
	select_node_modal.populate_from_scene(scene_root)
	select_node_modal.popup_centered()

func _on_condition_delete(signal_node, bound_node) -> void:
	blocks_container.remove_child(bound_node)
	bound_node.queue_free()

func _on_condition_negate(signal_node, bound_node) -> void:
	var data = bound_node.get_condition_data()
	data.negated = not data.negated
	bound_node.update_display()

func _on_condition_edit(signal_node, bound_node) -> void:
	var data = bound_node.get_condition_data()
	if not data:
		return
	
	# Get condition provider to check if it has inputs
	var provider_inputs = []
	if registry:
		for provider in registry.condition_providers:
			if provider.has_method("get_id") and provider.get_id() == data.condition_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break
	
	if provider_inputs.size() > 0:
		# Set up editing mode
		pending_target_node = bound_node
		pending_block_type = "condition_edit"
		pending_id = data.condition_id
		pending_node_path = data.target_node
		
		# Open expression modal with current values
		expression_modal.populate_inputs(data.target_node, data.condition_id, provider_inputs, data.inputs)
		expression_modal.popup_centered()
	else:
		print("Condition has no inputs to edit")

# === Action Block Handlers ===

func _on_action_insert_action(signal_node, bound_node) -> void:
	pending_target_node = bound_node
	_start_add_workflow("action")

func _on_action_replace(signal_node, bound_node) -> void:
	pending_target_node = bound_node
	pending_block_type = "action_replace"
	
	# Get current node path from the block being replaced
	var data = bound_node.get_action_data()
	if data:
		pending_node_path = data.target_node
	
	# Open node selector
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.set_editor_interface(editor_interface)
	select_node_modal.populate_from_scene(scene_root)
	select_node_modal.popup_centered()

func _on_action_delete(signal_node, bound_node) -> void:
	blocks_container.remove_child(bound_node)
	bound_node.queue_free()

func _on_action_edit(signal_node, bound_node) -> void:
	var data = bound_node.get_action_data()
	if not data:
		return
	
	# Get action provider to check if it has inputs
	var provider_inputs = []
	if registry:
		for provider in registry.action_providers:
			if provider.has_method("get_id") and provider.get_id() == data.action_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break
	
	if provider_inputs.size() > 0:
		# Set up editing mode
		pending_target_node = bound_node
		pending_block_type = "action_edit"
		pending_id = data.action_id
		pending_node_path = data.target_node
		
		# Open expression modal with current values
		expression_modal.populate_inputs(data.target_node, data.action_id, provider_inputs, data.inputs)
		expression_modal.popup_centered()
	else:
		print("Action has no inputs to edit")
