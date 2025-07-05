extends Control
class_name ManageChat

@onready var input_field := $VBoxContainer/LineEdit
@onready var send_button := $VBoxContainer/SendButton
@onready var listener_label := $VBoxContainer/Listeners
@onready var messages_box := $VBoxContainer/Messages
@onready var template_label := messages_box.get_node("Template")

var max_messages: int = 6
var visible_messages: Array[String] = []
var full_history: Array[String] = []

func _ready():
	Reference.chat = self
	Reference.interaction_area.listeners_updated.connect(__update_listener_label)
	__update_listener_label()
	send_button.pressed.connect(_on_send_pressed)
	__speak_text("Finde den Schatz! Er muss im Labyrinth versteckt sein!", 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		var current_focus = get_viewport().gui_get_focus_owner()
		if current_focus == input_field:
			get_viewport().gui_release_focus()
		else:
			input_field.grab_focus()
			input_field.caret_column = input_field.text.length()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("submit_chat"):
		if get_viewport().gui_get_focus_owner() == input_field:
			_on_send_pressed()
			get_viewport().gui_release_focus()
			get_viewport().set_input_as_handled()

func _on_send_pressed():
	var text = input_field.text.strip_edges()
	input_field.text = ""

	var listeners = Reference.interaction_area.get_listeners()
	__update_listener_label()

	if text == "" or listeners.is_empty():
		return

	__speak_text(text, 0)
	add_message("Spieler: " + text, Color.CORNFLOWER_BLUE, "player")

	var prompt := Prompt.new("response").add_param("message", text)
	var builder = AI.create_mcp(prompt)

	for npc in listeners:
		builder.add_context(npc.context())
		npc.register_ai_handlers(builder)

	builder.process_input()

func __update_listener_label():
	var listeners = Reference.interaction_area.get_listeners()
	if listeners.is_empty():
		listener_label.text = "Zuhörer: niemand"
	else:
		var names = listeners.map(func(n): return n.npc_name)
		listener_label.text = "Zuhörer: " + ", ".join(names)

func add_message(display_text: String, color: Color, sender_id: String):
	var label = template_label.duplicate()
	label.visible = true
	label.text = display_text
	label.add_theme_color_override("font_color", color)
	messages_box.add_child(label)

	visible_messages.append(display_text)

	var labels := messages_box.get_children()
	var message_labels := labels.filter(func(n): return n != template_label)

	while message_labels.size() > max_messages:
		var oldest = message_labels[0]
		oldest.queue_free()
		message_labels.remove_at(0)

	visible_messages = visible_messages.slice(-max_messages)
	
	var history_entry = "%s: %s" % [sender_id, display_text.split(": ", false)[1]]
	full_history.append(history_entry)
	MCP.add_global_context(Context.new("conversation", full_history.duplicate()))

func ai_message(message: String, npc_id: String):
	var npc = _resolve_npc_by_id(npc_id)
	if npc == null:
		push_warning("Ungültiger NPC: %s" % npc_id)
		return
	add_message("%s: %s" % [npc.npc_name, message], Color.WHITE, npc_id)
	__speak_text(message, npc.npc_gender)

func _resolve_npc_by_id(npc_id: String) -> SmartNPC:
	for npc in Reference.interaction_area.get_listeners():
		if npc.npc_id == npc_id:
			return npc
	return null

func __speak_text(text: String, gender: int = 1):
	var voice = DisplayServer.tts_get_voices_for_language("en")[gender % 2]
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voice)

func _toggle_chat_focus():
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner == input_field:
		input_field.release_focus()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		input_field.grab_focus()
		input_field.caret_column = input_field.text.length()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
