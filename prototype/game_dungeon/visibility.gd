extends RefCounted

static func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func in_bounds(grid: Array, cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < grid.size() and cell.x >= 0 and cell.x < (grid[cell.y] as PackedInt32Array).size()

static func is_clear(grid: Array, from: Vector2, to: Vector2, include_target: bool = false) -> bool:
	var delta := to - from
	var steps := maxi(1, int(ceil(maxf(absf(delta.x), absf(delta.y)) * 5.0)))
	var previous := Vector2i(roundi(from.x), roundi(from.y))
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / float(steps))
		var cell := Vector2i(roundi(point.x), roundi(point.y))
		if not in_bounds(grid, cell):
			return false
		if cell != previous and cell.x != previous.x and cell.y != previous.y:
			var side_a := Vector2i(cell.x, previous.y)
			var side_b := Vector2i(previous.x, cell.y)
			if in_bounds(grid, side_a) and in_bounds(grid, side_b) and int(grid[side_a.y][side_a.x]) != 1 and int(grid[side_b.y][side_b.x]) != 1:
				return false
		var is_target := i == steps
		if int(grid[cell.y][cell.x]) != 1 and (include_target or not is_target):
			return false
		previous = cell
	return true

static func is_arc_clear(grid: Array, from: Vector2, to: Vector2) -> bool:
	var delta := to - from
	var steps := maxi(1, int(ceil(maxf(absf(delta.x), absf(delta.y)) * 5.0)))
	for i in range(1, steps):
		var point := from.lerp(to, float(i) / float(steps))
		var cell := Vector2i(roundi(point.x), roundi(point.y))
		if not in_bounds(grid, cell) or int(grid[cell.y][cell.x]) in [0, 2]: return false
	return true

static func visible_cells(grid: Array, origin: Vector2, radius: int) -> Dictionary:
	var out := {}
	var center := Vector2i(roundi(origin.x), roundi(origin.y))
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if not in_bounds(grid, cell) or Vector2(x, y).distance_to(origin) > float(radius):
				continue
			if is_clear(grid, origin, Vector2(x, y), false):
				out[key(cell)] = true
	return out

static func selftest() -> bool:
	var grid: Array = []
	for y in 7:
		var row := PackedInt32Array()
		for x in 7: row.append(1)
		grid.append(row)
	grid[3][3] = 0
	var blocked := not is_clear(grid, Vector2(1, 3), Vector2(5, 3))
	var open := is_clear(grid, Vector2(1, 2), Vector2(5, 2))
	grid[2][3] = 0
	var corner := not is_clear(grid, Vector2(2, 2), Vector2(4, 4))
	var visible := visible_cells(grid, Vector2(1, 3), 6)
	grid[3][3] = 3
	var low_wall_blocks_direct := not is_clear(grid, Vector2(1, 3), Vector2(5, 3))
	var low_wall_allows_arc := is_arc_clear(grid, Vector2(1, 3), Vector2(5, 3))
	grid[3][3] = 2
	var pillar_blocks_arc := not is_arc_clear(grid, Vector2(1, 3), Vector2(5, 3))
	return blocked and open and corner and visible.has("1,3") and not visible.has("5,3") and low_wall_blocks_direct and low_wall_allows_arc and pillar_blocks_arc
