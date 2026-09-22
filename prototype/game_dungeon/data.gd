extends RefCounted
# 게임 데이터 로더 (data-driven 파이프라인). preload로 사용.
# JSON에서 몬스터/아이템 베이스/접사를 읽어온다 → 콘텐츠 확장의 토대.
# 정식화: 원본 monstats/weapons/armor/MagicPrefix.txt → JSON 변환 임포트.

static func _load(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("data: cannot open " + path)
		return null
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("data: parse failed " + path)
	return parsed

static func monsters() -> Array:
	var d = _load("res://data/monsters.json")
	var p = _load("res://art/monster_palettes.json")
	var a = _load("res://art/monster_archetypes.json")
	if d == null or p == null or a == null:
		return []
	var palettes: Dictionary = p.get("palettes", {})
	var archetypes: Dictionary = a.get("archetypes", {})
	var result: Array = []
	for raw in d.get("monsters", []):
		var monster: Dictionary = raw.duplicate(true)
		var art: Dictionary = monster.get("art", {})
		var palette_id := String(art.get("palette", ""))
		var archetype_id := String(art.get("archetype", ""))
		if not palettes.has(palette_id) or not archetypes.has(archetype_id):
			push_error("data: invalid monster art reference id=" + String(monster.get("id", "")))
			continue
		var color := Color.from_string(String(palettes[palette_id]), Color.MAGENTA)
		monster["color"] = [color.r, color.g, color.b]
		art["generator"] = String(archetypes[archetype_id].get("generator", archetype_id))
		monster["art"] = art
		result.append(monster)
	return result

static func monster_art_errors() -> Array:
	var errors: Array = []
	var d = _load("res://data/monsters.json")
	var p = _load("res://art/monster_palettes.json")
	var a = _load("res://art/monster_archetypes.json")
	if d == null or p == null or a == null:
		return ["monster art input missing"]
	var palettes: Dictionary = p.get("palettes", {})
	var archetypes: Dictionary = a.get("archetypes", {})
	var ids := {}
	for raw in d.get("monsters", []):
		var monster: Dictionary = raw
		var id := String(monster.get("id", ""))
		var art: Dictionary = monster.get("art", {})
		if id.is_empty() or ids.has(id): errors.append("empty or duplicate monster id: " + id)
		ids[id] = true
		if not palettes.has(String(art.get("palette", ""))): errors.append(id + ": unknown palette")
		if not archetypes.has(String(art.get("archetype", ""))): errors.append(id + ": unknown archetype")
	return errors

static func item_bases() -> Dictionary:
	var d = _load("res://data/item_bases.json")
	if d == null:
		return {"weapons": [], "armor": []}
	return d

static func affixes() -> Dictionary:
	var d = _load("res://data/affixes.json")
	if d == null:
		return {"prefixes": [], "suffixes": []}
	return d
