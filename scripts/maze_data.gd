class_name MazeData
extends RefCounted

## Turn-based labyrinth logic, BFS pathfinding for the monster & Ariadne's thread,
## human-friendly spatial orientation (landmarks, corridor depth, stereo pan),
## and structured audio descriptions (RPG-DU guidelines).

const GRID_ROWS: Array[String] = [
	"###########",
	"#S..#.....#",
	"#.#.#.###.#",
	"#.#...#...#",
	"#.#####.#.#",
	"#...#G..#.#",
	"###.#.###.#",
	"#...#...#.#",
	"#.#####.#.#",
	"#.......M.#",
	"###########",
]

# 0=Norte, 1=Leste, 2=Sul, 3=Oeste
const DIR_NAMES: Array[String] = ["Norte", "Leste", "Sul", "Oeste"]
const DIR_SHORT: Array[String] = ["N", "L", "S", "O"]
const DIR_VECTORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

const MONSTER_INTERVAL: int = 2

var width: int = 0
var height: int = 0
var player_pos: Vector2i = Vector2i(1, 1)
var player_dir: int = 1
var monster_pos: Vector2i = Vector2i(8, 9)
var goal_pos: Vector2i = Vector2i(5, 5)
var steps: int = 0
var monster_cooldown: int = MONSTER_INTERVAL
var visited: Dictionary = {}
var status: String = "playing" # "playing", "victory", "defeat"


func _init() -> void:
	height = GRID_ROWS.size()
	width = GRID_ROWS[0].length()
	reset()


func reset() -> void:
	steps = 0
	player_dir = 1
	monster_cooldown = MONSTER_INTERVAL
	status = "playing"
	visited.clear()

	for y in range(height):
		var row := GRID_ROWS[y]
		for x in range(width):
			var ch := row[x]
			if ch == "S":
				player_pos = Vector2i(x, y)
			elif ch == "G":
				goal_pos = Vector2i(x, y)
			elif ch == "M":
				monster_pos = Vector2i(x, y)

	_mark_surrounding_visited()


func _mark_surrounding_visited() -> void:
	visited[player_pos] = true
	for vec in DIR_VECTORS:
		var p: Vector2i = player_pos + vec
		if is_walkable(p):
			visited[p] = true


func cell_at(pos: Vector2i) -> String:
	if pos.y < 0 or pos.y >= height or pos.x < 0 or pos.x >= width:
		return "#"
	return GRID_ROWS[pos.y][pos.x]


func is_walkable(pos: Vector2i) -> bool:
	return cell_at(pos) != "#"


func rel_index(rel_dir: int) -> int:
	return posmod(player_dir + rel_dir, 4)


func cell_relative(rel_dir: int) -> String:
	var dir := rel_index(rel_dir)
	return cell_at(player_pos + DIR_VECTORS[dir])


func is_open_relative(rel_dir: int) -> bool:
	var dir := rel_index(rel_dir)
	return is_walkable(player_pos + DIR_VECTORS[dir])


func get_zone_name(pos: Vector2i = player_pos) -> String:
	if pos == goal_pos:
		return "Centro do Labirinto"
	if pos.x >= 5 and pos.x <= 7 and pos.y >= 5 and pos.y <= 7:
		return "Ante-câmara do Centro"
	if pos.x <= 3 and pos.y <= 2:
		return "Entrada do Labirinto"
	if pos.x >= 4 and pos.y <= 3:
		return "Corredor das Teias"
	if pos.x <= 3 and pos.y >= 3 and pos.y <= 7:
		return "Galeria Úmida"
	if pos.x >= 7 and pos.y >= 4 and pos.y <= 7:
		return "Salão dos Ecos"
	if pos.y >= 8:
		return "Passagem do Abismo"
	return "Corredor Central"


func get_corridor_depth_ahead() -> int:
	var fwd := DIR_VECTORS[player_dir]
	var dist := 0
	var p := player_pos + fwd
	while is_walkable(p):
		dist += 1
		p += fwd
	return dist


func get_intersection_label() -> String:
	var f := is_open_relative(0)
	var r := is_open_relative(1)
	var b := is_open_relative(2)
	var l := is_open_relative(3)
	var open_count := int(f) + int(r) + int(b) + int(l)

	if open_count <= 1:
		return "beco sem saída"
	if open_count == 4:
		return "encruzilhada"
	if open_count == 3:
		return "bifurcação"
	# Two exits
	if f and b:
		return "corredor reto"
	if l and not f:
		return "curva à esquerda"
	if r and not f:
		return "curva à direita"
	return "corredor em L"


func turn(delta: int) -> Dictionary:
	if status != "playing":
		return {"ok": false, "status": status}
	player_dir = posmod(player_dir + delta, 4)
	return {
		"ok": true,
		"dir_name": DIR_NAMES[player_dir],
		"monster_distance": get_monster_bfs_distance(),
		"monster_rel_dir": get_relative_direction_label(monster_pos),
		"danger_level": get_danger_level(),
		"status": status,
	}


func try_move_forward() -> Dictionary:
	if status != "playing":
		return {"ok": false, "hit_wall": false, "status": status}

	var next_pos := player_pos + DIR_VECTORS[player_dir]
	if not is_walkable(next_pos):
		# Error tolerance: bumping into a wall does NOT consume a turn or move the monster.
		return {
			"ok": false,
			"hit_wall": true,
			"monster_moved": false,
			"steps_until_monster_moves": monster_cooldown,
			"monster_distance": get_monster_bfs_distance(),
			"monster_rel_dir": get_relative_direction_label(monster_pos),
			"danger_level": get_danger_level(),
			"status": status,
		}

	player_pos = next_pos
	steps += 1
	_mark_surrounding_visited()

	if player_pos == goal_pos:
		status = "victory"
		return {
			"ok": true,
			"hit_wall": false,
			"monster_moved": false,
			"steps_until_monster_moves": monster_cooldown,
			"monster_distance": get_monster_bfs_distance(),
			"monster_rel_dir": get_relative_direction_label(monster_pos),
			"danger_level": get_danger_level(),
			"status": status,
		}

	if player_pos == monster_pos:
		status = "defeat"
		return {
			"ok": true,
			"hit_wall": false,
			"monster_moved": false,
			"steps_until_monster_moves": monster_cooldown,
			"monster_distance": 0,
			"monster_rel_dir": "aqui",
			"danger_level": 3,
			"status": status,
		}

	var monster_moved := false
	monster_cooldown -= 1
	if monster_cooldown <= 0:
		monster_cooldown = MONSTER_INTERVAL
		monster_moved = _move_monster_one_step()
		if monster_pos == player_pos:
			status = "defeat"

	return {
		"ok": true,
		"hit_wall": false,
		"monster_moved": monster_moved,
		"steps_until_monster_moves": monster_cooldown,
		"monster_distance": get_monster_bfs_distance(),
		"monster_rel_dir": get_relative_direction_label(monster_pos),
		"danger_level": get_danger_level(),
		"status": status,
	}


func _move_monster_one_step() -> bool:
	var path := _bfs_path(monster_pos, player_pos)
	if path.size() >= 2:
		monster_pos = path[1]
		return true
	return false


func _bfs_path(start: Vector2i, target: Vector2i, blocked: Vector2i = Vector2i(-1, -1)) -> Array[Vector2i]:
	if start == target:
		return [start]
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var head: int = 0

	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == target:
			break
		for vec in DIR_VECTORS:
			var nxt: Vector2i = cur + vec
			if not is_walkable(nxt):
				continue
			if nxt == blocked and nxt != target:
				continue
			if not came_from.has(nxt):
				came_from[nxt] = cur
				queue.append(nxt)

	if not came_from.has(target):
		return []

	var rev: Array[Vector2i] = []
	var node: Vector2i = target
	while node != start:
		rev.append(node)
		node = came_from[node]
	rev.append(start)
	rev.reverse()
	return rev


func get_bfs_distance(a: Vector2i, b: Vector2i) -> int:
	var path := _bfs_path(a, b)
	if path.is_empty():
		return -1
	return path.size() - 1


func get_monster_bfs_distance() -> int:
	return get_bfs_distance(player_pos, monster_pos)


func get_goal_bfs_distance() -> int:
	return get_bfs_distance(player_pos, goal_pos)


func get_monster_line_of_sight_distance() -> int:
	return _line_of_sight_distance(monster_pos)


func get_goal_line_of_sight_distance() -> int:
	return _line_of_sight_distance(goal_pos)


func _line_of_sight_distance(target: Vector2i) -> int:
	var fwd := DIR_VECTORS[player_dir]
	for dist in range(1, 4):
		var p := player_pos + fwd * dist
		if not is_walkable(p):
			return 0
		if p == target:
			return dist
	return 0


func get_danger_level() -> int:
	var d := get_monster_bfs_distance()
	if d < 0:
		return 0
	if d <= 1:
		return 3
	if d <= 3:
		return 2
	if d <= 6:
		return 1
	return 0


func get_relative_direction_label(target: Vector2i) -> String:
	var delta := target - player_pos
	if delta == Vector2i.ZERO:
		return "na sua posição"

	var fwd := DIR_VECTORS[player_dir]
	var right := DIR_VECTORS[rel_index(1)]
	var fwd_proj: int = delta.x * fwd.x + delta.y * fwd.y
	var right_proj: int = delta.x * right.x + delta.y * right.y

	if absi(fwd_proj) >= absi(right_proj):
		return "à sua frente" if fwd_proj > 0 else "atrás de você"
	return "à sua direita" if right_proj > 0 else "à sua esquerda"


func get_relative_pan(target: Vector2i) -> float:
	var delta := target - player_pos
	if delta == Vector2i.ZERO:
		return 0.0
	var right := DIR_VECTORS[rel_index(1)]
	var right_proj: int = delta.x * right.x + delta.y * right.y
	if right_proj > 0:
		return 0.85
	if right_proj < 0:
		return -0.85
	return 0.0


func get_monster_sensory_cue() -> String:
	var md := get_monster_bfs_distance()
	var mdir := get_relative_direction_label(monster_pos)
	var danger := get_danger_level()
	match danger:
		3:
			return "PERIGO! O monstro está a apenas 1 passo, %s!" % mdir
		2:
			return "Atenção! Passos e respiração do monstro muito perto, %s." % mdir
		1:
			return "Passos pesados ecoam %s, a média distância." % mdir
		_:
			if md >= 0:
				return "Tudo calmo por perto; o monstro está distante, %s." % mdir
			return "Tudo calmo ao redor."


func _get_body_turn_instruction(step_vec: Vector2i) -> String:
	if step_vec == DIR_VECTORS[player_dir]:
		return "siga em frente"
	if step_vec == DIR_VECTORS[rel_index(3)]:
		return "vire à esquerda e avance"
	if step_vec == DIR_VECTORS[rel_index(1)]:
		return "vire à direita e avance"
	return "faça meia-volta e avance"


func _describe_immediate_exits() -> String:
	var parts: Array[String] = []
	var ahead_depth := get_corridor_depth_ahead()
	if ahead_depth > 0:
		parts.append("livre à frente por %d passo%s" % [ahead_depth, "" if ahead_depth == 1 else "s"])
	else:
		parts.append("parede à frente")

	var has_l := is_open_relative(3)
	var has_r := is_open_relative(1)
	if has_l and has_r:
		parts.append("passagens abertas à esquerda e à direita")
	elif has_l:
		parts.append("passagem aberta à esquerda")
	elif has_r:
		parts.append("passagem aberta à direita")

	return ", ".join(parts) + "."


func get_step_speech(prev_zone: String = "") -> String:
	var parts: Array[String] = []
	var zone := get_zone_name()
	if not prev_zone.is_empty() and zone != prev_zone:
		parts.append("Entrou em: %s." % zone)

	var raw_shape := get_intersection_label()
	var shape := raw_shape.substr(0, 1).to_upper() + raw_shape.substr(1)
	parts.append("%s: %s" % [shape, _describe_immediate_exits()])

	var monster_los := get_monster_line_of_sight_distance()
	var goal_los := get_goal_line_of_sight_distance()
	if monster_los > 0:
		parts.append("Cuidado: o monstro está bem à sua frente!")
	elif goal_los > 0:
		parts.append("Luz dourada do centro brilha à sua frente!")
	elif get_danger_level() >= 1:
		parts.append(get_monster_sensory_cue())

	return " ".join(parts)


func get_ariadne_guidance() -> String:
	var zone := get_zone_name()
	var shape := get_intersection_label()
	var exits_txt := _describe_immediate_exits()

	# Prefer a safe route that avoids stepping on the monster tile when possible.
	var safe_path := _bfs_path(player_pos, goal_pos, monster_pos)
	var path := safe_path if not safe_path.is_empty() else _bfs_path(player_pos, goal_pos)

	var thread_txt := ""
	if path.size() >= 2:
		var next_step := path[1] - player_pos
		var action_hint := _get_body_turn_instruction(next_step)
		var remaining := path.size() - 1
		thread_txt = "O Fio de Ariadne puxa para o caminho certo: %s (faltam cerca de %d passos até o centro)." % [action_hint, remaining]
	else:
		thread_txt = "Você já está muito perto do centro."

	return "Você está em %s, em %s. %s %s %s" % [
		zone,
		shape,
		exits_txt.substr(0, 1).to_upper() + exits_txt.substr(1),
		thread_txt,
		get_monster_sensory_cue(),
	]


func get_scene_description() -> String:
	# Outside-in, top-to-bottom structured audio description (RPG-DU Diretrizes 34-36).
	var zone := get_zone_name()
	var left_desc := "passagem aberta" if is_open_relative(3) else "parede de pedra"
	var right_desc := "passagem aberta" if is_open_relative(1) else "parede de pedra"
	var ahead_depth := get_corridor_depth_ahead()

	var monster_los := get_monster_line_of_sight_distance()
	var goal_los := get_goal_line_of_sight_distance()
	var back_desc := ""
	if monster_los > 0:
		back_desc = "o monstro bloqueando o corredor a %d passo%s" % [monster_los, "" if monster_los == 1 else "s"]
	elif goal_los > 0:
		back_desc = "uma luz dourada, o centro do labirinto, a %d passo%s" % [goal_los, "" if goal_los == 1 else "s"]
	elif ahead_depth > 0:
		back_desc = "corredor escuro livre por %d passo%s" % [ahead_depth, "" if ahead_depth == 1 else "s"]
	else:
		back_desc = "parede de pedra, sem saída"

	var desc := "%s (%s). Teto de pedra com teias nos cantos. À esquerda: %s. À direita: %s. Ao fundo: %s. No chão, lajes úmidas." % [
		zone,
		get_intersection_label(),
		left_desc,
		right_desc,
		back_desc,
	]

	if get_danger_level() >= 1:
		desc += " " + get_monster_sensory_cue()

	return desc


func get_position_summary() -> String:
	return get_ariadne_guidance()


func get_map_summary() -> String:
	return get_ariadne_guidance()
