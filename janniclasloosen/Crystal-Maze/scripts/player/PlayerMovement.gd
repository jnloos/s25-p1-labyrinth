extends CharacterBody3D

@export var walk_speed: float = 2.0
@export var run_speed: float  = 6.0
@export var turn_speed: float = 180.0

@onready var anim_player: AnimationPlayer = $HeroAsset/AnimationPlayer

var walk_mode_enabled: bool = false  # Neuer Zustandsspeicher

func _ready() -> void:
	Reference.player = self
	add_to_group("player")

	var dir_ctx = Context.new("direction_to_treasure", Callable(self, "target_direction"))
	MCP.add_global_context(dir_ctx)

	var dist_ctx = Context.new("distance_to_treasure", Callable(self, "target_distance"))
	MCP.add_global_context(dist_ctx)

func target_distance():
	var maze = get_node("/root/Maze")
	return maze.get_distance_to_target(global_position)

func target_direction():
	var maze = get_node("/root/Maze")
	return maze.get_direction_to_target(global_position)

func _physics_process(delta: float) -> void:
	# Fokus auf UI blockiert Bewegung
	if get_viewport().gui_get_focus_owner() != null:
		return
		
	# Wenn pausiert, keine Bewegung und Idle-Animation
	if PauseManager.is_paused():
		velocity = Vector3.ZERO
		move_and_slide()
		if anim_player.current_animation != "Idle":
			anim_player.play("Idle")
		return

	# Umschaltmechanismus für Walk-Modus
	if Input.is_action_just_pressed("toggle_walk"):
		walk_mode_enabled = !walk_mode_enabled

	# Bewegung berechnen
	var input_vec = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_vec -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		input_vec += transform.basis.z
	if Input.is_action_pressed("rotate_left"):
		rotation.y += deg_to_rad(turn_speed * delta)
	if Input.is_action_pressed("rotate_right"):
		rotation.y -= deg_to_rad(turn_speed * delta)
	input_vec = input_vec.normalized()

	var speed: float = walk_speed if walk_mode_enabled else run_speed
	velocity = input_vec * speed
	move_and_slide()

	# Animationen
	if input_vec.length() > 0.01:
		var target_anim: String = "Walking_B" if walk_mode_enabled else "Running_B"
		if anim_player.current_animation != target_anim:
			anim_player.play(target_anim)
	else:
		if anim_player.current_animation != "Idle":
			anim_player.play("Idle")
