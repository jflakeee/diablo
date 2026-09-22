extends RefCounted
# 빌드 타임 생성 아틀라스 소비기. 산출물이 없거나 손상되면 null을 반환한다.

const MANIFEST_PATH := "res://generated/manifest.json"
const ATLAS_PATH := "res://generated/atlas.png"
const ANIMATION_MANIFEST_PATH := "res://generated/animation_manifest.json"
const ANIMATION_ATLAS_PATH := "res://generated/animation_atlas.png"

enum MissingPolicy { FALLBACK, WARN, FAIL }

var _atlas: Texture2D
var _entries := {}
var _regions := {}
var _animation_atlas: Texture2D
var _actors := {}
var _animation_regions := {}
var _policy: MissingPolicy = MissingPolicy.WARN if OS.is_debug_build() else MissingPolicy.FAIL
var _missing := {}
var _warned := {}
var _fallbacks := 0

func _init() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH) or not ResourceLoader.exists(ATLAS_PATH):
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("format_version", 0)) != 2 or not parsed.has("entries"):
		return
	_entries = parsed["entries"]
	_atlas = load(ATLAS_PATH) as Texture2D
	if FileAccess.file_exists(ANIMATION_MANIFEST_PATH) and ResourceLoader.exists(ANIMATION_ATLAS_PATH):
		var anim_file := FileAccess.open(ANIMATION_MANIFEST_PATH, FileAccess.READ)
		var anim_parsed = JSON.parse_string(anim_file.get_as_text()) if anim_file != null else null
		if anim_parsed is Dictionary and int(anim_parsed.get("format_version", 0)) == 2:
			_actors = anim_parsed.get("actors", {})
			_animation_atlas = load(ANIMATION_ATLAS_PATH) as Texture2D

func available() -> bool:
	return _atlas != null and not _entries.is_empty()

func configure(policy: MissingPolicy, _fallback_generator: GDScript = null) -> void:
	_policy = policy

func allows_fallback() -> bool:
	return _policy != MissingPolicy.FAIL

func _record_missing(id: String) -> void:
	_missing[id] = true
	if _policy == MissingPolicy.WARN and not _warned.has(id):
		push_warning("Missing generated asset: " + id)
		_warned[id] = true
	elif _policy == MissingPolicy.FAIL:
		push_error("Required generated asset missing: " + id)

func record_fallback(id: String) -> void:
	_fallbacks += 1
	_record_missing(id)

func texture(id: String) -> Texture2D:
	var key := id.to_lower().replace(" ", "_")
	if _regions.has(key):
		return _regions[key]
	if _atlas == null or not _entries.has(key):
		_record_missing("static/" + key)
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
	return _actor_frames(kind, "walk_" + direction)

func hero_directions(kind: String) -> Dictionary:
	var result := {}
	var names := ["s", "e", "n", "w"]
	for direction in 4:
		var frames := hero_frames(kind, names[direction])
		if frames.is_empty():
			return {}
		result[direction] = frames
	return result

func monster_frames(name: String) -> Dictionary:
	return _actor_frames(name.to_lower().replace(" ", "_"), "walk")

func missing_assets() -> PackedStringArray:
	var result := PackedStringArray(_missing.keys())
	result.sort()
	return result

func fallback_count() -> int:
	return _fallbacks

func loaded_atlas_count() -> int:
	return int(_atlas != null) + int(_animation_atlas != null)

func validate_runtime() -> Dictionary:
	var animation_count := 0
	for actor in _actors.values():
		animation_count += (actor as Dictionary).get("animations", {}).size()
	return {"ok": available() and loaded_atlas_count() == 2 and _missing.is_empty() and _fallbacks == 0,
		"static_entries": _entries.size(), "actors": _actors.size(), "animations": animation_count,
		"missing": missing_assets(), "fallback_count": _fallbacks}

func _actor_frames(actor_id: String, anim_id: String) -> Dictionary:
	if _animation_atlas == null or not _actors.has(actor_id):
		_record_missing("animation/" + actor_id + "/" + anim_id)
		return {}
	var animations: Dictionary = _actors[actor_id].get("animations", {})
	if not animations.has(anim_id):
		_record_missing("animation/" + actor_id + "/" + anim_id)
		return {}
	var specs: Array = animations[anim_id].get("frames", [])
	if specs.size() < 3:
		return {}
	var textures: Array = []
	for spec in specs:
		var values: Array = spec.get("region", [])
		if values.size() != 4:
			return {}
		var key := "%d:%d:%d:%d" % [int(values[0]), int(values[1]), int(values[2]), int(values[3])]
		if not _animation_regions.has(key):
			var region := AtlasTexture.new()
			region.atlas = _animation_atlas
			region.region = Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
			region.filter_clip = true
			_animation_regions[key] = region
		textures.append(_animation_regions[key])
	return {"idle": textures[1], "walk": [textures[0], textures[1], textures[2]]}

func selftest() -> bool:
	if not available() or entry_count() != 28:
		return false
	var sword := texture("sword")
	var potion := texture("potion")
	var ruby := texture("ruby")
	var hero := hero_directions("barbarian")
	var monster_ids := ["ash_imp", "ash_caller", "thorn_beast", "rotwalker", "bone_guard",
		"bone_marksman", "horned_marauder", "crimson_raptor", "blighted_ranger", "grave_stalker", "venom_husk", "brood_matron"]
	for monster_id in monster_ids:
		if monster_frames(monster_id).is_empty():
			return false
	return sword != null and potion != null and ruby != null and sword != potion and hero.size() == 4 and ((hero[0] as Dictionary)["walk"] as Array).size() == 3

func clear() -> void:
	_regions.clear()
	_animation_regions.clear()
	_entries.clear()
	_atlas = null
	_animation_atlas = null
	_actors.clear()
	_missing.clear()
	_warned.clear()
	_fallbacks = 0
