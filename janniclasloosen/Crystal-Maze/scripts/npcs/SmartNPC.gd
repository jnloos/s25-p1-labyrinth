extends AnimatedNPC
class_name SmartNPC

var npc_id: String = ""
static var __npc_instance_counter: int = 0

var npc_name: String = ""
var npc_gender: int = 0
var npc_description: String = ""
var npc_mood: String = "neutral"

var npc_data: Dictionary = {}

# Focus target
var curr_focus: Node3D = null
var focus_enabled := false

func _ready() -> void:
	super._ready()
	init_npc()

func _process(_delta: float) -> void:
	if focus_enabled and is_instance_valid(curr_focus):
		face_target()

func init_npc() -> void:
	npc_id = "npc_%d" % __npc_instance_counter
	__npc_instance_counter += 1
	add_to_group("npc")

func face_target() -> void:
	if not is_instance_valid(curr_focus):
		return
	var direction = global_position.direction_to(curr_focus.global_position)
	direction.y = 0
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

func focus(target: Node3D) -> void:
	curr_focus = target
	focus_enabled = true

func defocus() -> void:
	curr_focus = null
	focus_enabled = false

func focus_player() -> void:
	focus(Reference.player)

func dist_to(node: Node3D) -> float:
	return global_position.distance_to(node.global_position)

func set_mood(mood: String) -> void:
	npc_mood = mood

func talk(message: String) -> void:
	Reference.chat.ai_message(message, npc_id)

func register_ai_handlers(mcp: MCP) -> void:
	if mcp == null:
		push_warning("Kann AI-Animationen nicht registrieren: MCP ist null.")
		return
	if npc_id == "":
		push_error("NPC-ID ist leer – init_npc() wurde wahrscheinlich nicht aufgerufen.")
		return

	var suffix := ":" + npc_id

	mcp.add_handler(Handler.new("fight" + suffix, Callable(self, "play_fight")) \
		.add_desc("Spiele Kampf-Animation für NPC mit ID '%s'" % npc_id))

	mcp.add_handler(Handler.new("cheer" + suffix, Callable(self, "play_cheer")) \
		.add_desc("Spiele Jubeln-Animation für NPC mit ID '%s'" % npc_id))

	mcp.add_handler(Handler.new("interact" + suffix, Callable(self, "play_interact")) \
		.add_desc("Spiele Interaktionsanimation für NPC mit ID '%s'" % npc_id))

	mcp.add_handler(Handler.new("talk:" + npc_id, Callable(self, "talk")) \
		.add_desc("NPC '%s' spricht mit dem Spieler." % npc_id) \
		.add_param("message", "string"))

	mcp.add_handler(Handler.new("set_mood" + suffix, Callable(self, "set_mood")) \
		.add_desc("Ändere die Stimmung des NPC mit ID '%s'" % npc_id) \
		.add_param("mood", "string"))

func context() -> Context:
	npc_data["id"] = npc_id
	npc_data["name"] = npc_name
	npc_data["gender"] = npc_gender
	npc_data["description"] = npc_description
	npc_data["mood"] = npc_mood
	npc_data["distance_to_player"] = snapped(dist_to(Reference.player), 0.1)
	return Context.new(npc_id, npc_data)

# Override in subclasses if necessary
func on_player_approaching() -> void:
	pass

# Override in subclasses if necessary
func on_player_distancing() -> void:
	pass
