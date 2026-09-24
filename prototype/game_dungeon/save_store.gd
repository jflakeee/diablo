extends RefCounted

const CURRENT_VERSION := 6
const DEFAULT_PATH := "user://ashen_depths_save.json"

static func _migrate(raw: Dictionary) -> Dictionary:
	var state := raw.duplicate(true)
	var version := int(state.get("schema_version", 1))
	if version < 1 or version > CURRENT_VERSION:
		return {}
	if version == 1:
		state["difficulty"] = int(state.get("difficulty", 0))
		state["act"] = int(state.get("act", 1))
		state["acts_cleared"] = int(state.get("acts_cleared", 0))
		state["dungeon_level"] = int(state.get("dungeon_level", 1))
		state["levels_cleared"] = int(state.get("levels_cleared", 0))
		state["gold"] = int(state.get("gold", 0))
		state["belt_hp"] = int(state.get("belt_hp", 2))
		state["belt_mp"] = int(state.get("belt_mp", 2))
		version = 2
	if version == 2:
		state["quest_state"] = state.get("quest_state", {})
		version = 3
	if version == 3:
		state["waypoint_state"] = state.get("waypoint_state", {})
		version = 4
	if version == 4:
		state["merc_equipped"] = state.get("merc_equipped", {"weapon": {}, "armor": {}})
		version = 5
	if version == 5:
		state["stamina"] = float(state.get("stamina", -1.0))
		version = 6
	state["schema_version"] = version
	return state

static func _valid(state: Dictionary) -> bool:
	if int(state.get("schema_version", 0)) != CURRENT_VERSION:
		return false
	if String(state.get("class", "")) not in ["warden", "arcanist"]:
		return false
	if int(state.get("level", 0)) < 1 or int(state.get("level", 0)) > 99:
		return false
	return state.get("skills", null) is Dictionary and state.get("inventory", null) is Array and state.get("equipped", null) is Dictionary

static func save_state(input: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var state := input.duplicate(true)
	state["schema_version"] = CURRENT_VERSION
	if not _valid(state):
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var temp := absolute + ".tmp"
	var backup := absolute + ".bak"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state, "  "))
	file.flush()
	file.close()
	var verify := _load_file(temp)
	if not _valid(verify):
		DirAccess.remove_absolute(temp)
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(absolute):
		if DirAccess.rename_absolute(absolute, backup) != OK:
			DirAccess.remove_absolute(temp)
			return false
	if DirAccess.rename_absolute(temp, absolute) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute)
		return false
	return true

static func _load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed = json.data
	return parsed if parsed is Dictionary else {}

static func load_state(path: String = DEFAULT_PATH) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	var state := _migrate(_load_file(absolute))
	if _valid(state):
		return state
	var backup := _migrate(_load_file(absolute + ".bak"))
	return backup if _valid(backup) else {}

static func selftest() -> Dictionary:
	var failures: Array = []
	var suffix := str(OS.get_process_id())
	var path := "user://save_store_selftest_%s.json" % suffix
	var state := {
		"class": "warden", "level": 7, "skills": {"sundering_strike": 3},
		"inventory": [{"name": "test"}], "equipped": {"weapon": {}, "armor": {}},
	}
	if not save_state(state, path): failures.append("atomic save")
	var loaded := load_state(path)
	if int(loaded.get("schema_version", 0)) != CURRENT_VERSION or int(loaded.get("level", 0)) != 7: failures.append("roundtrip")
	var newer := state.duplicate(true)
	newer["level"] = 8
	if not save_state(newer, path): failures.append("backup rotation")
	var main_file := FileAccess.open(path, FileAccess.WRITE)
	if main_file != null:
		main_file.store_string("{interrupted")
		main_file.close()
	var recovered := load_state(path)
	if int(recovered.get("level", 0)) != 7: failures.append("backup recovery")
	var temp_file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if temp_file != null:
		temp_file.store_string("partial")
		temp_file.close()
	if int(load_state(path).get("level", 0)) != 7: failures.append("interrupted temp isolation")
	var legacy := state.duplicate(true)
	legacy["schema_version"] = 1
	var migrated := _migrate(legacy)
	if int(migrated.get("schema_version", 0)) != CURRENT_VERSION or not migrated.has("difficulty") or not migrated.has("quest_state") or not migrated.has("waypoint_state") or not migrated.has("merc_equipped") or not migrated.has("stamina"): failures.append("v1 migration")
	var v2 := state.duplicate(true)
	v2["schema_version"] = 2
	var migrated_v2 := _migrate(v2)
	if int(migrated_v2.get("schema_version", 0)) != CURRENT_VERSION or not migrated_v2.get("quest_state", null) is Dictionary: failures.append("v2 quest migration")
	var v3 := state.duplicate(true)
	v3["schema_version"] = 3
	var migrated_v3 := _migrate(v3)
	if int(migrated_v3.get("schema_version", 0)) != CURRENT_VERSION or not migrated_v3.get("waypoint_state", null) is Dictionary: failures.append("v3 waypoint migration")
	var v4 := state.duplicate(true)
	v4["schema_version"] = 4
	var migrated_v4 := _migrate(v4)
	if int(migrated_v4.get("schema_version", 0)) != CURRENT_VERSION or not migrated_v4.get("merc_equipped", null) is Dictionary: failures.append("v4 mercenary migration")
	var v5 := state.duplicate(true)
	v5["schema_version"] = 5
	var migrated_v5 := _migrate(v5)
	if int(migrated_v5.get("schema_version", 0)) != CURRENT_VERSION or not migrated_v5.has("stamina"): failures.append("v5 stamina migration")
	var corrupt_path := "user://save_store_corrupt_%s.json" % suffix
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{broken")
		corrupt.close()
	if not load_state(corrupt_path).is_empty(): failures.append("corruption rejection")
	for cleanup in [path, path + ".tmp", path + ".bak", corrupt_path]:
		var absolute := ProjectSettings.globalize_path(cleanup)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	return {"ok": failures.is_empty(), "checks": 11, "failures": failures}
