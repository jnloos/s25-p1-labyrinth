extends RefCounted
class_name Handler

var name: String
var description: String = ""
var parameters: Array = []
var handler: Callable = Callable()

func _init(_name: String, _handler := Callable()) -> void:
	name = _name
	handler = _handler

func add_desc(desc: String) -> Handler:
	description = desc
	return self

func add_param(param: String, type: String) -> Handler:
	parameters.append({
		"name": param,
		"type": type
	})
	return self

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"name": name,
		"description": description
	}
	if parameters.size() > 0:
		d["parameters"] = parameters
	return d

func get_name() -> String:
	return name

func get_handler() -> Callable:
	return handler
