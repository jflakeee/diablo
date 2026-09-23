extends RefCounted

static func new_state(definitions: Array) -> Dictionary:
	var state := {}
	for raw in definitions:
		var definition: Dictionary = raw
		var requirements: Array = definition.get("requires", [])
		state[String(definition.get("id", ""))] = {
			"status": "active" if requirements.is_empty() else "locked",
			"progress": 0,
		}
	return state

static func normalize_state(definitions: Array, saved: Dictionary) -> Dictionary:
	var normalized := new_state(definitions)
	for id in normalized:
		if saved.has(id) and saved[id] is Dictionary:
			var entry: Dictionary = saved[id]
			normalized[id] = {
				"status": String(entry.get("status", normalized[id]["status"])),
				"progress": maxi(0, int(entry.get("progress", 0))),
			}
	_unlock_available(definitions, normalized)
	return normalized

static func _requirements_complete(definition: Dictionary, state: Dictionary) -> bool:
	for required_id in definition.get("requires", []):
		if String(state.get(String(required_id), {}).get("status", "locked")) != "complete":
			return false
	return true

static func _unlock_available(definitions: Array, state: Dictionary) -> void:
	for raw in definitions:
		var definition: Dictionary = raw
		var id := String(definition.get("id", ""))
		var entry: Dictionary = state.get(id, {})
		if String(entry.get("status", "locked")) == "locked" and _requirements_complete(definition, state):
			entry["status"] = "active"
			state[id] = entry

static func _matches(objective: Dictionary, target: String, rank: String) -> bool:
	if String(objective.get("type", "")) != "kill":
		return false
	var expected := String(objective.get("target", ""))
	return expected == "any" or expected == target or (expected.begins_with("rank:") and expected.trim_prefix("rank:") == rank)

static func apply_kill(definitions: Array, state: Dictionary, act: int, target: String, rank: String = "") -> Array:
	var completed: Array = []
	var consumed := {}
	var search_newly_unlocked := true
	while search_newly_unlocked:
		search_newly_unlocked = false
		for raw in definitions:
			var definition: Dictionary = raw
			if int(definition.get("act", 0)) != act:
				continue
			var id := String(definition.get("id", ""))
			if consumed.has(id):
				continue
			var entry: Dictionary = state.get(id, {})
			if String(entry.get("status", "locked")) != "active":
				continue
			var objective: Dictionary = definition.get("objective", {})
			if not _matches(objective, target, rank):
				continue
			consumed[id] = true
			entry["progress"] = mini(int(objective.get("count", 1)), int(entry.get("progress", 0)) + 1)
			if int(entry["progress"]) >= int(objective.get("count", 1)):
				entry["status"] = "complete"
				completed.append(id)
				search_newly_unlocked = true
			state[id] = entry
		_unlock_available(definitions, state)
	return completed

static func definition_by_id(definitions: Array, id: String) -> Dictionary:
	for raw in definitions:
		var definition: Dictionary = raw
		if String(definition.get("id", "")) == id:
			return definition
	return {}

static func current(definitions: Array, state: Dictionary, act: int) -> Dictionary:
	for raw in definitions:
		var definition: Dictionary = raw
		var entry: Dictionary = state.get(String(definition.get("id", "")), {})
		if int(definition.get("act", 0)) == act and String(entry.get("status", "")) == "active":
			return definition
	return {}

static func objective_text(definitions: Array, state: Dictionary, act: int) -> String:
	var definition := current(definitions, state, act)
	if definition.is_empty():
		return "현재 액트 퀘스트 완료"
	var id := String(definition.get("id", ""))
	var entry: Dictionary = state.get(id, {})
	var objective: Dictionary = definition.get("objective", {})
	return "%s %d/%d" % [String(definition.get("name", id)), int(entry.get("progress", 0)), int(objective.get("count", 1))]
