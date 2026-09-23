extends RefCounted

static func new_state() -> Dictionary:
	return {"unlocked": {}, "current": ""}

static func normalize_state(definitions: Array, saved: Dictionary) -> Dictionary:
	var state := new_state()
	var valid_ids := {}
	for raw in definitions:
		valid_ids[String((raw as Dictionary).get("id", ""))] = true
	var saved_unlocked: Dictionary = saved.get("unlocked", {})
	for id in saved_unlocked:
		if valid_ids.has(String(id)) and bool(saved_unlocked[id]):
			state["unlocked"][String(id)] = true
	var current := String(saved.get("current", ""))
	if state["unlocked"].has(current):
		state["current"] = current
	return state

static func find_at(definitions: Array, act: int, floor: int) -> Dictionary:
	for raw in definitions:
		var definition: Dictionary = raw
		if int(definition.get("act", 0)) == act and int(definition.get("floor", 0)) == floor:
			return definition
	return {}

static func unlock(definitions: Array, state: Dictionary, act: int, floor: int) -> bool:
	var definition := find_at(definitions, act, floor)
	if definition.is_empty():
		return false
	var id := String(definition.get("id", ""))
	var was_unlocked := bool((state.get("unlocked", {}) as Dictionary).get(id, false))
	state["unlocked"][id] = true
	state["current"] = id
	return not was_unlocked

static func unlocked_for_act(definitions: Array, state: Dictionary, act: int) -> Array:
	var result: Array = []
	var unlocked: Dictionary = state.get("unlocked", {})
	for raw in definitions:
		var definition: Dictionary = raw
		if int(definition.get("act", 0)) == act and bool(unlocked.get(String(definition.get("id", "")), false)):
			result.append(definition)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("floor", 0)) < int(b.get("floor", 0)))
	return result

static func adjacent(definitions: Array, state: Dictionary, act: int, direction: int) -> Dictionary:
	var available := unlocked_for_act(definitions, state, act)
	if available.size() < 2 or direction == 0:
		return {}
	var current := String(state.get("current", ""))
	var index := -1
	for i in available.size():
		if String(available[i].get("id", "")) == current:
			index = i
			break
	if index < 0:
		return {}
	var target_index := index + (1 if direction > 0 else -1)
	if target_index < 0 or target_index >= available.size():
		return {}
	return available[target_index]

static func current_name(definitions: Array, state: Dictionary) -> String:
	var current := String(state.get("current", ""))
	for raw in definitions:
		var definition: Dictionary = raw
		if String(definition.get("id", "")) == current:
			return String(definition.get("name", current))
	return "미해금"

static func cycle(definitions: Array, state: Dictionary, act: int) -> Dictionary:
	var available := unlocked_for_act(definitions, state, act)
	if available.size() < 2:
		return {}
	var current := String(state.get("current", ""))
	for i in available.size():
		if String(available[i].get("id", "")) == current:
			return available[(i + 1) % available.size()]
	return {}
