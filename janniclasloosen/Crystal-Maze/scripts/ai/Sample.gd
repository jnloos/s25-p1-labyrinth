extends Node3D

@onready var open_ai = $OpenAi

# Called when the node enters the scene tree for the first time.
func _ready():
	##Conecting the output from chatgpt
	open_ai.connect("gpt_response_completed", gpt_response_completed)
	
	##Creating meessages template
	var messages:Array[Message] = [Message.new()]
	messages[0].set_content("say hi!")
	
	##setting the api key
	open_ai.set_api("API KEY")
	
	##Prompt chatgpt
	open_ai.prompt_gpt(messages, "gpt-3.5-turbo")
	
func gpt_response_completed(message:Message, response:Dictionary):
	printt(message.get_as_dict())
