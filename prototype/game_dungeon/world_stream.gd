extends RefCounted
## Deterministic 3x3-room chunk stream. Runtime rendering remains owned by main.gd.

const LevelGen := preload("res://level_gen.gd")

const ROOM_SIZE := 9
const CHUNK_ROOM_SIDE := 3
const CHUNK_TILE_SIDE := ROOM_SIZE * CHUNK_ROOM_SIDE
const REVEAL_THRESHOLD := 3
## Keep one traversable map resident. Generation and retirement are separate
## transitions so a newly generated map is never removed in the same tick.
const MAX_ACTIVE_CHUNKS := 1
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
# main.gd의 ACT_LEN과 동일한 값. 보스 여부를 floor_id/act에서 그때그때 다시
# 계산해(저장된 플래그에 의존하지 않고) 복원 시에도 동일한 청크가 재생성되게 한다.
const ACT_LEN := 3

var run_seed := 0
var floor_id := 1
var act := 1
var generation_epoch := 0
var next_sequence := 0
var active_chunks: Array[Dictionary] = []
var used_chunk_coords := {}
var retired_chunks: Array[Dictionary] = []

func setup(seed_value: int, new_floor_id: int, new_act: int, epoch: int = 0) -> void:
	run_seed = seed_value
	floor_id = new_floor_id
	act = new_act
	generation_epoch = epoch
	next_sequence = 0
	active_chunks.clear()
	used_chunk_coords.clear()
	retired_chunks.clear()
	_append_chunk(Vector2i.ZERO, Vector2i.LEFT, "west")

func _is_boss_floor() -> bool:
	return ((floor_id - 1) % ACT_LEN) + 1 == ACT_LEN

const TREASURE_CHANCE := 0.25

# 청크 자체의 시드로 독립적인 1회 판정을 내려 보물방 여부를 결정한다. LevelGen
# 내부 rng와는 별도 인스턴스라 생성 시퀀스를 건드리지 않고, 동일 시드이므로
# setup()/restore() 양쪽에서 항상 같은 결론을 낸다.
func _rolls_treasure(seed_val: int) -> bool:
	var roll_rng := RandomNumberGenerator.new()
	roll_rng.seed = seed_val
	return roll_rng.randf() < TREASURE_CHANCE

func frontier() -> Dictionary:
	return active_chunks.back() if not active_chunks.is_empty() else {}

func reveal_room(chunk_id: String, room: Vector2i) -> Dictionary:
	if room.x < 0 or room.x >= CHUNK_ROOM_SIDE or room.y < 0 or room.y >= CHUNK_ROOM_SIDE:
		return {}
	for chunk in active_chunks:
		if String(chunk["id"]) != chunk_id:
			continue
		var revealed: Dictionary = chunk["revealed_rooms"]
		revealed[_room_key(room)] = true
		if chunk != frontier() or bool(chunk.get("frontier_consumed", false)) or revealed.size() < REVEAL_THRESHOLD:
			return {}
		chunk["frontier_consumed"] = true
		return advance()
	return {}

func advance() -> Dictionary:
	if active_chunks.is_empty():
		return {}
	var previous: Dictionary = active_chunks.back()
	var direction := _choose_direction(previous)
	var next_coord: Vector2i = previous["coord"] + direction
	var rng := RandomNumberGenerator.new()
	rng.seed = _mixed_seed(next_sequence + 97)
	var gate_offset: int = int([4, 13, 22][rng.randi_range(0, 2)]) + rng.randi_range(-1, 1)
	previous["exit_direction"] = direction
	previous["gate_offset"] = gate_offset
	var added := _append_chunk(next_coord, -direction, _side_name(-direction))
	added["gate_offset"] = gate_offset
	return {"phase": "generate", "added": added, "retired": {}, "composite": compose_active_grid()}

func retire_farthest(reference_global: Vector2i = Vector2i(2147483647, 2147483647)) -> Dictionary:
	if active_chunks.size() <= MAX_ACTIVE_CHUNKS:
		return {}
	var retire_index := 0
	if reference_global != Vector2i(2147483647, 2147483647):
		var farthest_distance := -1.0
		for index in active_chunks.size():
			var chunk: Dictionary = active_chunks[index]
			var center := Vector2(chunk["coord"] * CHUNK_TILE_SIDE + Vector2i(CHUNK_TILE_SIDE / 2, CHUNK_TILE_SIDE / 2))
			var distance := center.distance_squared_to(Vector2(reference_global))
			if distance > farthest_distance:
				farthest_distance = distance
				retire_index = index
	var retired := _retire_at(retire_index)
	return {"phase": "retire", "added": {}, "retired": retired, "composite": compose_active_grid()}

func compose_active_grid() -> Dictionary:
	if active_chunks.is_empty():
		return {"grid": [], "w": 0, "h": 0, "grid_origin": Vector2i.ZERO, "chunk_rects": {}}
	var min_coord: Vector2i = active_chunks[0]["coord"]
	var max_coord: Vector2i = min_coord
	for chunk in active_chunks:
		var coord: Vector2i = chunk["coord"]
		min_coord.x = mini(min_coord.x, coord.x)
		min_coord.y = mini(min_coord.y, coord.y)
		max_coord.x = maxi(max_coord.x, coord.x)
		max_coord.y = maxi(max_coord.y, coord.y)
	var width := (max_coord.x - min_coord.x + 1) * CHUNK_TILE_SIDE
	var height := (max_coord.y - min_coord.y + 1) * CHUNK_TILE_SIDE
	var grid: Array = []
	for y in height:
		var row := PackedInt32Array()
		row.resize(width)
		grid.append(row)
	var rects := {}
	for chunk in active_chunks:
		var coord: Vector2i = chunk["coord"]
		var tile_origin := (coord - min_coord) * CHUNK_TILE_SIDE
		var source: Array = chunk["grid"]
		for y in CHUNK_TILE_SIDE:
			for x in CHUNK_TILE_SIDE:
				grid[tile_origin.y + y][tile_origin.x + x] = source[y][x]
		rects[String(chunk["id"])] = Rect2i(tile_origin, Vector2i(CHUNK_TILE_SIDE, CHUNK_TILE_SIDE))
	for index in range(active_chunks.size() - 1):
		_carve_connection(grid, active_chunks[index], active_chunks[index + 1], min_coord)
	var first: Dictionary = active_chunks.front()
	var last: Dictionary = active_chunks.back()
	var first_origin: Vector2i = (first["coord"] - min_coord) * CHUNK_TILE_SIDE
	var entrance: Vector2i = first_origin + Vector2i(first.get("entrance_cell", Vector2i(1, CHUNK_TILE_SIDE / 2)))
	var last_origin: Vector2i = (last["coord"] - min_coord) * CHUNK_TILE_SIDE
	var exit: Vector2i = last_origin + Vector2i(last.get("exit_cell", Vector2i(CHUNK_TILE_SIDE - 2, CHUNK_TILE_SIDE / 2)))
	var boss_anchor := Vector2i(-1, -1)
	var first_boss_anchor := Vector2i(first.get("boss_anchor", Vector2i(-1, -1)))
	if first_boss_anchor != Vector2i(-1, -1):
		boss_anchor = first_origin + first_boss_anchor
	# 보물방은 (보스 아레나와 달리) 어떤 청크에든 생길 수 있다. MAX_ACTIVE_CHUNKS가
	# 1이라 활성 청크는 항상 하나뿐이므로 "현재" 청크는 first==last다.
	var treasure_anchor := Vector2i(-1, -1)
	var last_treasure_anchor := Vector2i(last.get("treasure_anchor", Vector2i(-1, -1)))
	if last_treasure_anchor != Vector2i(-1, -1):
		treasure_anchor = last_origin + last_treasure_anchor
	return {
		"grid": grid, "w": width, "h": height,
		"grid_origin": min_coord * CHUNK_TILE_SIDE,
		"chunk_rects": rects, "entrance": entrance, "exit": exit, "boss_anchor": boss_anchor,
		"treasure_anchor": treasure_anchor,
		"rooms": active_chunks.size() * CHUNK_ROOM_SIDE * CHUNK_ROOM_SIDE,
		"map_type": String(last.get("map_type", "cinder_catacombs")),
		"theme": String(last.get("theme", "cinder")),
	}

func snapshot() -> Dictionary:
	var chunks: Array = []
	for chunk in active_chunks:
		chunks.append({
			"id": chunk["id"], "sequence": chunk["sequence"],
			"coord": [chunk["coord"].x, chunk["coord"].y],
			"seed": chunk["seed"], "generation_mode": chunk.get("generation_mode", LevelGen.MODE_RANDOM), "entry_side": chunk["entry_side"],
			"entrance_cell": [chunk.get("entrance_cell", Vector2i(1, CHUNK_TILE_SIDE / 2)).x, chunk.get("entrance_cell", Vector2i(1, CHUNK_TILE_SIDE / 2)).y],
			"exit_cell": [chunk.get("exit_cell", Vector2i(CHUNK_TILE_SIDE - 2, CHUNK_TILE_SIDE / 2)).x, chunk.get("exit_cell", Vector2i(CHUNK_TILE_SIDE - 2, CHUNK_TILE_SIDE / 2)).y],
			"entry_direction": [chunk["entry_direction"].x, chunk["entry_direction"].y],
			"exit_direction": [chunk["exit_direction"].x, chunk["exit_direction"].y],
			"gate_offset": chunk["gate_offset"],
			"revealed_rooms": chunk["revealed_rooms"].duplicate(true),
			"frontier_consumed": chunk["frontier_consumed"],
		})
	return {
		"run_seed": run_seed, "floor_id": floor_id, "act": act,
		"generation_epoch": generation_epoch, "next_sequence": next_sequence,
		"active_chunks": chunks, "used_chunk_coords": used_chunk_coords.keys(),
	}

func restore(raw: Dictionary) -> bool:
	var saved_chunks = raw.get("active_chunks", null)
	if not saved_chunks is Array or saved_chunks.is_empty() or saved_chunks.size() > MAX_ACTIVE_CHUNKS:
		return false
	run_seed = int(raw.get("run_seed", 0))
	floor_id = maxi(1, int(raw.get("floor_id", 1)))
	act = maxi(1, int(raw.get("act", 1)))
	generation_epoch = maxi(0, int(raw.get("generation_epoch", 0)))
	next_sequence = maxi(0, int(raw.get("next_sequence", saved_chunks.size())))
	active_chunks.clear()
	used_chunk_coords.clear()
	retired_chunks.clear()
	for raw_coord in raw.get("used_chunk_coords", []):
		used_chunk_coords[String(raw_coord)] = true
	for raw_chunk in saved_chunks:
		if not raw_chunk is Dictionary:
			return false
		var coord_values: Array = raw_chunk.get("coord", [])
		var entry_values: Array = raw_chunk.get("entry_direction", [])
		var exit_values: Array = raw_chunk.get("exit_direction", [])
		if coord_values.size() != 2 or exit_values.size() != 2:
			return false
		var coord := Vector2i(int(coord_values[0]), int(coord_values[1]))
		var entry_direction := _side_direction(String(raw_chunk.get("entry_side", "west")))
		if entry_values.size() == 2:
			entry_direction = Vector2i(int(entry_values[0]), int(entry_values[1]))
		var seed := int(raw_chunk.get("seed", 0))
		var mode := String(raw_chunk.get("generation_mode", LevelGen.MODE_RANDOM))
		var carve_boss := int(raw_chunk.get("sequence", 0)) == 0 and _is_boss_floor()
		var carve_treasure := not _is_boss_floor() and _rolls_treasure(seed)
		var level := LevelGen.generate_chunk(seed, act, mode, carve_boss, carve_treasure)
		var entrance_cell: Vector2i = level["entrance"]
		var exit_cell: Vector2i = level["exit"]
		var entrance_values: Array = raw_chunk.get("entrance_cell", [])
		var exit_cell_values: Array = raw_chunk.get("exit_cell", [])
		if entrance_values.size() == 2:
			entrance_cell = Vector2i(int(entrance_values[0]), int(entrance_values[1]))
		if exit_cell_values.size() == 2:
			exit_cell = Vector2i(int(exit_cell_values[0]), int(exit_cell_values[1]))
		var chunk := {
			"id": String(raw_chunk.get("id", "%d:%d:%d" % [floor_id, generation_epoch, int(raw_chunk.get("sequence", 0))])),
			"sequence": int(raw_chunk.get("sequence", 0)), "coord": coord, "seed": seed,
			"generation_mode": mode,
			"entrance_cell": entrance_cell, "exit_cell": exit_cell,
			"entry_direction": entry_direction, "entry_side": String(raw_chunk.get("entry_side", "west")),
			"exit_direction": Vector2i(int(exit_values[0]), int(exit_values[1])),
			"gate_offset": int(raw_chunk.get("gate_offset", CHUNK_TILE_SIDE / 2)),
			"revealed_rooms": (raw_chunk.get("revealed_rooms", {}) as Dictionary).duplicate(true),
			"frontier_consumed": bool(raw_chunk.get("frontier_consumed", false)),
			"grid": level["grid"], "map_type": level["map_type"], "theme": level["theme"],
			"boss_anchor": level.get("boss_anchor", Vector2i(-1, -1)),
			"treasure_anchor": level.get("treasure_anchor", Vector2i(-1, -1)),
		}
		active_chunks.append(chunk)
		used_chunk_coords[_coord_key(coord)] = true
	return not active_chunks.is_empty()

func _append_chunk(coord: Vector2i, entry_direction: Vector2i, entry_side: String) -> Dictionary:
	var sequence := next_sequence
	next_sequence += 1
	var seed := _mixed_seed(sequence)
	var modes := [LevelGen.MODE_STRAIGHT, LevelGen.MODE_RANDOM, LevelGen.MODE_BLOCKED_RANDOM]
	var mode: String = modes[posmod(sequence, modes.size())]
	# 보스 아레나는 층의 첫 청크(입구 청크)에만 둔다 — 출구가 보스 처치 전까지
	# 잠겨 있어 플레이어가 그 청크를 벗어나기 전에 보스와 마주치는 것이 보통이다.
	var carve_boss := sequence == 0 and _is_boss_floor()
	var carve_treasure := not _is_boss_floor() and _rolls_treasure(seed)
	var level := LevelGen.generate_chunk(seed, act, mode, carve_boss, carve_treasure)
	var chunk := {
		"id": "%d:%d:%d" % [floor_id, generation_epoch, sequence],
		"sequence": sequence, "coord": coord, "seed": seed,
		"generation_mode": mode,
		"entrance_cell": level["entrance"], "exit_cell": level["exit"],
		"entry_direction": entry_direction, "entry_side": entry_side,
		"exit_direction": Vector2i.ZERO, "gate_offset": CHUNK_TILE_SIDE / 2,
		"revealed_rooms": {}, "frontier_consumed": false,
		"grid": level["grid"], "map_type": level["map_type"], "theme": level["theme"],
		"boss_anchor": level.get("boss_anchor", Vector2i(-1, -1)),
		"treasure_anchor": level.get("treasure_anchor", Vector2i(-1, -1)),
	}
	active_chunks.append(chunk)
	used_chunk_coords[_coord_key(coord)] = true
	return chunk

func _retire_at(index: int) -> Dictionary:
	var chunk: Dictionary = active_chunks.pop_at(index)
	var summary := {
		"id": chunk["id"], "coord": chunk["coord"], "theme": chunk["theme"],
		"revealed_count": (chunk["revealed_rooms"] as Dictionary).size(),
	}
	retired_chunks.append(summary)
	return summary

func _choose_direction(previous: Dictionary) -> Vector2i:
	# A rotated square spiral varies all four wall directions and can extend
	# forever without enclosing the frontier or revisiting an old chunk.
	var direction := _spiral_direction(next_sequence)
	var rotation := posmod(run_seed + floor_id + generation_epoch, 4)
	for turn in rotation:
		direction = Vector2i(-direction.y, direction.x)
	if not used_chunk_coords.has(_coord_key(previous["coord"] + direction)):
		return direction
	# Corrupt/legacy snapshots may not follow the spiral. Prefer any unused
	# neighbour; never overlap an active chunk.
	for candidate in DIRECTIONS:
		if not used_chunk_coords.has(_coord_key(previous["coord"] + candidate)):
			return candidate
	for candidate in DIRECTIONS:
		if not _active_has_coord(previous["coord"] + candidate):
			return candidate
	return Vector2i.RIGHT

func _spiral_direction(step: int) -> Vector2i:
	var remaining := maxi(1, step)
	var length := 1
	var direction_index := 0
	while true:
		for pair in 2:
			if remaining <= length:
				return [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][direction_index % 4]
			remaining -= length
			direction_index += 1
		length += 1
	return Vector2i.RIGHT

func _active_has_coord(coord: Vector2i) -> bool:
	for chunk in active_chunks:
		if chunk["coord"] == coord:
			return true
	return false

func _carve_connection(grid: Array, from_chunk: Dictionary, to_chunk: Dictionary, min_coord: Vector2i) -> void:
	var direction: Vector2i = from_chunk["exit_direction"]
	if direction == Vector2i.ZERO or from_chunk["coord"] + direction != to_chunk["coord"]:
		return
	var from_origin: Vector2i = (from_chunk["coord"] - min_coord) * CHUNK_TILE_SIDE
	var to_origin: Vector2i = (to_chunk["coord"] - min_coord) * CHUNK_TILE_SIDE
	var offset := clampi(int(from_chunk["gate_offset"]), 2, CHUNK_TILE_SIDE - 3)
	for spread in [-1, 0, 1]:
		if direction == Vector2i.RIGHT:
			grid[from_origin.y + offset + spread][from_origin.x + CHUNK_TILE_SIDE - 1] = LevelGen.FLOOR
			grid[to_origin.y + offset + spread][to_origin.x] = LevelGen.FLOOR
		elif direction == Vector2i.LEFT:
			grid[from_origin.y + offset + spread][from_origin.x] = LevelGen.FLOOR
			grid[to_origin.y + offset + spread][to_origin.x + CHUNK_TILE_SIDE - 1] = LevelGen.FLOOR
		elif direction == Vector2i.DOWN:
			grid[from_origin.y + CHUNK_TILE_SIDE - 1][from_origin.x + offset + spread] = LevelGen.FLOOR
			grid[to_origin.y][to_origin.x + offset + spread] = LevelGen.FLOOR
		elif direction == Vector2i.UP:
			grid[from_origin.y][from_origin.x + offset + spread] = LevelGen.FLOOR
			grid[to_origin.y + CHUNK_TILE_SIDE - 1][to_origin.x + offset + spread] = LevelGen.FLOOR

func _mixed_seed(sequence: int) -> int:
	var value := int(run_seed) ^ int(floor_id * 73856093) ^ int(generation_epoch * 19349663) ^ int(sequence * 83492791)
	value = int((value ^ (value >> 16)) * 0x45d9f3b)
	value = int((value ^ (value >> 16)) * 0x45d9f3b)
	# JSON stores numbers as doubles. Keep procedural seeds below 2^31 so Web
	# save/load round-trips reproduce the exact same chunk layout.
	return int(absi(value ^ (value >> 16)) % 2147483647)

static func _coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

static func _room_key(room: Vector2i) -> String:
	return "%d,%d" % [room.x, room.y]

static func _side_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP: return "north"
	if direction == Vector2i.RIGHT: return "east"
	if direction == Vector2i.DOWN: return "south"
	if direction == Vector2i.LEFT: return "west"
	return ""

static func _side_direction(side: String) -> Vector2i:
	if side == "north": return Vector2i.UP
	if side == "east": return Vector2i.RIGHT
	if side == "south": return Vector2i.DOWN
	return Vector2i.LEFT

static func selftest() -> bool:
	var stream := preload("res://world_stream.gd").new()
	stream.setup(987654, 1, 1)
	if stream.active_chunks.size() != 1 or int(stream.compose_active_grid()["rooms"]) != 9 or stream.next_sequence != 1:
		return false
	for generation in 1:
		var front: Dictionary = stream.frontier()
		var result := {}
		for room_x in 3:
			result = stream.reveal_room(String(front["id"]), Vector2i(room_x, generation % 3))
		if result.is_empty():
			return false
	if stream.active_chunks.size() != 2 or stream.retired_chunks.size() != 0 or stream.next_sequence != 2:
		return false
	var composite := stream.compose_active_grid()
	if int(composite["rooms"]) != 18 or int(composite["w"]) * int(composite["h"]) > 54 * 54:
		return false
	var initial_trim := stream.retire_farthest()
	if initial_trim.is_empty() or stream.active_chunks.size() != MAX_ACTIVE_CHUNKS or stream.retired_chunks.size() != 1:
		return false
	if (composite["grid"] as Array).size() != int(composite["h"]):
		return false
	var long_stream := preload("res://world_stream.gd").new()
	long_stream.setup(246810, 2, 2)
	var long_treasure_seen := false
	for index in 100:
		var transition: Dictionary = long_stream.advance()
		if transition.is_empty():
			return false
		var long_composite: Dictionary = transition["composite"]
		if int(long_composite["w"]) * int(long_composite["h"]) > 81 * 81:
			return false
		if Vector2i(long_composite.get("treasure_anchor", Vector2i(-1, -1))) != Vector2i(-1, -1):
			long_treasure_seen = true
		if long_stream.active_chunks.size() > MAX_ACTIVE_CHUNKS:
			var trim_transition := long_stream.retire_farthest()
			if trim_transition.is_empty() or long_stream.active_chunks.size() != MAX_ACTIVE_CHUNKS:
				return false
	if long_stream.next_sequence != 101 or long_stream.used_chunk_coords.size() != 101 or long_stream.retired_chunks.size() != 100:
		return false
	var encoded := JSON.stringify(stream.snapshot())
	var decoded = JSON.parse_string(encoded)
	var restored := preload("res://world_stream.gd").new()
	if not decoded is Dictionary or not restored.restore(decoded):
		return false
	var sequence_ok: bool = restored.next_sequence == stream.next_sequence
	var active_ok: bool = restored.active_chunks.size() == stream.active_chunks.size()
	var used_ok: bool = restored.used_chunk_coords.size() == stream.used_chunk_coords.size()
	var grid_ok: bool = restored.compose_active_grid()["grid"] == stream.compose_active_grid()["grid"]
	if not (sequence_ok and active_ok and used_ok and grid_ok):
		return false
	# 보스 층(floor_id=3, act=1 -> level_in_act==ACT_LEN)은 입구 청크에 아레나가
	# 있어야 하고, floor_id로부터 재도출되므로 스냅샷/복원 후에도 동일해야 한다.
	var boss_stream := preload("res://world_stream.gd").new()
	boss_stream.setup(55667, 3, 1)
	var boss_composite := boss_stream.compose_active_grid()
	var boss_anchor_present: bool = Vector2i(boss_composite.get("boss_anchor", Vector2i(-1, -1))) != Vector2i(-1, -1)
	var boss_encoded := JSON.stringify(boss_stream.snapshot())
	var boss_decoded = JSON.parse_string(boss_encoded)
	var boss_restored := preload("res://world_stream.gd").new()
	if not boss_decoded is Dictionary or not boss_restored.restore(boss_decoded):
		return false
	var boss_restored_composite := boss_restored.compose_active_grid()
	var boss_anchor_matches: bool = Vector2i(boss_restored_composite.get("boss_anchor", Vector2i(-2, -2))) == Vector2i(boss_composite.get("boss_anchor", Vector2i(-1, -1)))
	var boss_grid_matches: bool = boss_restored_composite["grid"] == boss_composite["grid"]
	# 비보스 층(floor_id=1)은 아레나가 없어야 한다(회귀 방지).
	var non_boss_stream := preload("res://world_stream.gd").new()
	non_boss_stream.setup(55668, 1, 1)
	var non_boss_absent: bool = Vector2i(non_boss_stream.compose_active_grid().get("boss_anchor", Vector2i.ZERO)) == Vector2i(-1, -1)
	# 보물방은 비보스 층에서 100개 청크를 생성하면 25% 확률상 적어도 한 번은
	# 등장해야 하고, 보스 층 입구 청크에는 절대 생기지 않아야 한다.
	var boss_treasure_absent: bool = Vector2i(boss_composite.get("treasure_anchor", Vector2i.ZERO)) == Vector2i(-1, -1)
	return boss_anchor_present and boss_anchor_matches and boss_grid_matches and non_boss_absent and long_treasure_seen and boss_treasure_absent
