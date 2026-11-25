extends Control

## Draws the Greek meander frieze border using the active accessibility palette.

func _ready() -> void:
	if AccessibilityManager != null:
		AccessibilityManager.settings_changed.connect(queue_redraw)


func _draw() -> void:
	var pal := AccessibilityManager.get_palette() if AccessibilityManager != null else {
		"bg": Color.BLACK,
		"frieze": Color(0.45, 0.5, 1.0, 1.0),
	}
	var bg: Color = pal["bg"]
	var fg: Color = pal["frieze"]

	draw_rect(Rect2(Vector2.ZERO, size), bg)

	var cell: float = 4.0
	var tile_w: float = 32.0
	var cols: int = ceili(size.x / tile_w)
	var rows_offset: float = floorf((size.y - 20.0) * 0.5)

	for i in range(cols):
		var ox: float = float(i) * tile_w
		# Outer top bar & meander motif (Greek key)
		draw_rect(Rect2(ox, rows_offset, tile_w, cell), fg)
		draw_rect(Rect2(ox, rows_offset, cell, cell * 4.0), fg)
		draw_rect(Rect2(ox, rows_offset + cell * 3.0, cell * 5.0, cell), fg)
		draw_rect(Rect2(ox + cell * 4.0, rows_offset + cell, cell, cell * 3.0), fg)
		draw_rect(Rect2(ox + cell * 2.0, rows_offset + cell, cell * 3.0, cell), fg)
		draw_rect(Rect2(ox + cell * 2.0, rows_offset + cell, cell, cell * 2.0), fg)
		draw_rect(Rect2(ox + cell * 6.0, rows_offset, cell, cell * 4.0), fg)
		draw_rect(Rect2(ox + cell * 6.0, rows_offset + cell * 3.0, cell * 2.0, cell), fg)

	draw_rect(Rect2(0.0, size.y - 3.0, size.x, 3.0), fg)
