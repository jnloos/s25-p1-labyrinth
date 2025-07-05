extends SmartNPC

var possible_names := ["Knochenbert", "Ribby", "Schädelchen"]

var is_dead := true
var is_resurrecting := false

@export var death_anim: String = "Death_A"
@export var dead_pose_anim: String = "Death_A_Pose"

@onready var pivot: Node3D = get_parent().get_node_or_null("Pivot")

func _ready() -> void:
	super._ready()

	npc_name = possible_names[randi() % possible_names.size()]
	npc_gender = 0
	npc_description = Prompt.new("skeleton").to_str()

	if is_dead:
		_focus_on_pivot()
		play_animation_permanent(dead_pose_anim)
	else:
		focus_player()
		play_idle_permanent()

func _process(delta: float) -> void:
	super._process(delta)
	velocity = Vector3.ZERO
	
func die() -> void:
	if is_dead or is_resurrecting:
		return

	is_dead = true
	is_resurrecting = false

	_focus_on_pivot()

	super.queue_animation(death_anim, 10.0, 1.0)
	play_animation_permanent(dead_pose_anim)
	
	await get_tree().create_timer(1.5).timeout

func resurrect() -> void:
	if not is_dead or is_resurrecting:
		return

	is_dead = false
	is_resurrecting = true

	_focus_on_pivot()

	super.queue_animation(death_anim, 10.0, -1.0)
	play_idle_permanent()
	
	await get_tree().create_timer(1.5).timeout
	focus_player()
	
	is_resurrecting = false

func play_pose() -> void:
	play_animation_permanent(dead_pose_anim)

func _focus_on_pivot() -> void:
	if is_instance_valid(pivot):
		focus(pivot)
	else:
		defocus()

func queue_animation(anim_name: String, priority: float = 1.0, speed_override: float = 1.0) -> void:
	if is_dead and not is_resurrecting:
		resurrect()
	super.queue_animation(anim_name, priority, speed_override)

func _sub_register_ai_handlers(mcp: MCP) -> void:
	var suffix := ":" + npc_id

	mcp.add_handler(Handler.new("die" + suffix, Callable(self, "die"))
		.add_desc("Skelett '%s' legt sich ins Grab." % npc_id))

	mcp.add_handler(Handler.new("resurrect" + suffix, Callable(self, "resurrect"))
		.add_desc("Skelett '%s' steht wieder auf." % npc_id))

	mcp.add_handler(Handler.new("pose" + suffix, Callable(self, "play_pose"))
		.add_desc("Skelett '%s' posiert." % npc_id))

func _sub_context() -> Dictionary:
	return {
		"is_dead": is_dead,
		"is_resurrecting": is_resurrecting
	}
