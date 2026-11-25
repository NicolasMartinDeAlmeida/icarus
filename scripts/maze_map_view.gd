class_name MazeMapView
extends Control

## Accessible 2D Labyrinth Map renderer.
## Uses distinct shapes + high-contrast outlines in addition to color
## so colorblind and low-vision players can read every element clearly.

var maze: MazeData = null


func _ready() -> void:
	if AccessibilityManager != null:
		AccessibilityManager.settings_changed.connect(queue_redraw)


func set_maze(maze_ref: MazeData) -> void:
	maze = maze_ref
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var pal := AccessibilityManager.get_palette() if AccessibilityManager != null else {
		"bg": Color.BLACK,
		"border": Color.WHITE,
		"accent": Color(1.0, 0.48, 0.0),
		"muted": Color(0.9, 0.8, 0.7),
		"err": Color(1.0, 0.48, 0.48),
		"ok": Color(0.5, 1.0, 0.6),
	}

	draw_rect(Rect2(Vector2.ZERO, size), pal["bg"])

	if maze == null or maze.width <= 0 or maze.height <= 0:
		return

	var pad: float = 8.0
	var avail_w: float = maxf(10.0, size.x - pad * 2.0)
	var avail_h: float = maxf(10.0, size.y - pad * 2.0)
	var cell: float = floorf(minf(avail_w / float(maze.width), avail_h / float(maze.height)))
	var grid_w: float = cell * float(maze.width)
	var grid_h: float = cell * float(maze.height)
	var origin := Vector2(floorf((size.x - grid_w) * 0.5), floorf((size.y - grid_h) * 0.5))

	var hc: bool = AccessibilityManager.high_contrast if AccessibilityManager != null else true
	var wall_fill := Color(0.14, 0.16, 0.20) if hc else Color(0.18, 0.22, 0.28)
	var wall_line := Color(0.65, 0.68, 0.72) if hc else Color(0.45, 0.50, 0.58)
	var floor_unvisited := Color(0.03, 0.03, 0.04) if hc else Color(0.06, 0.07, 0.10)
	var floor_visited := Color(0.10, 0.15, 0.13) if hc else Color(0.14, 0.22, 0.18)

	for y in range(maze.height):
		for x in range(maze.width):
			var pos := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(float(x) * cell, float(y) * cell), Vector2(cell, cell))

			if not maze.is_walkable(pos):
				draw_rect(rect, wall_fill)
				draw_rect(rect, wall_line, false, 1.5)
				# Subtle diagonal hatch so walls are distinguishable without relying on color
				draw_line(rect.position + Vector2(3, 3), rect.end - Vector2(3, 3), wall_line * Color(1, 1, 1, 0.35), 1.0)
			else:
				var is_vis: bool = maze.visited.has(pos)
				draw_rect(rect, floor_visited if is_vis else floor_unvisited)
				draw_rect(rect, Color(1, 1, 1, 0.10), false, 1.0)
				if is_vis and pos != maze.player_pos and pos != maze.goal_pos and pos != maze.monster_pos:
					draw_circle(rect.get_center(), maxf(2.0, cell * 0.09), pal["muted"])

	# Draw Goal (★ / golden diamond + cross)
	_draw_goal(origin, cell, pal)

	# Draw Monster (◆ + X + warning ring)
	_draw_monster(origin, cell, pal)

	# Draw Player (Directional arrow triangle with thick outline)
	_draw_player(origin, cell, pal)

	draw_rect(Rect2(origin, Vector2(grid_w, grid_h)), pal["border"], false, 2.0)


func _draw_goal(origin: Vector2, cell: float, pal: Dictionary) -> void:
	var c := origin + (Vector2(maze.goal_pos) + Vector2(0.5, 0.5)) * cell
	var r: float = cell * 0.34
	var pts := PackedVector2Array([
		c + Vector2(0, -r),
		c + Vector2(r, 0),
		c + Vector2(0, r),
		c + Vector2(-r, 0),
	])
	draw_colored_polygon(pts, Color(1.0, 0.84, 0.15))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), pal["bg"], 2.0)
	# Star cross inside so it stands out by shape
	draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, r * 0.55), pal["bg"], 2.0)
	draw_line(c + Vector2(r * 0.55, -r * 0.55), c + Vector2(-r * 0.55, r * 0.55), pal["bg"], 2.0)


func _draw_monster(origin: Vector2, cell: float, pal: Dictionary) -> void:
	var c := origin + (Vector2(maze.monster_pos) + Vector2(0.5, 0.5)) * cell
	var r: float = cell * 0.36
	draw_circle(c, r * 1.05, Color(1.0, 0.25, 0.25, 0.30))
	draw_arc(c, r * 1.05, 0.0, TAU, 20, pal["err"], 2.0)
	var pts := PackedVector2Array([
		c + Vector2(-r * 0.65, -r * 0.75),
		c + Vector2(0, -r * 0.35),
		c + Vector2(r * 0.65, -r * 0.75),
		c + Vector2(r * 0.65, r * 0.55),
		c + Vector2(0, r * 0.80),
		c + Vector2(-r * 0.65, r * 0.55),
	])
	draw_colored_polygon(pts, Color(0.92, 0.18, 0.18))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), Color.WHITE, 1.5)
	# Eyes
	draw_circle(c + Vector2(-r * 0.25, -r * 0.05), maxf(2.0, cell * 0.07), Color.WHITE)
	draw_circle(c + Vector2(r * 0.25, -r * 0.05), maxf(2.0, cell * 0.07), Color.WHITE)


func _draw_player(origin: Vector2, cell: float, pal: Dictionary) -> void:
	var c := origin + (Vector2(maze.player_pos) + Vector2(0.5, 0.5)) * cell
	var r: float = cell * 0.36
	var angle: float = 0.0
	match maze.player_dir:
		0:
			angle = -PI * 0.5
		1:
			angle = 0.0
		2:
			angle = PI * 0.5
		3:
			angle = PI

	var tip := c + Vector2(cos(angle), sin(angle)) * r
	var left_wing := c + Vector2(cos(angle + 2.35), sin(angle + 2.35)) * (r * 0.95)
	var notch := c - Vector2(cos(angle), sin(angle)) * (r * 0.35)
	var right_wing := c + Vector2(cos(angle - 2.35), sin(angle - 2.35)) * (r * 0.95)

	var poly := PackedVector2Array([tip, left_wing, notch, right_wing])
	draw_colored_polygon(poly, pal["accent"])
	draw_polyline(PackedVector2Array([tip, left_wing, notch, right_wing, tip]), Color.WHITE, 2.5)
