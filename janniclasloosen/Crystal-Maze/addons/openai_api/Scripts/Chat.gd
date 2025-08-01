extends Node
class_name ChatGpt
var http_request: HTTPRequest
## Automaticly gets the api from the global script `OpenAi`

@onready var parent = get_parent()

func _ready():
	http_request = HTTPRequest.new()
	print(IP.resolve_hostname("api.openai.com", 443))
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)
	
##Sends an api request to chat gpt, will return a signal with a `Message` class.
func prompt_gpt(ListOfMessages:Array[Message], model: String = "gpt-o-mini", url:String="https://api.openai.com/v1/chat/completions"):
	var openai_api_key = parent.get_api()
	if !openai_api_key:
		return
	##req
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + openai_api_key
	]
	#Makes it a Array of dics insterad of Array of nodes
	var messages:Array[Dictionary] = []
	for i in ListOfMessages:
		messages.append(i.get_as_dict())
	
	var body = {
	"model": model,
	"messages": messages
	}
	var json = JSON.new()
	
	var body_json = json.stringify(body)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _http_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error with the request.")
		return
	
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Error parsing response.")
		return
	
	var response = json.get_data()
	var message = Message.new()
	
	##TODO: Add error handeling in case of bad response
	if not response.has("choices") or response["choices"].size() == 0:
		push_error("GPT response invalid or empty:\n" + JSON.stringify(response, "\t"))
		return

	var choice = response["choices"][0]
	var content = choice.get("message", {}).get("content", "")
	var role = choice.get("message", {}).get("role", "")

	message.set_role(role)
	message.set_content(content)

	parent.emit_signal("gpt_response_completed",message,response)
