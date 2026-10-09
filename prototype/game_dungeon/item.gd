extends RefCounted
# 아이템/접사/드롭 시스템 — Part 1 §3(접사 규칙) + Part 3 §2(접사 테이블) + Part 5 §5(MF).
# 접사 값·테이블은 부분집합(정식은 MagicPrefix/Suffix.txt). preload로 사용.
# 아이템은 Dictionary로 표현: {name,slot,quality,ilvl,dmin,dmax,defense,affixes{stat:val},prefix,suffix}

const Craft := preload("res://craft.gd")

const WEAPON_BASES := [
	{"name": "Short Sword", "slot": "weapon", "dmin": 2, "dmax": 7, "req_level": 1, "req_str": 10, "req_dex": 10},
	{"name": "Hand Axe", "slot": "weapon", "dmin": 3, "dmax": 10, "req_level": 1, "req_str": 20, "req_dex": 0},
	{"name": "Mace", "slot": "weapon", "dmin": 3, "dmax": 8, "req_level": 2, "req_str": 25, "req_dex": 0},
]
const ARMOR_BASES := [
	{"name": "Quilted Armor", "slot": "armor", "defense": 9, "req_level": 1, "req_str": 10, "req_dex": 0},
	{"name": "Leather Armor", "slot": "armor", "defense": 14, "req_level": 2, "req_str": 15, "req_dex": 0},
	{"name": "Ring Mail", "slot": "armor", "defense": 26, "req_level": 5, "req_str": 30, "req_dex": 0},
]
const HELM_BASES := [
	{"name": "Leather Cap", "slot": "helm", "defense": 5, "req_level": 1, "req_str": 8, "req_dex": 0},
	{"name": "Bone Skullcap", "slot": "helm", "defense": 9, "req_level": 2, "req_str": 12, "req_dex": 0},
	{"name": "Iron Sallet", "slot": "helm", "defense": 16, "req_level": 5, "req_str": 22, "req_dex": 0},
]
const ACCESSORY_BASES := [
	{"name": "Copper Ring", "slot": "ring", "req_level": 2, "req_str": 0, "req_dex": 0},
	{"name": "Moonstone Ring", "slot": "ring", "req_level": 4, "req_str": 0, "req_dex": 0},
	{"name": "Ashen Pendant", "slot": "amulet", "req_level": 6, "req_str": 0, "req_dex": 0},
]
# 참(Charm) — 반지처럼 좌/우 전용 슬롯 2개(가방 패시브 아님, 공간 비용 없는 탭 그리드라
# 무제한 중첩을 막기 위해 장비 슬롯으로 구현했다).
const CHARM_BASES := [
	{"name": "Jagged Tooth Charm", "slot": "charm", "req_level": 3, "req_str": 0, "req_dex": 0},
	{"name": "Sable Charm", "slot": "charm", "req_level": 7, "req_str": 0, "req_dex": 0},
]

# 유니크 아이템(범위 롤) — 베이스명 → 유니크. 각 접사는 [min,max] 범위,
# generate()가 매번 범위 내 랜덤값으로 확정한다(2026-10-09, 기존 고정값
# 원본의 ±20% 내외로 설정). 상세: docs/superpowers/specs/2026-10-09-item-scrapbook-design.md
const UNIQUES := {
	"Short Sword": {"name": "Emberneedle", "affixes": {"ed": [40, 60], "fdmg": [8, 12], "ar": [32, 48]}},
	"Hand Axe": {"name": "Rift Cleaver", "affixes": {"ed": [56, 84], "ar": [32, 48], "cdmg": [6, 10]}},
	"Mace": {"name": "Storm Knell", "affixes": {"ed": [48, 72], "str": [8, 12], "ldmg": [10, 14]}},
	"Quilted Armor": {"name": "Ashweave", "affixes": {"def": [24, 36], "res_all": [10, 14], "dex": [6, 10], "life": [12, 18]}},
	"Leather Armor": {"name": "Frostveil", "affixes": {"def": [36, 54], "res_cold": [28, 42], "res_all": [8, 12], "life": [20, 30]}},
	"Ring Mail": {"name": "Crownless Mantle", "affixes": {"def": [44, 66], "res_all": [12, 18], "mana": [24, 36], "str": [6, 10]}},
	"Copper Ring": {"name": "Kindled Circuit", "affixes": {"life": [14, 22], "res_fire": [16, 24], "ar": [28, 42]}},
	"Moonstone Ring": {"name": "Pale Orbit", "affixes": {"mana": [19, 29], "res_cold": [16, 24], "dex": [4, 6]}},
	"Ashen Pendant": {"name": "Depthward Seal", "affixes": {"res_all": [13, 19], "str": [4, 6], "life": [10, 14]}},
	"Leather Cap": {"name": "Scoutlight Hood", "affixes": {"def": [16, 24], "dex": [8, 12], "ar": [20, 30]}},
	"Bone Skullcap": {"name": "Marrowguard", "affixes": {"def": [28, 42], "life": [16, 24], "str": [6, 10]}},
	"Iron Sallet": {"name": "Warden's Judgment", "affixes": {"def": [40, 60], "res_all": [12, 18], "mana": [14, 20]}},
}

# 독자 세트 장비. 동일 set_id 두 부위를 함께 장착하면 SET_BONUSES가 활성화된다.
# 접사는 UNIQUES와 동일하게 [min,max] 범위(2026-10-09). SET_BONUSES(완성 보너스)는
# 개별 부위 수치가 아니라 "N부위 장착" 보너스라 범위화 대상이 아니다 — 고정값 유지.
const SETS := {
	"Short Sword": {"set_id": "ember_oath", "set_name": "Ember Oath", "piece_name": "Oathspark", "affixes": {"ed": [26, 38], "fdmg": [6, 8]}},
	"Quilted Armor": {"set_id": "ember_oath", "set_name": "Ember Oath", "piece_name": "Oathweave", "affixes": {"def": [18, 26], "res_fire": [14, 22]}},
	"Mace": {"set_id": "storm_vigil", "set_name": "Storm Vigil", "piece_name": "Vigil Bell", "affixes": {"ed": [22, 34], "ldmg": [8, 12]}},
	"Ring Mail": {"set_id": "storm_vigil", "set_name": "Storm Vigil", "piece_name": "Vigil Links", "affixes": {"def": [30, 46], "res_light": [18, 26]}}
}
const SET_BONUSES := {
	"ember_oath": {2: {"life": 30, "res_all": 12}},
	"storm_vigil": {2: {"mana": 24, "ar": 65}}
}

# stat 코드: ed(%ED) ar(+AR) def(+방어) life(+생명) mana(+마나) str dex res_all(+전저항)
const PREFIXES := [
	{"name": "Serrated", "stat": "ed", "min": 10, "max": 20, "alvl": 1, "slot": "weapon"},
	{"name": "Ruinous", "stat": "ed", "min": 21, "max": 30, "alvl": 5, "slot": "weapon"},
	{"name": "Savage", "stat": "ed", "min": 31, "max": 40, "alvl": 8, "slot": "weapon"},
	{"name": "Coppermarked", "stat": "ar", "min": 10, "max": 20, "alvl": 1, "slot": "any"},
	{"name": "Sunmarked", "stat": "ar", "min": 40, "max": 60, "alvl": 8, "slot": "any"},
	{"name": "Reinforced", "stat": "def", "min": 5, "max": 14, "alvl": 1, "slot": "armor"},
	{"name": "Emberbound", "stat": "fdmg", "min": 3, "max": 9, "alvl": 1, "slot": "weapon"},
	{"name": "Rimebound", "stat": "cdmg", "min": 2, "max": 7, "alvl": 3, "slot": "weapon"},
	{"name": "Stormbound", "stat": "ldmg", "min": 1, "max": 12, "alvl": 3, "slot": "weapon"},
]
const SUFFIXES := [
	{"name": "of Vital Sparks", "stat": "life", "min": 1, "max": 5, "alvl": 1, "slot": "any"},
	{"name": "of the Dire Hound", "stat": "life", "min": 11, "max": 20, "alvl": 15, "slot": "any"},
	{"name": "of Focus", "stat": "mana", "min": 1, "max": 6, "alvl": 1, "slot": "any"},
	{"name": "of Might", "stat": "str", "min": 1, "max": 4, "alvl": 1, "slot": "any"},
	{"name": "of Grace", "stat": "dex", "min": 1, "max": 4, "alvl": 1, "slot": "any"},
	{"name": "of Warding", "stat": "res_all", "min": 3, "max": 8, "alvl": 5, "slot": "any"},
	{"name": "of Cinders", "stat": "res_fire", "min": 10, "max": 30, "alvl": 5, "slot": "any"},
	{"name": "of Hoarfrost", "stat": "res_cold", "min": 10, "max": 30, "alvl": 5, "slot": "any"},
	{"name": "of Stormglass", "stat": "res_light", "min": 10, "max": 30, "alvl": 5, "slot": "any"},
	{"name": "of Mireblood", "stat": "res_poison", "min": 10, "max": 30, "alvl": 5, "slot": "any"},
]

static func _eligible(table: Array, ilvl: int, slot: String) -> Array:
	var out: Array = []
	for a in table:
		var a_slot := String(a["slot"])
		var matches := a_slot == "any" or a_slot == slot or (a_slot == "armor" and slot == "helm")
		if int(a["alvl"]) <= ilvl and matches:
			out.append(a)
	return out

static func _roll_affixes(rng: RandomNumberGenerator, it: Dictionary, table: Array, count: int, ilvl: int, is_prefix: bool) -> void:
	var pool := _eligible(table, ilvl, String(it["slot"]))
	var used := {}
	for i in count:
		if pool.is_empty():
			return
		var pick = pool[rng.randi_range(0, pool.size() - 1)]
		var stat := String(pick["stat"])
		if used.has(stat):
			continue
		used[stat] = true
		var val := rng.randi_range(int(pick["min"]), int(pick["max"]))
		it["affixes"][stat] = int(it["affixes"].get(stat, 0)) + val
		if is_prefix and it["prefix"] == "":
			it["prefix"] = String(pick["name"])
		if (not is_prefix) and it["suffix"] == "":
			it["suffix"] = String(pick["name"])

# 접사 규칙(Part 1 §3): 매직 = 접미사만50% / 접두사만25% / 둘다25%. 레어 = pre 1~3 + suf 1~3.
static func generate(rng: RandomNumberGenerator, base: Dictionary, ilvl: int, quality: String) -> Dictionary:
	var slot := String(base["slot"])
	var indestructible := slot in ["ring", "amulet", "charm"]
	var maximum_durability := 1 if indestructible else (24 if slot == "weapon" else 32)
	var it := {
		"name": String(base["name"]), "slot": slot, "quality": quality, "ilvl": ilvl,
		"dmin": int(base.get("dmin", 0)), "dmax": int(base.get("dmax", 0)),
		"defense": int(base.get("defense", 0)),
		"req_level": int(base.get("req_level", 1)), "req_str": int(base.get("req_str", 0)), "req_dex": int(base.get("req_dex", 0)),
		"durability_max": maximum_durability, "durability": maximum_durability,
		"indestructible": indestructible,
		"affixes": {}, "prefix": "", "suffix": "",
	}
	if quality == "normal":
		return it
	if quality == "unique" and UNIQUES.has(String(base["name"])):
		var u: Dictionary = UNIQUES[String(base["name"])]
		it["prefix"] = String(u["name"])   # 유니크 이름 저장
		for k in u["affixes"]:
			var range_vals: Array = u["affixes"][k]
			it["affixes"][k] = rng.randi_range(int(range_vals[0]), int(range_vals[1]))
		return it
	if quality == "set" and SETS.has(String(base["name"])):
		var set_piece: Dictionary = SETS[String(base["name"])]
		it["set_id"] = String(set_piece["set_id"])
		it["set_name"] = String(set_piece["set_name"])
		it["prefix"] = String(set_piece["piece_name"])
		for k in set_piece["affixes"]:
			var range_vals: Array = set_piece["affixes"][k]
			it["affixes"][k] = rng.randi_range(int(range_vals[0]), int(range_vals[1]))
		return it
	_apply_quality_roll(rng, it, quality, ilvl)
	return it

# 스크랩북 티켓 복원용 — 베이스명+슬롯으로 원본 베이스 딕셔너리를 역조회한다.
# 티켓은 베이스 딕셔너리 전체가 아니라 이름만 저장하므로(세이브 용량/데이터
# 신선도 때문 — WEAPON_BASES 등이 나중에 바뀌어도 티켓은 항상 최신 베이스를
# 참조), 복원 시점에 매번 이 함수로 찾는다.
static func find_base(base_name: String, slot: String) -> Dictionary:
	var pool: Array = []
	if slot == "weapon":
		pool = WEAPON_BASES
	elif slot == "armor":
		pool = ARMOR_BASES
	elif slot == "helm":
		pool = HELM_BASES
	elif slot in ["ring", "amulet"]:
		pool = ACCESSORY_BASES
	elif slot == "charm":
		pool = CHARM_BASES
	for base in pool:
		if String(base["name"]) == base_name:
			return base
	return {}

static func _apply_quality_roll(rng: RandomNumberGenerator, it: Dictionary, quality: String, ilvl: int) -> void:
	var n_pre := 0
	var n_suf := 0
	if quality == "magic":
		var r := rng.randf()
		if r < 0.5:
			n_suf = 1
		elif r < 0.75:
			n_pre = 1
		else:
			n_pre = 1
			n_suf = 1
	elif quality == "rare":
		n_pre = rng.randi_range(1, 3)
		n_suf = rng.randi_range(1, 3)
	_roll_affixes(rng, it, PREFIXES, n_pre, ilvl, true)
	_roll_affixes(rng, it, SUFFIXES, n_suf, ilvl, false)

# 큐브: 매직/레어 아이템의 접사를 같은 등급·아이템레벨 기준으로 다시 굴린다(이름/슬롯/
# 요구치/내구도/소켓은 그대로 유지). 미감정 아이템은 대상이 아니다(재굴림할 "현재 접사"를
# 아직 모르는 상태라 의미가 없음).
static func reroll(rng: RandomNumberGenerator, it: Dictionary) -> bool:
	var quality := String(it.get("quality", ""))
	if quality not in ["magic", "rare"] or not is_identified(it):
		return false
	it["affixes"] = {}
	it["prefix"] = ""
	it["suffix"] = ""
	_apply_quality_roll(rng, it, quality, int(it.get("ilvl", 1)))
	return true

# 큐브: 매직 weapon/armor + 룬1 + 퍼펙트 보석1 → "crafted" 품질(고정 접사 2개 +
# ilvl 구간별 랜덤 접사 1~4개). Part 1 §4 제작 규칙 근사 — 상세:
# docs/superpowers/specs/2026-10-08-crafted-items-design.md
const CRAFT_FIXED_AFFIXES := {
	"weapon": [{"stat": "ar", "min": 20, "max": 40}, {"stat": "cdmg", "min": 3, "max": 8}],
	"armor": [{"stat": "def", "min": 10, "max": 20}, {"stat": "res_all", "min": 5, "max": 10}],
}

static func _craft_affix_count(rng: RandomNumberGenerator, ilvl: int) -> int:
	var r := rng.randf() * 100.0
	if ilvl <= 30:
		if r < 40.0: return 1
		elif r < 60.0: return 2
		elif r < 80.0: return 3
		return 4
	if ilvl <= 50:
		if r < 60.0: return 2
		elif r < 80.0: return 3
		return 4
	if ilvl <= 70:
		if r < 80.0: return 3
		return 4
	return 4

static func craft(rng: RandomNumberGenerator, it: Dictionary, character_level: int) -> bool:
	var slot := String(it.get("slot", ""))
	if String(it.get("quality", "")) != "magic" or not is_identified(it) or not CRAFT_FIXED_AFFIXES.has(slot):
		return false
	var base_ilvl := int(it.get("ilvl", 1))
	# 원문 공식의 qlvl 보정은 이 프로젝트가 qlvl을 모델링하지 않아 0으로
	# 근사(그 경우 공식이 접사레벨=ilvl로 수렴) — clvl/ilvl 가중평균만 적용.
	var ilvl := mini(99, int(0.5 * character_level) + int(0.5 * base_ilvl))
	it["quality"] = "crafted"
	it["ilvl"] = ilvl
	it["affixes"] = {}
	it["prefix"] = ""
	it["suffix"] = ""
	for fixed in CRAFT_FIXED_AFFIXES[slot]:
		var stat := String(fixed["stat"])
		it["affixes"][stat] = int(it["affixes"].get(stat, 0)) + rng.randi_range(int(fixed["min"]), int(fixed["max"]))
	var n := _craft_affix_count(rng, ilvl)
	var n_pre := (n + 1) / 2
	var n_suf := n / 2
	_roll_affixes(rng, it, PREFIXES, n_pre, ilvl, true)
	_roll_affixes(rng, it, SUFFIXES, n_suf, ilvl, false)
	return true

static func requirement_failures(it: Dictionary, character_level: int, strength: int, dexterity: int) -> Array:
	var failures: Array = []
	if not is_identified(it): failures.append("Identify first")
	if character_level < int(it.get("req_level", 1)): failures.append("Lv %d" % int(it.get("req_level", 1)))
	if strength < int(it.get("req_str", 0)): failures.append("STR %d" % int(it.get("req_str", 0)))
	if dexterity < int(it.get("req_dex", 0)): failures.append("DEX %d" % int(it.get("req_dex", 0)))
	return failures

static func can_equip(it: Dictionary, character_level: int, strength: int, dexterity: int) -> bool:
	return requirement_failures(it, character_level, strength, dexterity).is_empty()

static func requirement_text(it: Dictionary) -> String:
	return "Req Lv%d STR%d DEX%d" % [int(it.get("req_level", 1)), int(it.get("req_str", 0)), int(it.get("req_dex", 0))]

# 드롭 롤(Part 1 §4 근사 + Part 5 §5 MF): {} = NoDrop
static func roll_drop(rng: RandomNumberGenerator, monster_level: int, magic_find: int, dropped_uniques: Dictionary = {}) -> Dictionary:
	if rng.randf() < 0.40:
		return {}
	var base: Dictionary
	var base_roll := rng.randf()
	if base_roll < 0.38:
		base = WEAPON_BASES[rng.randi_range(0, WEAPON_BASES.size() - 1)]
	elif base_roll < 0.62:
		base = ARMOR_BASES[rng.randi_range(0, ARMOR_BASES.size() - 1)]
	elif base_roll < 0.72:
		base = HELM_BASES[rng.randi_range(0, HELM_BASES.size() - 1)]
	elif base_roll < 0.86:
		base = ACCESSORY_BASES[rng.randi_range(0, ACCESSORY_BASES.size() - 1)]
	else:
		base = CHARM_BASES[rng.randi_range(0, CHARM_BASES.size() - 1)]
	var ilvl := monster_level + 8   # 데모: 접사 다양성 위해 상향(정식은 mlvl 그대로)
	var eff_mf := (magic_find * 600.0) / (magic_find + 600.0) if magic_find > 0 else 0.0
	var rare_chance := 4.0 * (1.0 + eff_mf / 100.0)
	var uniq_mf := (magic_find * 250.0) / (magic_find + 250.0) if magic_find > 0 else 0.0
	var uniq_chance := 2.0 * (1.0 + uniq_mf / 100.0)
	var set_mf := (magic_find * 400.0) / (magic_find + 400.0) if magic_find > 0 else 0.0
	var set_chance := 2.5 * (1.0 + set_mf / 100.0)
	var r := rng.randf() * 100.0
	var quality := "magic"
	if r < uniq_chance and UNIQUES.has(String(base["name"])) and not dropped_uniques.has(String(base["name"])):
		quality = "unique"
	elif r < uniq_chance + set_chance and SETS.has(String(base["name"])):
		quality = "set"
	elif r < uniq_chance + set_chance + rare_chance:
		quality = "rare"
	elif r >= 92.0:
		quality = "normal"
	var item := generate(rng, base, ilvl, quality)
	if quality == "rare":
		item["identified"] = false
	if quality == "unique":
		dropped_uniques[String(base["name"])] = true
	return item

# Missing flags are legacy, already usable equipment. Identification reveals the
# original roll; it never regenerates stats or consumes randomness.
static func is_identified(it: Dictionary) -> bool:
	return bool(it.get("identified", true))

static func identify(it: Dictionary) -> bool:
	if is_identified(it) or String(it.get("slot", "")) not in ["weapon", "armor", "helm", "ring", "amulet", "charm"]:
		return false
	it["identified"] = true
	return true

static func display_name(it: Dictionary) -> String:
	if not is_identified(it):
		return "Unidentified %s" % String(it.get("name", "Item"))
	if String(it.get("slot", "")) == "skill_book":
		return String(it.get("name", "Skill Book"))
	var q := String(it["quality"])
	if q == "normal":
		return String(it["name"])
	if q == "unique":
		return "%s (%s)" % [String(it["prefix"]), String(it["name"])]   # 유니크명 (베이스)
	if q == "set":
		return "%s (%s)" % [String(it["prefix"]), String(it["set_name"])]
	var pre := (String(it["prefix"]) + " ") if it["prefix"] != "" else ""
	var suf := (" " + String(it["suffix"])) if it["suffix"] != "" else ""
	return pre + String(it["name"]) + suf

static func affix_text(it: Dictionary) -> String:
	if not is_identified(it):
		return "Hidden options - identify in Bag"
	var parts: Array = []
	if int(it.get("dmax", 0)) > 0:
		parts.append("%d-%d dmg" % [int(it["dmin"]), int(it["dmax"])])
	if int(it.get("defense", 0)) > 0:
		parts.append("def %d" % int(it["defense"]))
	for stat in it["affixes"]:
		parts.append("+%d %s" % [int(it["affixes"][stat]), stat])
	return ", ".join(parts)

static func quality_color(q: String) -> Color:
	if q == "magic":
		return Color(0.45, 0.5, 1.0)
	if q == "rare":
		return Color(1.0, 0.9, 0.35)
	if q == "unique":
		return Color(0.72, 0.55, 0.28)   # 유니크 금갈색
	if q == "set":
		return Color(0.2, 0.85, 0.35)
	if q == "crafted":
		return Color(0.8, 0.45, 0.15)   # 구리색 — 매직/레어/유니크/세트와 구분
	return Color(0.85, 0.85, 0.85)

# 구형 저장에는 내구도 필드가 없다. 해당 아이템은 완전 수리 상태로 간주한다.
static func durability_max(it: Dictionary) -> int:
	if bool(it.get("indestructible", false)):
		return 1
	return maxi(1, int(it.get("durability_max", 24 if String(it.get("slot", "")) == "weapon" else 32)))

static func durability(it: Dictionary) -> int:
	return clampi(int(it.get("durability", durability_max(it))), 0, durability_max(it))

static func is_broken(it: Dictionary) -> bool:
	return not it.is_empty() and not bool(it.get("indestructible", false)) and durability(it) <= 0

static func lose_durability(it: Dictionary, amount: int = 1) -> bool:
	if it.is_empty() or amount <= 0:
		return false
	if bool(it.get("indestructible", false)):
		return false
	var was_broken := is_broken(it)
	it["durability_max"] = durability_max(it)
	it["durability"] = maxi(0, durability(it) - amount)
	return not was_broken and is_broken(it)

static func repair_cost(it: Dictionary) -> int:
	if it.is_empty():
		return 0
	if bool(it.get("indestructible", false)):
		return 0
	var missing := durability_max(it) - durability(it)
	var quality_multiplier: int = int({"normal": 1, "magic": 2, "rare": 3, "crafted": 4, "set": 5, "unique": 6}.get(String(it.get("quality", "normal")), 1))
	return missing * int(quality_multiplier) * maxi(1, 1 + int(it.get("ilvl", 1)) / 5)

static func repair(it: Dictionary) -> int:
	if it.is_empty():
		return 0
	var cost := repair_cost(it)
	it["durability_max"] = durability_max(it)
	it["durability"] = durability_max(it)
	return cost

# ── 소켓/룬워드 (Phase 4) ──
static func make_socketed(base: Dictionary, sockets: int) -> Dictionary:
	var it := generate(null, base, 1, "normal")
	it["sockets"] = sockets
	it["socketed"] = []
	return it

static func socket_insert(it: Dictionary, socketable: Dictionary) -> bool:
	var cur: Array = it.get("socketed", [])
	if cur.size() >= int(it.get("sockets", 0)):
		return false
	cur.append(socketable)
	it["socketed"] = cur
	return true

# 유효 스탯 = 베이스 접사 + 소켓(보석/룬) + 룬워드(순서·소켓수 일치 시)
static func effective_affixes(it: Dictionary) -> Dictionary:
	var out := {}
	if is_broken(it) or not is_identified(it):
		return out
	for k in it.get("affixes", {}):
		out[k] = int(it["affixes"][k])
	var slot := String(it["slot"])
	var rune_ids: Array = []
	for s in it.get("socketed", []):
		var stat := {}
		if String(s["kind"]) == "gem":
			stat = Craft.gem_stat(String(s["id"]), slot)
		else:
			stat = Craft.rune_stat(String(s["id"]), slot)
			rune_ids.append(String(s["id"]))
		for k in stat:
			out[k] = int(out.get(k, 0)) + int(stat[k])
	if rune_ids.size() >= 2 and rune_ids.size() == int(it.get("sockets", 0)):
		var rw := Craft.match_runeword(slot, rune_ids)
		if not rw.is_empty():
			it["runeword"] = String(rw["name"])
			for k in rw["stats"]:
				out[k] = int(out.get(k, 0)) + int(rw["stats"][k])
	return out

static func aggregate_affixes(items: Array) -> Dictionary:
	var result := {}
	for item in items:
		if not item is Dictionary or (item as Dictionary).is_empty():
			continue
		for stat in effective_affixes(item):
			result[stat] = int(result.get(stat, 0)) + int(effective_affixes(item)[stat])
	return result

static func equipped_set_bonus(items: Array) -> Dictionary:
	var counts := {}
	for raw in items:
		if not raw is Dictionary:
			continue
		var it: Dictionary = raw
		if not it.is_empty() and is_identified(it) and not is_broken(it) and String(it.get("quality", "")) == "set":
			var set_id := String(it.get("set_id", ""))
			counts[set_id] = int(counts.get(set_id, 0)) + 1
	var result := {}
	for set_id in counts:
		var tiers: Dictionary = SET_BONUSES.get(set_id, {})
		for required in tiers:
			if int(counts[set_id]) >= int(required):
				for stat in (tiers[required] as Dictionary):
					result[stat] = int(result.get(stat, 0)) + int(tiers[required][stat])
	return result
