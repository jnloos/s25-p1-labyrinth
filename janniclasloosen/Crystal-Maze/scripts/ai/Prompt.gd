extends RefCounted
class_name Prompt

var name: String = ""
var params: Dictionary = {}

static var __cache: Dictionary = {}

func _init(prompt_name: String) -> void:
	name = prompt_name

func add_param(key: String, value) -> Prompt:
	params[key] = value
	return self

func add_params(dict: Dictionary) -> Prompt:
	for key in dict.keys():
		params[key] = dict[key]
	return self

func to_str() -> String:
	var template := __load_template(name)
	if template == "":
		return ""
	for key in params.keys():
		template = template.replace("{{" + key + "}}", str(params[key]))
	return template

static func __load_template(name: String) -> String:
	if __cache.has(name):
		return __cache[name]

	var path := "res://prompts/%s.txt" % name
	if not FileAccess.file_exists(path):
		push_error("Prompt template not found: %s" % path)
		return ""

	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	__cache[name] = content
	return content
