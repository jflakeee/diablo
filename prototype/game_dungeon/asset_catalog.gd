extends RefCounted
# 빌드 타임 생성 아틀라스 소비기. 산출물이 없거나 손상되면 null을 반환한다.

const MANIFEST_PATH := "res://generated/manifest.json"
const ATLAS_PATH := "res://generated/atlas.png"
const HEROES_PATH := "res://generated/heroes.tres"

var _atlas: Texture2D
var _entries := {}
var _regions := {}
var _heroes: SpriteFrames

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
	if ResourceLoader.exists(HEROES_PATH):
		_heroes = load(HEROES_PATH) as SpriteFrames

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

func hero_frames(kind: String, direction: String = "s") -> Dictionary:
	if _heroes == null:
		return {}
	var anim := "%s_walk_%s" % [kind, direction]
	if not _heroes.has_animation(anim) or _heroes.get_frame_count(anim) < 3:
		return {}
	return {"idle": _heroes.get_frame_texture(anim, 1), "walk": [
		_heroes.get_frame_texture(anim, 0),
		_heroes.get_frame_texture(anim, 1),
		_heroes.get_frame_texture(anim, 2),
	]}

func hero_directions(kind: String) -> Dictionary:
	var result := {}
	var names := ["s", "e", "n", "w"]
	for direction in 4:
		var frames := hero_frames(kind, names[direction])
		if frames.is_empty():
			return {}
		result[direction] = frames
	return result

func selftest() -> bool:
	if not available() or entry_count() != 18:
		return false
	var sword := texture("sword")
	var potion := texture("potion")
	var ruby := texture("ruby")
	var hero := hero_directions("barbarian")
	return sword != null and potion != null and ruby != null and sword != potion and texture("missing") == null and hero.size() == 4 and ((hero[0] as Dictionary)["walk"] as Array).size() == 3

func clear() -> void:
	_regions.clear()
	_entries.clear()
	_atlas = null
	_heroes = null
