extends RefCounted
# 랜덤 던전 생성 (Part 2 §5): 프리셋 룸 슬롯 + 스패닝 트리 연결(문 = connectivity 매칭 근사).
# 시드 기반 → 매번 다른, 그러나 항상 완전 연결된 아이소 던전. preload로 사용.
# 반환: {w,h,grid(0=wall,1=floor),entrance:Vector2i,exit:Vector2i,rooms:int,doors:int}

const SLOTS := 9   # 9x9 room grid: 81 connected rooms
const ROOM := 9    # 9x9 tiles per room: 81x81 world
const LOOP_CHANCE := 0.22

const WALL := 0
const FLOOR := 1
const PILLAR := 2
const LOW_WALL := 3
const MODE_STRAIGHT := "straight"
const MODE_RANDOM := "random"
const MODE_BLOCKED_RANDOM := "blocked_random"

static func generate(seed_val: int, act: int = 1) -> Dictionary:
	return _generate_region(seed_val, act, SLOTS, MODE_RANDOM, false)

static func generate_chunk(seed_val: int, act: int = 1, mode: String = MODE_RANDOM, carve_boss_arena: bool = false) -> Dictionary:
	return _generate_region(seed_val, act, 3, mode, carve_boss_arena)

static func _generate_region(seed_val: int, act: int, slots: int, mode: String = MODE_RANDOM, carve_boss_arena: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var w := slots * ROOM
	var h := slots * ROOM

	var grid: Array = []
	for y in h:
		var row := PackedInt32Array()
		row.resize(w)  # 0 = wall
		grid.append(row)

	# 스패닝 트리(randomized DFS) — 모든 룸 슬롯을 연결 보장
	var visited := {}
	var edges: Array = []
	# Randomize the entrance room per seed so every regenerated floor can begin
	# from a different valid room while retaining deterministic replays.
	var start := Vector2i(rng.randi_range(0, slots - 1), rng.randi_range(0, slots - 1))
	visited[start] = true
	var stack: Array = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var neigh: Array = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < slots and n.y >= 0 and n.y < slots and not visited.has(n):
				neigh.append(n)
		if neigh.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = neigh[rng.randi_range(0, neigh.size() - 1)]
		visited[pick] = true
		edges.append([cur, pick])
		stack.append(pick)
	if mode == MODE_STRAIGHT:
		edges.clear()
		for sy in slots:
			var row_start := 0 if sy % 2 == 0 else slots - 1
			var row_step := 1 if sy % 2 == 0 else -1
			for offset in range(slots - 1):
				var sx := row_start + offset * row_step
				edges.append([Vector2i(sx, sy), Vector2i(sx + row_step, sy)])
			if sy < slots - 1:
				var end_x := row_start + (slots - 1) * row_step
				edges.append([Vector2i(end_x, sy), Vector2i(end_x, sy + 1)])

	# Add deterministic cross-links so layouts are not a single winding tree.
	# Scanning right/down considers every neighbour pair once and produces
	# alternate horizontal and vertical routes between rooms.
	var edge_keys := {}
	for edge in edges:
		edge_keys[_edge_key(edge[0], edge[1])] = true
	var loops := 0
	for sy in slots:
		for sx in slots:
			var room := Vector2i(sx, sy)
			for raw_direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var direction: Vector2i = raw_direction
				var neighbour: Vector2i = room + direction
				if neighbour.x >= slots or neighbour.y >= slots:
					continue
				var key := _edge_key(room, neighbour)
				if not edge_keys.has(key) and rng.randf() < LOOP_CHANCE:
					edges.append([room, neighbour])
					edge_keys[key] = true
					loops += 1

	for sy in slots:
		for sx in slots:
			_carve_room(grid, sx, sy)
			_apply_room_preset(grid, sx, sy, rng)
	for e in edges:
		_carve_door(grid, e[0], e[1], rng)
	var act_cycle := posmod(act - 1, 3) + 1
	var map_type := "cinder_catacombs"
	var theme := "cinder"
	if act_cycle == 2:
		map_type = "outdoor"
		theme = "sunken_wilds"
		for y in h:
			for x in w:
				if grid[y][x] == WALL: grid[y][x] = LOW_WALL
	var plains_pillar_cells: Array[Vector2i] = []
	if act_cycle == 3:
		map_type = "pillar_plains"
		theme = "storm_ossuary"
		for y in range(1, h - 1):
			for x in range(1, w - 1): grid[y][x] = FLOOR
		for i in slots * slots * 2:
			var px := rng.randi_range(2, w - 3)
			var py := rng.randi_range(2, h - 3)
			if Vector2(px, py).distance_to(Vector2(ROOM / 2, ROOM / 2)) > 3.0:
				grid[py][px] = PILLAR
				plains_pillar_cells.append(Vector2i(px, py))

	# 입구 = start 중심, 출구 = 트리 최심부 슬롯 중심
	# Choose the goal room independently from the entrance. The room graph is
	# connected by construction, so any distinct room remains reachable.
	var exit_slot := start
	while exit_slot == start:
		exit_slot = Vector2i(rng.randi_range(0, slots - 1), rng.randi_range(0, slots - 1))
	var path_distance := _slot_distance(edges, start, exit_slot)
	# pillar_plains은 테두리 없이 전역에 기둥을 흩뿌리므로 드물게 입구-출구
	# 경로를 끊을 수 있다 — blocked_random과 동일한 방식으로 복구한다.
	while (not _tile_path_exists(grid, _slot_center(start), _slot_center(exit_slot)) or not _all_room_centers_reachable(grid, slots, _slot_center(start))) and not plains_pillar_cells.is_empty():
		var plains_restore: Vector2i = plains_pillar_cells.pop_back()
		grid[plains_restore.y][plains_restore.x] = FLOOR
	if mode == MODE_BLOCKED_RANDOM:
		var blocked_cells: Array[Vector2i] = []
		for i in slots * slots:
			var bx := rng.randi_range(2, w - 3)
			var by := rng.randi_range(2, h - 3)
			var cell := Vector2i(bx, by)
			if cell == _slot_center(start) or cell == _slot_center(exit_slot):
				continue
			if grid[by][bx] == FLOOR and (bx + by) % 5 != 0:
				grid[by][bx] = PILLAR if i % 2 == 0 else LOW_WALL
				blocked_cells.append(cell)
		while (not _tile_path_exists(grid, _slot_center(start), _slot_center(exit_slot)) or not _all_room_centers_reachable(grid, slots, _slot_center(start))) and not blocked_cells.is_empty():
			var restore: Vector2i = blocked_cells.pop_back()
			grid[restore.y][restore.x] = FLOOR

	# 보스 전용 아레나: 중앙 슬롯과 상하좌우 인접 슬롯 사이 벽을 완전히 터서
	# 십자(+) 모양의 넓은 개활지를 만든다. 테마 장식(PILLAR/LOW_WALL)보다 뒤에
	# 실행해 어떤 액트·모드에서도 아레나 내부가 항상 깨끗한 FLOOR가 되게 한다.
	var boss_anchor := Vector2i(-1, -1)
	if carve_boss_arena:
		boss_anchor = _carve_boss_arena(grid, slots)

	return {
		"w": w, "h": h, "grid": grid,
		"entrance": _slot_center(start), "exit": _slot_center(exit_slot),
		"rooms": slots * slots, "doors": edges.size(), "loops": loops,
		"critical_path_rooms": path_distance,
		"map_type": map_type, "theme": theme, "act": act,
		"generation_mode": mode, "boss_anchor": boss_anchor,
	}

static func selftest() -> bool:
	var dungeon := generate(1000, 1)
	var outdoor := generate(1001, 2)
	var plains := generate(1002, 3)
	var chunk := generate_chunk(2000, 1)
	var straight := generate_chunk(2001, 1, MODE_STRAIGHT)
	var blocked := generate_chunk(2002, 1, MODE_BLOCKED_RANDOM)
	var another_seed := generate(3000, 1)
	var entrance_a: Vector2i = dungeon["entrance"]
	var entrance_b: Vector2i = another_seed["entrance"]
	var endpoints_valid: bool = dungeon["entrance"] != dungeon["exit"] and another_seed["entrance"] != another_seed["exit"]
	var randomized_start: bool = entrance_a != entrance_b
	var blocked_path: bool = _tile_path_exists(blocked["grid"], blocked["entrance"], blocked["exit"])
	# 보스 아레나: 3개 액트 테마 + blocked_random 모드에서 모두 중앙+인접 4룸이
	# PILLAR/LOW_WALL 없이 깨끗하고 boss_anchor가 유효한지 검증.
	var boss_cinder := generate_chunk(2100, 1, MODE_RANDOM, true)
	var boss_outdoor := generate_chunk(2101, 2, MODE_RANDOM, true)
	var boss_plains := generate_chunk(2102, 3, MODE_RANDOM, true)
	var boss_blocked := generate_chunk(2103, 1, MODE_BLOCKED_RANDOM, true)
	var boss_anchor_ok := Vector2i(chunk.get("boss_anchor", Vector2i.ZERO)) == Vector2i(-1, -1)
	var arena_clean := true
	for boss_level in [boss_cinder, boss_outdoor, boss_plains, boss_blocked]:
		if Vector2i(boss_level.get("boss_anchor", Vector2i(-1, -1))) == Vector2i(-1, -1):
			arena_clean = false
		if _arena_obstacle_count(boss_level["grid"]) > 0:
			arena_clean = false
		if not _tile_path_exists(boss_level["grid"], boss_level["entrance"], boss_level["exit"]):
			arena_clean = false
	# 프리셋 룸 다양화: 여러 시드에서 전부 연결성이 유지되는지, 그리고 실제로
	# PILLAR 장식이 등장하는지(act1은 테마 자체가 장애물을 추가하지 않으므로
	# 발견되면 전부 프리셋 기여분) 확인.
	var preset_connectivity_ok := true
	var preset_pillar_seen := false
	for preset_seed in [5001, 5002, 5003, 5004, 5005, 5006]:
		var sample := generate_chunk(preset_seed, 1, MODE_RANDOM)
		if not _tile_path_exists(sample["grid"], sample["entrance"], sample["exit"]):
			preset_connectivity_ok = false
		if not _all_room_centers_reachable(sample["grid"], 3, sample["entrance"]):
			preset_connectivity_ok = false
		if _count_tile(sample["grid"], PILLAR) > 0:
			preset_pillar_seen = true
	# pillar_plains(act3)의 전역 기둥 산포는 자체 복구 루프를 갖기 전까지
	# 입구-출구 경로를 끊을 수 있었다 — 여러 시드로 회귀를 감시한다.
	var plains_connectivity_ok := true
	for plains_seed in [6001, 6002, 6003, 6004, 6005, 6006]:
		var plains_sample := generate_chunk(plains_seed, 3, MODE_RANDOM)
		if not _tile_path_exists(plains_sample["grid"], plains_sample["entrance"], plains_sample["exit"]):
			plains_connectivity_ok = false
		if not _all_room_centers_reachable(plains_sample["grid"], 3, plains_sample["entrance"]):
			plains_connectivity_ok = false
	return int(dungeon.get("rooms", 0)) == 81 and int(dungeon.get("doors", 0)) >= 80 and int(dungeon.get("loops", 0)) > 0 and int(chunk.get("rooms", 0)) == 9 and int(chunk.get("w", 0)) == 27 and int(chunk.get("h", 0)) == 27 and String(dungeon.get("map_type", "")) == "cinder_catacombs" and String(outdoor.get("map_type", "")) == "outdoor" and String(plains.get("map_type", "")) == "pillar_plains" and _count_tile(outdoor["grid"], LOW_WALL) > 0 and _count_tile(plains["grid"], PILLAR) > 0 and String(straight.get("generation_mode", "")) == MODE_STRAIGHT and String(blocked.get("generation_mode", "")) == MODE_BLOCKED_RANDOM and (_count_tile(blocked["grid"], PILLAR) + _count_tile(blocked["grid"], LOW_WALL)) > 0 and endpoints_valid and randomized_start and blocked_path and boss_anchor_ok and arena_clean and preset_connectivity_ok and preset_pillar_seen and plains_connectivity_ok

# 3x3 청크의 중앙 슬롯(1,1)과 그 4개 인접 슬롯 내부에 남은 PILLAR/LOW_WALL 수.
# _carve_boss_arena가 올바르게 비웠다면 0이어야 한다.
static func _arena_obstacle_count(grid: Array) -> int:
	var center := Vector2i(1, 1)
	var slots: Array[Vector2i] = [center, center + Vector2i.UP, center + Vector2i.RIGHT, center + Vector2i.DOWN, center + Vector2i.LEFT]
	var count := 0
	for slot in slots:
		var ox := slot.x * ROOM
		var oy := slot.y * ROOM
		for y in range(1, ROOM - 1):
			for x in range(1, ROOM - 1):
				var v := int(grid[oy + y][ox + x])
				if v == PILLAR or v == LOW_WALL:
					count += 1
	return count

static func _count_tile(grid: Array, tile: int) -> int:
	var count := 0
	for row in grid:
		for value in row:
			if int(value) == tile: count += 1
	return count

static func _tile_path_exists(grid: Array, start: Vector2i, target: Vector2i) -> bool:
	if grid.is_empty():
		return false
	var height := grid.size()
	var width := (grid[0] as PackedInt32Array).size()
	if start.x < 0 or start.y < 0 or target.x < 0 or target.y < 0 or start.x >= width or target.x >= width or start.y >= height or target.y >= height:
		return false
	if int(grid[start.y][start.x]) != FLOOR or int(grid[target.y][target.x]) != FLOOR:
		return false
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == target:
			return true
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height or seen.has(next):
				continue
			if int(grid[next.y][next.x]) != FLOOR:
				continue
			seen[next] = true
			queue.append(next)
	return false

static func _all_room_centers_reachable(grid: Array, slots: int, start: Vector2i) -> bool:
	for sy in slots:
		for sx in slots:
			if not _tile_path_exists(grid, start, _slot_center(Vector2i(sx, sy))):
				return false
	return true

static func _slot_center(s: Vector2i) -> Vector2i:
	return Vector2i(s.x * ROOM + ROOM / 2, s.y * ROOM + ROOM / 2)

static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.y < b.y or (a.y == b.y and a.x < b.x):
		return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d:%d,%d" % [b.x, b.y, a.x, a.y]

static func _farthest_slot(edges: Array, start: Vector2i) -> Dictionary:
	var adjacency := {}
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		if not adjacency.has(a): adjacency[a] = []
		if not adjacency.has(b): adjacency[b] = []
		adjacency[a].append(b)
		adjacency[b].append(a)
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var farthest := start
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for raw_next in adjacency.get(current, []):
			var next: Vector2i = raw_next
			if distances.has(next): continue
			distances[next] = int(distances[current]) + 1
			queue.append(next)
			if int(distances[next]) > int(distances[farthest]):
				farthest = next
	return {"slot": farthest, "distance": int(distances[farthest])}

static func _slot_distance(edges: Array, start: Vector2i, target: Vector2i) -> int:
	if start == target:
		return 0
	var adjacency := {}
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		if not adjacency.has(a): adjacency[a] = []
		if not adjacency.has(b): adjacency[b] = []
		adjacency[a].append(b)
		adjacency[b].append(a)
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for raw_next in adjacency.get(current, []):
			var next: Vector2i = raw_next
			if distances.has(next):
				continue
			distances[next] = int(distances[current]) + 1
			if next == target:
				return int(distances[next])
			queue.append(next)
	return -1

static func _carve_boss_arena(grid: Array, slots: int) -> Vector2i:
	var center := Vector2i(slots / 2, slots / 2)
	_open_room_interior(grid, center)
	for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var neighbour: Vector2i = center + d
		if neighbour.x < 0 or neighbour.x >= slots or neighbour.y < 0 or neighbour.y >= slots:
			continue
		_open_room_interior(grid, neighbour)
		_open_full_wall(grid, center, neighbour)
	return _slot_center(center)

# 룸 내부를 FLOOR로 재설정해 테마 장식(PILLAR/LOW_WALL)을 아레나 범위에서 제거한다.
static func _open_room_interior(grid: Array, slot: Vector2i) -> void:
	var ox := slot.x * ROOM
	var oy := slot.y * ROOM
	for y in range(1, ROOM - 1):
		for x in range(1, ROOM - 1):
			grid[oy + y][ox + x] = FLOOR

# 인접 슬롯 사이 경계 전체를 열어 두 룸을 하나의 개활지로 합친다(_carve_door의
# 3타일 문과 달리 내부 전체 폭을 연다).
static func _open_full_wall(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var ax := a.x * ROOM
	var ay := a.y * ROOM
	var bx := b.x * ROOM
	var by := b.y * ROOM
	if b.x == a.x + 1:
		for dy in range(1, ROOM - 1):
			grid[ay + dy][ax + ROOM - 1] = FLOOR
			grid[by + dy][bx] = FLOOR
	elif b.x == a.x - 1:
		for dy in range(1, ROOM - 1):
			grid[ay + dy][ax] = FLOOR
			grid[by + dy][bx + ROOM - 1] = FLOOR
	elif b.y == a.y + 1:
		for dx in range(1, ROOM - 1):
			grid[ay + ROOM - 1][ax + dx] = FLOOR
			grid[by][bx + dx] = FLOOR
	elif b.y == a.y - 1:
		for dx in range(1, ROOM - 1):
			grid[ay][ax + dx] = FLOOR
			grid[by + ROOM - 1][bx + dx] = FLOOR

# 프리셋 룸 다양화: 룸 내부 안쪽 5x5(테두리 1칸 통로는 항상 비워 둠)에
# 작가가 설계한 기둥 배치를 확률적으로 얹는다. 중심(4,4)의 4방향 이웃과
# 바깥 테두리(1,1~7,7의 1·7행/열)는 항상 비어 있으므로 문 위치·연결성과
# 무관하게 항상 우회로가 존재한다 — act3(필러 평원)처럼 룸 내부를 통째로
# 다시 까는 테마가 이후 단계에서 덮어써도 안전하다.
static func _apply_room_preset(grid: Array, sx: int, sy: int, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	var ox := sx * ROOM
	var oy := sy * ROOM
	if roll < 0.25:
		for p in [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6)]:
			grid[oy + p.y][ox + p.x] = PILLAR
	elif roll < 0.5:
		for p in [Vector2i(4, 2), Vector2i(4, 6), Vector2i(2, 4), Vector2i(6, 4)]:
			grid[oy + p.y][ox + p.x] = PILLAR

static func _carve_room(grid: Array, sx: int, sy: int) -> void:
	var ox := sx * ROOM
	var oy := sy * ROOM
	for y in range(1, ROOM - 1):
		for x in range(1, ROOM - 1):
			grid[oy + y][ox + x] = 1  # 내부 바닥, 테두리는 벽

static func _carve_door(grid: Array, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var ax := a.x * ROOM
	var ay := a.y * ROOM
	var bx := b.x * ROOM
	var by := b.y * ROOM
	# Offset each doorway along its shared wall to avoid repeated centre-only
	# connections while retaining a three-tile-wide mobile-friendly opening.
	var m := ROOM / 2 + rng.randi_range(-2, 2)
	if b.x == a.x + 1:
		for dy in [-1, 0, 1]:
			grid[ay + m + dy][ax + ROOM - 1] = 1
			grid[by + m + dy][bx] = 1
	elif b.x == a.x - 1:
		for dy in [-1, 0, 1]:
			grid[ay + m + dy][ax] = 1
			grid[by + m + dy][bx + ROOM - 1] = 1
	elif b.y == a.y + 1:
		for dx in [-1, 0, 1]:
			grid[ay + ROOM - 1][ax + m + dx] = 1
			grid[by][bx + m + dx] = 1
	elif b.y == a.y - 1:
		for dx in [-1, 0, 1]:
			grid[ay][ax + m + dx] = 1
			grid[by + ROOM - 1][bx + m + dx] = 1
