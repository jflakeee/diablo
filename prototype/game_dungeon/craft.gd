extends RefCounted
# 소켓/보석/룬/룬워드/큐브 (Part 6 §2 보석 · Part 2 §4 룬워드 · Part 3 §3 큐브).
# 값은 부분집합 근사 — 정식은 gems.txt/runes.txt/runewords.txt/cubemain.txt. preload로 사용.

const RUNE_ORDER := [
	"Ahn", "Ahnor", "Vey", "Korr", "Saal", "Myr", "Dren", "Pyre", "Volt", "Rime",
	"Nara", "Solun", "Shae", "Doln", "Helm", "Iora", "Luma", "Kovan", "Fara", "Lemn",
	"Pura", "Umon", "Mala", "Istra", "Gulan", "Vexa", "Ohra", "Lorn", "Sura", "Beryn",
	"Jahar", "Chama", "Zorin",
]

# 룬 소켓 스탯(슬롯별) — 룬워드에 쓰이는 룬 위주 부분집합
const RUNE_STATS := {
	"Ahn": {"weapon": {"ar": 50}, "armor": {"def": 15}},
	"Vey": {"weapon": {"mana": 2}, "armor": {"mana": 2}},
	"Korr": {"weapon": {}, "armor": {"def": 30}},
	"Saal": {"weapon": {}, "armor": {"mana": 3}},
	"Dren": {"weapon": {}, "armor": {"res_all": 5}},
	"Pyre": {"weapon": {"res_all": 5}, "armor": {"res_all": 5}},
}

# Perfect 보석 스탯(슬롯별) — Part 6 §2 (매핑 가능한 stat만). 값은 전부 perfect 등급
# 기준이며, 소켓 시 실제 효과는 GEM_QUALITY_SCALE로 등급에 맞게 축소된다.
const GEM_STATS := {
	"amethyst": {"weapon": {"ar": 150}, "armor": {"str": 10}},
	"diamond": {"weapon": {"ar": 100}, "armor": {"res_all": 19}},
	"ruby": {"weapon": {}, "armor": {"life": 38}},
	"sapphire": {"weapon": {}, "armor": {"mana": 38}},
	"emerald": {"weapon": {}, "armor": {"dex": 10}},
	"topaz": {"weapon": {}, "armor": {"res_all": 0}},
	"skull": {"weapon": {}, "armor": {"life": 0}},
}

# 품질별 효과 배율(perfect=1.0 기준 역산). chipped/flawed는 현재 드롭 테이블에
# 없고(드롭은 normal에서 시작, 업그레이드는 위로만 간다) 변환 체인의 하위 끝으로만
# 존재하지만, 큐브로 일반 등급까지 내려서 끼울 가능성을 막지 않기 위해 정의는 둔다.
const GEM_QUALITY_SCALE := {
	"chipped": 0.4, "flawed": 0.55, "normal": 0.7, "flawless": 0.85, "perfect": 1.0,
}

# 룬워드(부분집합) — stats는 매핑 근사
const RUNEWORDS := [
	{"name": "Tempered Edge", "runes": ["Vey", "Ahn"], "slot": "weapon", "sockets": 2, "stats": {"ed": 20, "ar": 50}},
	{"name": "Veiled Step", "runes": ["Dren", "Saal"], "slot": "armor", "sockets": 2, "stats": {"dex": 6, "mana": 15}},
	{"name": "Gloom Crown", "runes": ["Korr", "Vey"], "slot": "helm", "sockets": 2, "stats": {"def": 50}},
]

static func gem_stat(gem_id: String, slot: String) -> Dictionary:
	var parts := gem_id.split(":")
	var name := String(parts[0])
	var quality := String(parts[1]) if parts.size() == 2 else "normal"
	var g: Dictionary = GEM_STATS.get(name, {})
	var base: Dictionary = g.get(slot, {})
	var scale: float = float(GEM_QUALITY_SCALE.get(quality, GEM_QUALITY_SCALE["normal"]))
	var result := {}
	for stat in base:
		result[stat] = roundi(float(base[stat]) * scale)
	return result

static func rune_stat(rune: String, slot: String) -> Dictionary:
	var r: Dictionary = RUNE_STATS.get(rune, {})
	return r.get(slot, {})

static func match_runeword(slot: String, socketed_runes: Array) -> Dictionary:
	for rw in RUNEWORDS:
		if rw["slot"] == slot and int(rw["sockets"]) == socketed_runes.size():
			var same := true
			for i in socketed_runes.size():
				if String(rw["runes"][i]) != String(socketed_runes[i]):
					same = false
					break
			if same:
				return rw
	return {}

# 큐브: 동일 하위 룬 3개 → 다음 룬 (Part 3 §3)
static func upgrade_rune(id: String) -> String:
	var i := RUNE_ORDER.find(id)
	if i >= 0 and i < RUNE_ORDER.size() - 1:
		return RUNE_ORDER[i + 1]
	return ""

# 큐브: 보석 3개 → 다음 등급
const GEM_QUALITY := ["chipped", "flawed", "normal", "flawless", "perfect"]

static func upgrade_gem_quality(q: String) -> String:
	var i := GEM_QUALITY.find(q)
	if i >= 0 and i < GEM_QUALITY.size() - 1:
		return GEM_QUALITY[i + 1]
	return ""

# Bare gem IDs are the normal-quality materials used by existing saves/drops.
# Upgraded gems use gem:quality; sigils use rune_ID.
static func material_name(id: String) -> String:
	if id.begins_with("rune_"):
		return "%s Sigil" % id.trim_prefix("rune_")
	var parts := id.split(":")
	if GEM_STATS.has(parts[0]):
		return "%s %s" % [String(parts[1] if parts.size() == 2 else "normal").capitalize(), String(parts[0]).capitalize()]
	return id.capitalize()

static func upgrade_material(id: String) -> String:
	if id.begins_with("rune_"):
		var next := upgrade_rune(id.trim_prefix("rune_"))
		return "rune_" + next if not next.is_empty() else ""
	var parts := id.split(":")
	if parts.size() > 2 or not GEM_STATS.has(parts[0]):
		return ""
	var quality := String(parts[1]) if parts.size() == 2 else "normal"
	var next := upgrade_gem_quality(quality)
	if next.is_empty():
		return ""
	return String(parts[0]) if next == "normal" else "%s:%s" % [parts[0], next]

# 큐브: 토파즈 N개 + 감정된 매직/레어 아이템 1개 → 아이템 접사 재굴림.
# 토파즈는 소켓 효과가 없어(armor res_all=0) 다른 쓸모가 없는 재료라 리롤 재료로 돌린다.
# 비용은 원작(최상급 해골 매직 3개/레어 6개)의 1:2 비율을 그대로 따르되 재료는
# 토파즈 유지(2026-10-08 리서치 대조 — 해골 재료 전환은 사용자가 보류 결정).
const REROLL_CATALYST := "topaz"
const REROLL_COST := {"magic": 3, "rare": 6}

static func _reroll_cost(it: Dictionary) -> int:
	return int(REROLL_COST.get(String(it.get("quality", "")), 0))

static func can_reroll(materials: Dictionary, it: Dictionary, item_script: GDScript) -> bool:
	var cost := _reroll_cost(it)
	return cost > 0 and int(materials.get(REROLL_CATALYST, 0)) >= cost and item_script.is_identified(it)

static func reroll(rng: RandomNumberGenerator, materials: Dictionary, it: Dictionary, item_script: GDScript) -> bool:
	if not can_reroll(materials, it, item_script):
		return false
	var cost := _reroll_cost(it)
	var available := int(materials.get(REROLL_CATALYST, 0))
	if available == cost:
		materials.erase(REROLL_CATALYST)
	else:
		materials[REROLL_CATALYST] = available - cost
	return item_script.reroll(rng, it)

# 큐브: 스컬 3개 + 소켓 없는 일반(normal) 무기/방어구 → 소켓 2개 부여(제자리 변형).
# Item.make_socketed()는 아이템을 새로 생성하므로 가방의 기존 아이템에는 쓸 수 없다.
# 스컬은 토파즈와 동일한 이유로 재료로 돌린다: GEM_STATS 소켓 효과가 0이라 다른
# 쓸모가 없었고, 드롭 테이블에도 없어 이번에 함께 추가한다.
const SOCKET_CATALYST := "skull"
const SOCKET_COST := 3
const SOCKET_COUNT := 2

static func can_add_sockets(materials: Dictionary, it: Dictionary) -> bool:
	return int(materials.get(SOCKET_CATALYST, 0)) >= SOCKET_COST and String(it.get("quality", "")) == "normal" and String(it.get("slot", "")) in ["weapon", "armor"] and int(it.get("sockets", 0)) == 0

static func add_sockets(materials: Dictionary, it: Dictionary) -> bool:
	if not can_add_sockets(materials, it):
		return false
	var available := int(materials.get(SOCKET_CATALYST, 0))
	if available == SOCKET_COST:
		materials.erase(SOCKET_CATALYST)
	else:
		materials[SOCKET_CATALYST] = available - SOCKET_COST
	it["sockets"] = SOCKET_COUNT
	it["socketed"] = []
	return true

# 큐브: 매직 weapon/armor + 룬 1개 + 퍼펙트 보석 1개 → "crafted" 품질(고정
# 접사 + 랜덤 접사). 어떤 룬워드에도 안 쓰이는 Saal(룬 아이콘은 이름 무관
# 범용이라 드롭 풀에 추가해도 아틀라스 작업 불필요)과, 기존 드롭 가능한 5종
# 보석 중 하나(ruby)의 perfect 등급을 전용 촉매로 골라 기존 토파즈/스컬
# 경제와 겹치지 않게 한다. diamond/amethyst는 GEM_STATS에 정의만 있고
# art_recipes.json에 아이콘이 없어 재료로 쓰면 2026-10-04의
# `[ASSET] "ok": false` 함정을 재현하므로 의도적으로 배제.
# 상세: docs/superpowers/specs/2026-10-08-crafted-items-design.md
const CRAFT_RUNE_CATALYST := "rune_Saal"
const CRAFT_GEM_CATALYST := "ruby:perfect"

static func can_craft(materials: Dictionary, it: Dictionary) -> bool:
	return int(materials.get(CRAFT_RUNE_CATALYST, 0)) >= 1 and int(materials.get(CRAFT_GEM_CATALYST, 0)) >= 1 \
		and String(it.get("quality", "")) == "magic" and String(it.get("slot", "")) in ["weapon", "armor"]

static func craft(rng: RandomNumberGenerator, materials: Dictionary, it: Dictionary, character_level: int, item_script: GDScript) -> bool:
	if not can_craft(materials, it):
		return false
	for catalyst in [CRAFT_RUNE_CATALYST, CRAFT_GEM_CATALYST]:
		var available := int(materials.get(catalyst, 0))
		if available == 1:
			materials.erase(catalyst)
		else:
			materials[catalyst] = available - 1
	return item_script.craft(rng, it, character_level)

static func transmute(materials: Dictionary, id: String) -> bool:
	var result := upgrade_material(id)
	var available := int(materials.get(id, 0))
	if result.is_empty() or available < 3:
		return false
	# Revalidate at execution time so stale UI cannot spend the same stack twice.
	if available == 3:
		materials.erase(id)
	else:
		materials[id] = available - 3
	materials[result] = int(materials.get(result, 0)) + 1
	return true
