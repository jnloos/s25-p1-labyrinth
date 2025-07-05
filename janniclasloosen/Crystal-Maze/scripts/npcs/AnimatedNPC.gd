extends CharacterBody3D
class_name AnimatedNPC

@onready var anim_player: AnimationPlayer = $ControllerNpc/AnimationPlayer

const IDLE_ANIM := "Idle"
const WALK_ANIM := "Walking_B"
const RUN_ANIM := "Running_B"
const FIGHT_ANIM := "1H_Melee_Attack_Chop"
const CHEER_ANIM := "Cheer"
const INTERACT_ANIM := "Interact"

var _permanent_animation: String = ""
var _animation_active: bool = false
var animation_queue: Array[Dictionary] = []

func _ready() -> void:
	set_process(true)
	anim_player.animation_finished.connect(_on_animation_finished)
	play_idle_permanent()

func play_animation(anim_name: String, speed_override: float = 1.0) -> void:
	if not anim_player.has_animation(anim_name):
		push_warning("Animation '%s' nicht gefunden." % anim_name)
		return

	if speed_override < 0.0:
		anim_player.play_backwards(anim_name)
		anim_player.speed_scale = abs(speed_override)
	else:
		anim_player.speed_scale = speed_override
		anim_player.play(anim_name)

	var loops := anim_player.get_animation(anim_name).loop_mode != Animation.LOOP_NONE
	_animation_active = not loops

func play_animation_permanent(anim_name: String) -> void:
	if not anim_player.has_animation(anim_name):
		push_warning("Permanente Animation '%s' nicht gefunden." % anim_name)
		return

	_permanent_animation = anim_name

	var anim_res := anim_player.get_animation(anim_name)
	if anim_res.loop_mode == Animation.LOOP_NONE:
		anim_res.loop_mode = Animation.LOOP_LINEAR

	if not _animation_active and anim_player.current_animation != anim_name:
		_try_play_fallback()

func _try_play_fallback() -> void:
	if _permanent_animation == "":
		return
	if anim_player.current_animation == _permanent_animation and anim_player.is_playing():
		return
	anim_player.speed_scale = 1.0
	anim_player.play(_permanent_animation)
	_animation_active = false

func clear_animation_mode() -> void:
	_permanent_animation = ""
	_animation_active    = false
	animation_queue.clear()
	anim_player.stop()

func queue_animation(anim_name: String, priority: float = 1.0, speed_override: float = 1.0) -> void:
	if not anim_player.has_animation(anim_name):
		push_warning("Queued animation '%s' nicht gefunden." % anim_name)
		return

	animation_queue.append({
		"name": anim_name,
		"priority": priority,
		"speed": speed_override
	})

	animation_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["priority"] > b["priority"])

	if not _animation_active:
		_play_next_in_queue()

func _play_next_in_queue() -> void:
	if animation_queue.size() > 0:
		var next = animation_queue.pop_front()
		play_animation(next["name"], next["speed"])
	else:
		if not anim_player.is_playing():
			_try_play_fallback()

func _on_animation_finished(name: StringName) -> void:
	_animation_active = false
	_play_next_in_queue()

func play_idle_permanent() -> void:
	play_animation_permanent(IDLE_ANIM)
	
func play_idle() -> void:
	queue_animation(IDLE_ANIM)
	
func play_walk_permanent() -> void:
	play_animation_permanent(WALK_ANIM)
	
func play_walk() -> void:
	queue_animation(WALK_ANIM)
	
func play_run_permanent() -> void:
	play_animation_permanent(RUN_ANIM)

func play_run() -> void:
	queue_animation(RUN_ANIM)

func play_fight() -> void:
	queue_animation(FIGHT_ANIM,    5.0)

func play_cheer() -> void:
	queue_animation(CHEER_ANIM,    5.0)

func play_interact()  -> void:
	queue_animation(INTERACT_ANIM, 5.0)
