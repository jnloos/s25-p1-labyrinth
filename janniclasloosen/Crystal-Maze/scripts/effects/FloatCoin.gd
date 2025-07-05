extends Node3D

# Exportierte Variablen im Inspector
@export var max_height: float = 50.0  # wie weit er über den Startpunkt hinaus steigt
@export var speed:      float = 2.0   # Wie schnell gebobbt wird (Periodendauer)
@export var rot_speed:  float = 1.0

# Interne Variablen
var _origin: Vector3      # Start-Position als Unterkante
var _time_acc: float = 0  # akkumulierte Laufzeit

func _ready() -> void:
	_origin = global_transform.origin

func _process(delta: float) -> void:
	# 1. Laufzeit akkumulieren
	_time_acc += delta
	
	# 2. Sinus-Welle zwischen –1 und +1
	var sine_wave = sin(_time_acc * speed)
	# 3. Normierung auf [0,1]
	var t = (sine_wave + 1.0) * 0.5
	# 4. Offset von 0 bis max_height
	var offset_y = lerp(0.0, max_height, t)
	
	# 5. Neue Position setzen (Y-Bobbing)
	var new_origin = _origin + Vector3(0, offset_y, 0)
	global_transform.origin = new_origin
	
	# 6. Rotation um lokale Y-Achse hinzufügen
	#    delta * rot_speed ist der Winkel (in Radiant), um den wir in diesem Frame rotieren
	rotate_y(delta * rot_speed)
