extends RefCounted
# 세이브/로드 (P10) — 캐릭터/인벤토리/진행을 JSON으로 직렬화. preload로 사용.
# user:// = OS별 사용자 데이터 경로(헤드리스도 기록 가능).

const PATH := "user://savegame.json"

static func save_state(state: Dictionary, path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("save: cannot open " + path)
		return false
	f.store_string(JSON.stringify(state, "  "))
	f.close()
	return true

static func load_state(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		return {}
	return parsed

static func has_save(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)
