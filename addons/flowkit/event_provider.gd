# event_provider.gd
extends Resource
class_name FKEventProvider

func get_supported_types() -> Array[String]:
	return []

func get_events_for(node: Node) -> Array[Dictionary]:
	return []

func poll(event_id: String, node: Node) -> bool:
	# Should return true when event fires
	return false
