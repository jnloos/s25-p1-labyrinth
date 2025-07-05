extends RefCounted
class_name Context

var key: String
var value

func _init(_key: String, _value) -> void:
	key = _key
	value = _value

func to_dict() -> Dictionary:
	if typeof(value) == TYPE_CALLABLE and value.is_valid():
		return { key: value.call() }
	else:
		return { key: value }
