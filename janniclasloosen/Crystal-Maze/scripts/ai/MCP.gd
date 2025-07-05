extends Node3D
class_name MCP

# GLOBAL
static var _global_handlers: Dictionary = {}
static var _global_capabilities: Array = []
static var _global_contexts: Dictionary = {}

# INSTANCE
var handlers: Dictionary = {}
var capabilities: Array = []
var context: Dictionary = {}
var prompt: Prompt = null
var wrapper: Prompt = null
var openai: Node = null 
var model: String = "gpt-4.1"

func _init(p: Prompt = null, model_name: String = "gpt-4.1") -> void:
	wrapper = Prompt.new("wrapper")
	prompt = p
	model = model_name

static func add_global_handler(handler: Handler) -> void:
	var name := handler.get_name()
	if handler.get_handler().is_valid() and not _global_handlers.has(name):
		_global_handlers[name] = handler.get_handler()
		_global_capabilities.append(handler.to_dict())

func add_handler(handler: Handler) -> MCP:
	var name := handler.get_name()
	if handler.get_handler().is_valid() and not handlers.has(name):
		handlers[name] = handler.get_handler()
		capabilities.append(handler.to_dict())
	return self

static func add_global_context(ctx: Context) -> void:
	_global_contexts[ctx.key] = ctx

func add_context(ctx: Context) -> MCP:
	context[ctx.key] = ctx
	return self

func process_input() -> MCP:
	if not openai:
		push_error("MCP: No OpenAI node set.")
		return self

	if prompt == null:
		push_error("MCP: No prompt template set.")
		return self

	# Prepare context list
	var ctx_dict = {}
	for c in _global_contexts.values():
		ctx_dict.merge(c.to_dict(), true)
	for c in context.values():
		ctx_dict.merge(c.to_dict(), true)

	# Prepare param list
	var all_capabilities := _global_capabilities + capabilities
	var all_handlers := _global_handlers.duplicate()
	all_handlers.merge(handlers, true)

	# Prepare action list
	var action_list: Array = []
	for c in all_capabilities:
		var name: String = c.get("name")
		var desc: String = c.get("description", "")
		var param_obj := {}

		var params: Array = c.get("parameters", [])
		for param in params:
			var pname: String = param.get("name", "")
			var ptype: String = param.get("type", "any")
			param_obj[pname] = ptype

		action_list.append({
			"action": name,
			"parameters": param_obj,
			"description": desc
		})
		
	# Prepare context as JSON
	var context_list := JSON.stringify(ctx_dict, "\t")

	# Prepare prompt
	wrapper.add_params({
		"situation": prompt.to_str(),
		"context_list": context_list,
		"action_list": JSON.stringify(action_list)
	})
	var prompt_text := wrapper.to_str()
	print("[MCP -> OpenAI]\n", prompt_text)

	# Prepare final message
	var msg := Message.new()
	msg.set_content(prompt_text)
	var messages: Array[Message] = [msg]

	# Send request and fetch response
	openai.gpt_response_completed.connect(self.interpret_response)
	openai.prompt_gpt(messages, model)
	return self
	
func interpret_response(message: Message, response: Dictionary):
	openai.gpt_response_completed.disconnect(self.interpret_response)
	
	# Prepare JSON response
	var content: String = message.get_content()
	var result = JSON.new()
	if result.parse(content) != OK:
		push_warning("JSON parsing failed: %s" % content)
		return
	print("[MCP <- OpenAI]\n", content)

	var data = result.data
	if typeof(data) == TYPE_DICTIONARY:
		data = [data]
	elif typeof(data) != TYPE_ARRAY:
		push_warning("Expected array or object in AI response.")
		return
	
	# Parse and call handlers
	for entry in data:
		if not entry.has("action"):
			push_warning("Missing 'action' in AI response entry.")
			continue

		var action: String = entry["action"]
		var reason: String = entry.get("reason", "")

		# Merge parameters from nested object if necessary
		if entry.has("parameters") and typeof(entry["parameters"]) == TYPE_DICTIONARY:
			for key in entry["parameters"].keys():
				# Don't overwrite existing top-level fields
				if not entry.has(key):
					entry[key] = entry["parameters"][key]

		var handler_callable = handlers.get(action, _global_handlers.get(action, null))
		if handler_callable and handler_callable.is_valid():
			var param_defs := []
			for c in capabilities + _global_capabilities:
				if c.get("name", "") == action:
					param_defs = c.get("parameters", [])
					break
					
			if param_defs.is_empty():
				handler_callable.call()
			else:
				var args: Array = []
				for param in param_defs:
					var raw = entry.get(param["name"])
					match param["type"]:
						"int": args.append(int(raw))
						"float": args.append(float(raw))
						"string": args.append(str(raw))
						"bool": args.append(bool(raw))
						_: args.append(raw)
				handler_callable.callv(args)
		else:
			push_warning("Unknown action: %s" % action)
