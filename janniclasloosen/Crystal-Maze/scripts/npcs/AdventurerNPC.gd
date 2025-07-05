extends SmartNPC

enum MovementMode { NONE, STEP, FOLLOW }

var possible_names := [
	"Arwen", "Eowyn", "Galadriel", "Luthien", "Idril", "Melian", "Yavanna", "Elwing"
]

var movement_mode: int = MovementMode.NONE
var is_following: bool = false
var min_distance: float = 2.5

@export var walk_speed: float = 2.0
@export var run_speed: float = 6.0

var _step_timer := 0.0
var _step_duration := 2.0
var _step_velocity: Vector3 = Vector3.ZERO
var _post_step_follow_timer: float = -1.0

var _movement_state: String = "idle"

func _ready() -> void:
	super._ready()
	npc_name = possible_names[randi() % possible_names.size()]
	npc_gender = 1
	npc_description = Prompt.new("adventurer").to_str()
	play_idle_permanent()

func _process(delta: float) -> void:
	super._process(delta)

	var v := Vector3.ZERO

	match movement_mode:
		MovementMode.STEP:
			_step_timer -= delta
			if _step_timer <= 0.0:
				_step_timer = 0.0
				movement_mode = MovementMode.NONE
				_post_step_follow_timer = 4.0
				if is_following:
					focus_enabled = true  # Reaktiviert Rotation nach STEP
			else:
				v = _step_velocity

		MovementMode.FOLLOW:
			var player := Reference.player
			if not is_instance_valid(player) or not is_following:
				movement_mode = MovementMode.NONE
			else:
				var dir := player.global_position - global_position
				dir.y = 0
				var dist := dir.length()

				match _movement_state:
					"idle":
						if dist > min_distance:
							_movement_state = "walk"
							play_walk_permanent()
					"walk":
						if dist <= min_distance:
							_movement_state = "idle"
							play_idle_permanent()
						elif dist > 6.0:
							_movement_state = "run"
							play_run_permanent()
						else:
							play_walk_permanent()
					"run":
						if dist <= 4.0:
							_movement_state = "walk"
							play_walk_permanent()
						else:
							play_run_permanent()

				if dist > min_distance:
					var speed := run_speed if _movement_state == "run" else walk_speed
					v = dir.normalized() * speed

		MovementMode.NONE:
			pass

	# Timer nach STEP: Rückkehr zu FOLLOW
	if _post_step_follow_timer > 0.0:
		_post_step_follow_timer -= delta
		if _post_step_follow_timer <= 0.0 and is_following:
			movement_mode = MovementMode.FOLLOW
			_post_step_follow_timer = -1.0

	velocity = v
	move_and_slide()

func do_step(dir: Vector3) -> void:
	movement_mode = MovementMode.STEP
	_step_timer = _step_duration
	_step_velocity = dir.normalized() * walk_speed
	_post_step_follow_timer = -1.0
	focus_enabled = false  # Deaktiviert Rotation während STEP

func step_back() -> void:
	if is_instance_valid(Reference.player):
		var dir = global_position - Reference.player.global_position
		dir.y = 0
		do_step(dir.normalized())

func step_forward() -> void:
	if is_instance_valid(Reference.player):
		var dir = Reference.player.global_position - global_position
		dir.y = 0
		do_step(dir.normalized())

func step_left() -> void:
	if is_instance_valid(Reference.player):
		var dir = global_position - Reference.player.global_position
		dir.y = 0
		var right = dir.cross(Vector3.UP).normalized()
		do_step(-right)

func step_right() -> void:
	if is_instance_valid(Reference.player):
		var dir = global_position - Reference.player.global_position
		dir.y = 0
		var right = dir.cross(Vector3.UP).normalized()
		do_step(right)

func follow_player() -> void:
	if Reference.player == null:
		push_warning("Kein Spieler verfügbar zum Folgen.")
		return
	is_following = true
	movement_mode = MovementMode.FOLLOW
	focus_player()

func unfollow_player() -> void:
	is_following = false
	movement_mode = MovementMode.NONE
	clear_animation_mode()
	play_idle_permanent()
	_movement_state = "idle"
	defocus()

func register_ai_handlers(mcp: MCP) -> void:
	var suffix := ":" + npc_id
	super.register_ai_handlers(mcp)

	mcp.add_handler(Handler.new("follow" + suffix, Callable(self, "follow_player")) \
		.add_desc("NPC mit ID '%s' beginnt, den Spieler durch das Labyrinth zu verfolgen." % npc_id))

	mcp.add_handler(Handler.new("unfollow" + suffix, Callable(self, "unfollow_player")) \
		.add_desc("NPC mit ID '%s' hört damit auf, den Spieler zu verfolgen und bleibt stehen." % npc_id))

	mcp.add_handler(Handler.new("step_forward" + suffix, Callable(self, "step_forward")) \
		.add_desc("NPC '%s' geht kurz geradeaus." % npc_id))

	mcp.add_handler(Handler.new("step_back" + suffix, Callable(self, "step_back")) \
		.add_desc("NPC '%s' macht einen Schritt zurück." % npc_id))

	mcp.add_handler(Handler.new("step_left" + suffix, Callable(self, "step_left")) \
		.add_desc("NPC '%s' geht kurz nach links." % npc_id))

	mcp.add_handler(Handler.new("step_right" + suffix, Callable(self, "step_right")) \
		.add_desc("NPC '%s' geht kurz nach rechts." % npc_id))

func context() -> Context:
	npc_data["is_following_player"] = is_following
	return super.context()

func on_player_approaching() -> void:
	focus_player()

func on_player_distancing() -> void:
	defocus()
