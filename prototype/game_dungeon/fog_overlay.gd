extends Node2D

var grid: Array = []
var visible_mask := {}
var explored_mask := {}
var tile_w := 64.0
var tile_h := 32.0

func configure(new_grid: Array, new_visible: Dictionary, new_explored: Dictionary) -> void:
	grid = new_grid
	visible_mask = new_visible
	explored_mask = new_explored
	queue_redraw()

func _iso(x: float, y: float) -> Vector2:
	return Vector2((x - y) * tile_w * 0.5, (x + y) * tile_h * 0.5)

func _draw() -> void:
	for y in grid.size():
		for x in (grid[y] as PackedInt32Array).size():
			var id := "%d,%d" % [x, y]
			if visible_mask.has(id):
				continue
			var alpha := 0.62 if explored_mask.has(id) else 0.98
			var center := _iso(x, y)
			var diamond := PackedVector2Array([center + Vector2(0, -tile_h * 0.5), center + Vector2(tile_w * 0.5, 0), center + Vector2(0, tile_h * 0.5), center + Vector2(-tile_w * 0.5, 0)])
			draw_colored_polygon(diamond, Color(0.015, 0.012, 0.025, alpha))
