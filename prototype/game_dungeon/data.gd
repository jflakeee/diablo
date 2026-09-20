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
	if d == null:
		return []
	return d.get("monsters", [])

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
