extends Control

@onready var camera := get_node("../CameraRig/Camera3D")
@onready var pivot := $Pivot

func _ready():
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)

func _process(_delta: float) -> void:
	if camera == null:
		return

	var forward = -camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	var angle_deg = rad_to_deg(atan2(forward.x, forward.z))
	pivot.rotation_degrees = -angle_deg
