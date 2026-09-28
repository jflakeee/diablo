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

static func generate(seed_val: int, act: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var w := SLOTS * ROOM
	var h := SLOTS * ROOM

	var grid: Array = []
	for y in h:
		var row := PackedInt32Array()
		row.resize(w)  # 0 = wall
		grid.append(row)

	# 스패닝 트리(randomized DFS) — 모든 룸 슬롯을 연결 보장
	var visited := {}
	var edges: Array = []
	var depth := {}
	var start := Vector2i(0, 0)
	visited[start] = true
	depth[start] = 0
	var stack: Array = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var neigh: Array = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < SLOTS and n.y >= 0 and n.y < SLOTS and not visited.has(n):
				neigh.append(n)
		if neigh.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = neigh[rng.randi_range(0, neigh.size() - 1)]
		visited[pick] = true
		depth[pick] = int(depth[cur]) + 1
		edges.append([cur, pick])
		stack.append(pick)

	# Add deterministic cross-links so layouts are not a single winding tree.
	# Scanning right/down considers every neighbour pair once and produces
	# alternate horizontal and vertical routes between rooms.
	var edge_keys := {}
	for edge in edges:
		edge_keys[_edge_key(edge[0], edge[1])] = true
	var loops := 0
	for sy in SLOTS:
		for sx in SLOTS:
			var room := Vector2i(sx, sy)
			for raw_direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var direction: Vector2i = raw_direction
				var neighbour: Vector2i = room + direction
				if neighbour.x >= SLOTS or neighbour.y >= SLOTS:
					continue
				var key := _edge_key(room, neighbour)
				if not edge_keys.has(key) and rng.randf() < LOOP_CHANCE:
					edges.append([room, neighbour])
					edge_keys[key] = true
					loops += 1

	for sy in SLOTS:
		for sx in SLOTS:
			_carve_room(grid, sx, sy)
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
	elif act_cycle == 3:
		map_type = "pillar_plains"
		theme = "storm_ossuary"
		for y in range(1, h - 1):
			for x in range(1, w - 1): grid[y][x] = FLOOR
		for i in SLOTS * SLOTS * 2:
			var px := rng.randi_range(2, w - 3)
			var py := rng.randi_range(2, h - 3)
			if Vector2(px, py).distance_to(Vector2(ROOM / 2, ROOM / 2)) > 3.0: grid[py][px] = PILLAR

	# 입구 = start 중심, 출구 = 트리 최심부 슬롯 중심
	var exit_slot := start
	var maxd := -1
	for s in depth:
		if int(depth[s]) > maxd:
			maxd = int(depth[s])
			exit_slot = s

	return {
		"w": w, "h": h, "grid": grid,
		"entrance": _slot_center(start), "exit": _slot_center(exit_slot),
		"rooms": SLOTS * SLOTS, "doors": edges.size(), "loops": loops,
		"map_type": map_type, "theme": theme, "act": act,
	}

static func selftest() -> bool:
	var dungeon := generate(1000, 1)
	var outdoor := generate(1001, 2)
	var plains := generate(1002, 3)
	return int(dungeon.get("rooms", 0)) == 81 and int(dungeon.get("doors", 0)) >= 80 and int(dungeon.get("loops", 0)) > 0 and String(dungeon.get("map_type", "")) == "cinder_catacombs" and String(outdoor.get("map_type", "")) == "outdoor" and String(plains.get("map_type", "")) == "pillar_plains" and _count_tile(outdoor["grid"], LOW_WALL) > 0 and _count_tile(plains["grid"], PILLAR) > 0

static func _count_tile(grid: Array, tile: int) -> int:
	var count := 0
	for row in grid:
		for value in row:
			if int(value) == tile: count += 1
	return count

static func _slot_center(s: Vector2i) -> Vector2i:
	return Vector2i(s.x * ROOM + ROOM / 2, s.y * ROOM + ROOM / 2)

static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.y < b.y or (a.y == b.y and a.x < b.x):
		return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d:%d,%d" % [b.x, b.y, a.x, a.y]

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
