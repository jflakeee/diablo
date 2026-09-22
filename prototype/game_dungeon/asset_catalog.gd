extends RefCounted
# 빌드 타임 생성 아틀라스 소비기. 산출물이 없거나 손상되면 null을 반환한다.

const MANIFEST_PATH := "res://generated/manifest.json"
const ATLAS_PATH := "res://generated/atlas.png"

var _atlas: Texture2D
var _entries := {}
var _regions := {}

func _init() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH) or not ResourceLoader.exists(ATLAS_PATH):
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("entries"):
		return
	_entries = parsed["entries"]
	_atlas = load(ATLAS_PATH) as Texture2D

func available() -> bool:
	return _atlas != null and not _entries.is_empty()

func texture(id: String) -> Texture2D:
	var key := id.to_lower().replace(" ", "_")
	if _regions.has(key):
		return _regions[key]
	if _atlas == null or not _entries.has(key):
		return null
	var values: Array = _entries[key].get("region", [])
	if values.size() != 4:
		return null
	var result := AtlasTexture.new()
	result.atlas = _atlas
	result.region = Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	result.filter_clip = true
	_regions[key] = result
	return result

func entry_count() -> int:
	return _entries.size()

func selftest() -> bool:
	if not available() or entry_count() != 18:
		return false
	var sword := texture("sword")
	var potion := texture("potion")
	var ruby := texture("ruby")
	return sword != null and potion != null and ruby != null and sword != potion and texture("missing") == null

func clear() -> void:
	_regions.clear()
	_entries.clear()
	_atlas = null
