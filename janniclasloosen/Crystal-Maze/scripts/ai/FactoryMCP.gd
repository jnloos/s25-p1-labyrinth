extends Node
class_name Intelligence

@onready var openai := $OpenAi

func create_mcp(prompt: Prompt) -> MCP:
	var mcp := MCP.new(prompt)
	
	var key := load_api_key()
	openai.set_api(key)
	mcp.openai = openai

	var handler = Handler.new("test", Callable(self, "test_log")) \
		.add_desc("Execute a test response and log it into the console.")
	MCP.add_global_handler(handler)

	return mcp

func test_log():
	print("OpenAI responed properly and the test was succesful.")

func load_api_key() -> String:
	var file := FileAccess.open("res://auth.txt", FileAccess.READ)
	if file:
		var key = file.get_as_text().strip_edges()
		file.close()
		return key
	else:
		push_warning("Could not open auth.txt for OpenAi API key.")
		return ""
