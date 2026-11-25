class_name CorridorView
extends Control

## First-person pixel-art dungeon corridor renderer using sprites matching
## the user's prototype, plus dynamic side archway cutouts and accessible HUD badges.

const TEX_OPEN: Texture2D = preload("res://assets/Art/corridor_open.png")
const TEX_WALL: Texture2D = preload("res://assets/Art/corridor_wall.png")
const TEX_GOAL: Texture2D = preload("res://assets/Art/corridor_goal.png")
const TEX_MONSTER: Texture2D = preload("res://assets/Art/corridor_monster.png")

var maze: MazeData = null
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_timer: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if AccessibilityManager != null:
		AccessibilityManager.settings_changed.connect(queue_redraw)


func set_maze(maze_ref: MazeData) -> void:
	maze = maze_ref
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func trigger_bump_feedback() -> void:
	if AccessibilityManager != null and AccessibilityManager.reduced_motion:
		return
	_shake_timer = 0.18
	set_process(true)


func _process(delta: float) -> void:
	if _shake_timer <= 0.0:
		_shake_offset = Vector2.ZERO
		set_process(false)
		queue_redraw()
		return
	_shake_timer = maxf(0.0, _shake_timer - delta)
	var amp := 6.0 * (_shake_timer / 0.18)
	_shake_offset = Vector2(sin(_shake_timer * 75.0) * amp, 0.0)
	queue_redraw()


func _draw() -> void:
	var pal := AccessibilityManager.get_palette() if AccessibilityManager != null else {
		"bg": Color.BLACK,
		"border": Color.WHITE,
		"accent": Color(1.0, 0.48, 0.0),
		"text": Color.WHITE,
		"err": Color(1.0, 0.48, 0.48),
	}

	draw_rect(Rect2(Vector2.ZERO, size), pal["bg"])
	if maze == null:
		return

	var side: float = minf(size.x, size.y)
	var origin := Vector2(floorf((size.x - side) * 0.5), floorf((size.y - side) * 0.5)) + _shake_offset
	var view_rect := Rect2(origin, Vector2(side, side))

	var monster_los: int = maze.get_monster_line_of_sight_distance()
	var goal_los: int = maze.get_goal_line_of_sight_distance()
	var tex: Texture2D = TEX_WALL
	if monster_los > 0:
		tex = TEX_MONSTER
	elif goal_los > 0:
		tex = TEX_GOAL
	elif maze.is_open_relative(0):
		tex = TEX_OPEN

	draw_texture_rect(tex, view_rect, false)

	# Composite dark pixel-art side archway cutouts when left or right paths are open
	if maze.is_open_relative(3):
		_draw_side_passage(view_rect, true, pal)
	if maze.is_open_relative(1):
		_draw_side_passage(view_rect, false, pal)

	draw_rect(view_rect, pal["border"], false, 2.0)
	_draw_hud_badges(view_rect, pal, monster_los)


func _draw_side_passage(view_rect: Rect2, is_left: bool, pal: Dictionary) -> void:
	var o := view_rect.position
	var s := view_rect.size.x
	var void_col := Color(0.02, 0.03, 0.03, 0.96)
	var lintel_col := Color(0.14, 0.19, 0.18, 1.0)
	var edge_col: Color = pal["border"]

	if is_left:
		var poly := PackedVector2Array([
			o + Vector2(0.0, s * 0.16),
			o + Vector2(s * 0.18, s * 0.26),
			o + Vector2(s * 0.18, s * 0.74),
			o + Vector2(0.0, s * 0.84),
		])
		draw_colored_polygon(poly, void_col)
		draw_line(poly[0], poly[1], lintel_col, 4.0)
		draw_line(poly[1], poly[2], edge_col, 2.0)
		draw_line(poly[2], poly[3], lintel_col, 4.0)
	else:
		var poly := PackedVector2Array([
			o + Vector2(s, s * 0.16),
			o + Vector2(s * 0.82, s * 0.26),
			o + Vector2(s * 0.82, s * 0.74),
			o + Vector2(s, s * 0.84),
		])
		draw_colored_polygon(poly, void_col)
		draw_line(poly[0], poly[1], lintel_col, 4.0)
		draw_line(poly[1], poly[2], edge_col, 2.0)
		draw_line(poly[2], poly[3], lintel_col, 4.0)


func _draw_hud_badges(view_rect: Rect2, pal: Dictionary, monster_los: int) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var fsize := clampi(AccessibilityManager.get_scaled_font_size(12) if AccessibilityManager != null else 12, 11, 16)
	var o := view_rect.position
	var s := view_rect.size.x

	# Top-left compass + zone short badge
	var dir_txt := "%s · %s" % [MazeData.DIR_NAMES[maze.player_dir], maze.get_zone_name()]
	var box_w := minf(s - 20.0, maxf(120.0, float(dir_txt.length()) * float(fsize) * 0.60 + 16.0))
	var badge := Rect2(o + Vector2(8, 8), Vector2(box_w, float(fsize) + 12.0))
	draw_rect(badge, Color(0, 0, 0, 0.84))
	draw_rect(badge, pal["border"], false, 2.0)
	draw_string(font, badge.position + Vector2(8, float(fsize) + 2.0), dir_txt, HORIZONTAL_ALIGNMENT_LEFT, box_w - 12.0, fsize, pal["text"])

	# Top-right danger badge
	var danger := maze.get_danger_level()
	if danger >= 2 or monster_los > 0:
		var warn_txt := "⚠ Monstro (%d)" % monster_los if monster_los > 0 else "⚠ PERIGO"
		var wb_w := maxf(104.0, float(warn_txt.length()) * float(fsize) * 0.64 + 12.0)
		var warn_rect := Rect2(o + Vector2(s - wb_w - 8.0, 8), Vector2(wb_w, float(fsize) + 12.0))
		draw_rect(warn_rect, Color(0.28, 0.0, 0.0, 0.90))
		draw_rect(warn_rect, pal["err"], false, 2.0)
		draw_string(font, warn_rect.position + Vector2(8, float(fsize) + 2.0), warn_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, pal["err"])
