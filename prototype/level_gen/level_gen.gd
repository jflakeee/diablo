extends RefCounted
# 랜덤 던전 생성 (Part 2 §5): 프리셋 룸 슬롯 + 스패닝 트리 연결(문 = connectivity 매칭 근사).
# 시드 기반 → 매번 다른, 그러나 항상 완전 연결된 아이소 던전. preload로 사용.
# 반환: {w,h,grid(0=wall,1=floor),entrance:Vector2i,exit:Vector2i,rooms:int,doors:int}

const SLOTS := 5   # 5x5 룸 슬롯
const ROOM := 9    # 룸당 9x9 타일 → 맵 45x45

static func generate(seed_val: int) -> Dictionary:
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

	for sy in SLOTS:
		for sx in SLOTS:
			_carve_room(grid, sx, sy)
	for e in edges:
		_carve_door(grid, e[0], e[1])

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
		"rooms": SLOTS * SLOTS, "doors": edges.size(),
	}

static func _slot_center(s: Vector2i) -> Vector2i:
	return Vector2i(s.x * ROOM + ROOM / 2, s.y * ROOM + ROOM / 2)

static func _carve_room(grid: Array, sx: int, sy: int) -> void:
	var ox := sx * ROOM
	var oy := sy * ROOM
	for y in range(1, ROOM - 1):
		for x in range(1, ROOM - 1):
			grid[oy + y][ox + x] = 1  # 내부 바닥, 테두리는 벽

static func _carve_door(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var ax := a.x * ROOM
	var ay := a.y * ROOM
	var bx := b.x * ROOM
	var by := b.y * ROOM
	var m := ROOM / 2
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
