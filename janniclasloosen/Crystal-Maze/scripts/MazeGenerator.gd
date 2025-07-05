extends Node3D
class_name MazeGenerator

@export var map_file_path: String = "res://maps/maze.txt"
@export var tile_size: Vector3 = Vector3(6, 0, 6)

# Start & Ziel
@export var start_scene: PackedScene = preload("res://assets/maze/Start.tscn")
@export var target_scene: PackedScene = preload("res://assets/maze/Target.tscn")

# Basis-Pfad für Ecken/Kreuzungen und als Variante
@export var base_path_scene: PackedScene = preload("res://assets/maze/paths/BasePath.tscn")
@export var base_path_weight: float = 1.0  # Gewicht für BasePath bei einfacher Zelle

# Walls + ihre Gewichte
@export var wall_scenes: Array[PackedScene] = []
@export var wall_weights: Array[float] = []

# NPCs + ihre Gewichte
@export var npc_scenes: Array[PackedScene] = []
var npc_list: Array[Node3D] = []

# Paths + ihre Gewichte (für spezielle Pfade)
@export var path_scenes: Array[PackedScene] = []
@export var path_weights: Array[float] = []

# Store target position and map
var target_position: Vector3 = Vector3.ZERO
var raw_map: Array[String] = []

func _ready() -> void:
	Reference.maze = self
	randomize()
	
	print("MazeGenerator starts.")
	assert(wall_scenes.size() == wall_weights.size())
	assert(path_scenes.size() == path_weights.size())
	generate_maze()
	print("MazeGenerator finished.")

	MCP.add_global_context(Context.new("maze_map", Callable(self, "create_map")))
	MCP.add_global_context(Context.new("player_position", Callable(self, "get_player_coords")))
	MCP.add_global_context(Context.new("target_position", Callable(self, "get_target_coords")))

func generate_maze() -> void:
	if not FileAccess.file_exists(map_file_path):
		push_error("Map-File not found: %s" % map_file_path)
		return

	var file: FileAccess = FileAccess.open(map_file_path, FileAccess.ModeFlags.READ)
	if file == null:
		push_error("Can not read file: %s" % map_file_path)
		return

	var lines: Array[String] = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	raw_map = lines.duplicate()

	var total_instances := 0
	var simple_path_cells = []
	
	for row in range(lines.size()):
		var line := lines[row]
		for col in range(line.length()):
			var c := line[col]
			var instance: Node3D = null

			match c:
				"#":
					instance = _choose_weighted(wall_scenes, wall_weights).instantiate() as Node3D
				" ":
					if _is_simple_cell(lines, row, col):
						var scenes := path_scenes.duplicate()
						var weights := path_weights.duplicate()
						scenes.append(base_path_scene)
						weights.append(base_path_weight)
						instance = _choose_weighted(scenes, weights).instantiate() as Node3D
						simple_path_cells.append(instance)
					else:
						instance = base_path_scene.instantiate() as Node3D
					_orient_corridor(instance, lines, row, col)
				"S":
					instance = start_scene.instantiate() as Node3D
				"T":
					instance = target_scene.instantiate() as Node3D
					target_position = Vector3(col * tile_size.x, 0, row * tile_size.z)
				_:
					pass
	
			if instance:
				total_instances += 1
				instance.position = Vector3(col * tile_size.x, 0, row * tile_size.z)
				add_child(instance)
				
	if npc_scenes.size() > simple_path_cells.size():
		push_warning("Nicht genug einfache Zellen für alle NPCs – einige werden nicht platziert.")
	simple_path_cells.shuffle()

	for i in range(npc_scenes.size()):
		var npc = npc_scenes[i].instantiate() as Node3D
		var old_node: Node3D = simple_path_cells[i]
		
		# Alte Node entfernen
		remove_child(old_node)
		old_node.queue_free()

		# NPC an dieselbe Stelle setzen
		npc.position = old_node.position
		npc.rotation = old_node.rotation
		add_child(npc)
		npc_list.append(npc)

	print(lines.size(), "x" , lines[0].length(), " Felder, ", total_instances, " Instanzen")

func _is_simple_cell(lines: Array[String], row: int, col: int) -> bool:
	var dirs := [Vector2(0,-1), Vector2(0,1), Vector2(-1,0), Vector2(1,0)]
	var open_dirs := []
	for d in dirs:
		var r := row + int(d.y)
		var c := col + int(d.x)
		if r >= 0 and r < lines.size() and c >= 0 and c < lines[r].length():
			if lines[r][c] != "#":
				open_dirs.append(d)
	if open_dirs.size() == 1:
		return true
	if open_dirs.size() == 2 and (
		(open_dirs[0].x == 0 and open_dirs[1].x == 0) or
		(open_dirs[0].y == 0 and open_dirs[1].y == 0)
	):
		return true
	return false

func _orient_corridor(instance: Node3D, lines: Array[String], row: int, col: int) -> void:
	var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	var open_dirs := []
	for d in dirs:
		var r := row + int(d.y)
		var c := col + int(d.x)
		if r >= 0 and r < lines.size() and c >= 0 and c < lines[r].length() and lines[r][c] != "#":
			open_dirs.append(d)

	var target_rot := 0.0

	if open_dirs.size() == 1:
		# Sackgasse – rotiere so, dass offene Seite zeigt nach vorne
		match open_dirs[0]:
			Vector2(0, -1): target_rot = 0
			Vector2(0, 1):  target_rot = PI
			Vector2(-1, 0): target_rot = -PI / 2
			Vector2(1, 0):  target_rot = PI / 2

	elif open_dirs.size() == 2:
		# Durchgang – horizontale oder vertikale Strecke
		if open_dirs[0].x == 0 and open_dirs[1].x == 0:
			target_rot = 0  # Nord-Süd
		elif open_dirs[0].y == 0 and open_dirs[1].y == 0:
			target_rot = PI / 2  # Ost-West

		# zufällige 180°-Drehung nur für Durchgänge
		if randf() < 0.5:
			target_rot += PI
			
	instance.rotation.y = target_rot

func _choose_weighted(scenes: Array[PackedScene], weights: Array[float]) -> PackedScene:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		push_error("Sum of weights must be > 0.")
		return scenes[0]
	var r := randf() * total
	var acc := 0.0
	for i in range(weights.size()):
		acc += weights[i]
		if r < acc:
			return scenes[i]
	return scenes[scenes.size() - 1]

func get_direction_to_target(from_position: Vector3) -> String:
	var delta := target_position - from_position
	var angle := atan2(-delta.x, delta.z)

	var directions := [
		"Nord", "Nordost", "Ost", "Südost",
		"Süd", "Südwest", "West", "Nordwest"
	]
	var index := int(round(angle / (PI / 4))) % 8
	if index < 0:
		index += 8
	return directions[index]

func get_distance_to_target(from_position: Vector3) -> float:
	return from_position.distance_to(target_position)

func create_map() -> String:
	var player_pos = Reference.player.global_position
	
	var map_lines := raw_map.duplicate()
	var px := int(round(player_pos.x / tile_size.x))
	var py := int(round(player_pos.z / tile_size.z))
	var tx := int(round(target_position.x / tile_size.x))
	var ty := int(round(target_position.z / tile_size.z))

	for row in range(map_lines.size()):
		var line = map_lines[row]
		var line_chars = line.split("")
		for col in range(line_chars.size()):
			match line_chars[col]:
				"N": line_chars[col] = " "
		if row == py:
			line_chars[px] = "S"
		if row == ty:
			line_chars[tx] = "T"
		map_lines[row] = "".join(line_chars)
	
	return "\n".join(map_lines)

func get_player_coords() -> Vector2i:
	var pos = Reference.player.global_position
	return Vector2i(
		int(round(pos.x / tile_size.x)),
		int(round(pos.z / tile_size.z))
	)

func get_target_coords() -> Vector2i:
	return Vector2i(
		int(round(target_position.x / tile_size.x)),
		int(round(target_position.z / tile_size.z))
	)
