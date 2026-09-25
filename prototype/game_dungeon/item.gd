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
const ACCESSORY_BASES := [
	{"name": "Copper Ring", "slot": "ring", "req_level": 2, "req_str": 0, "req_dex": 0},
	{"name": "Moonstone Ring", "slot": "ring", "req_level": 4, "req_str": 0, "req_dex": 0},
	{"name": "Ashen Pendant", "slot": "amulet", "req_level": 6, "req_str": 0, "req_dex": 0},
]

# 유니크 아이템(고정 스탯) — 베이스명 → 유니크
const UNIQUES := {
	"Short Sword": {"name": "Emberneedle", "affixes": {"ed": 50, "fdmg": 10, "ar": 40}},
	"Hand Axe": {"name": "Rift Cleaver", "affixes": {"ed": 70, "ar": 40, "cdmg": 8}},
	"Mace": {"name": "Storm Knell", "affixes": {"ed": 60, "str": 10, "ldmg": 12}},
	"Quilted Armor": {"name": "Ashweave", "affixes": {"def": 30, "res_all": 12, "dex": 8, "life": 15}},
	"Leather Armor": {"name": "Frostveil", "affixes": {"def": 45, "res_cold": 35, "res_all": 10, "life": 25}},
	"Ring Mail": {"name": "Crownless Mantle", "affixes": {"def": 55, "res_all": 15, "mana": 30, "str": 8}},
	"Copper Ring": {"name": "Kindled Circuit", "affixes": {"life": 18, "res_fire": 20, "ar": 35}},
	"Moonstone Ring": {"name": "Pale Orbit", "affixes": {"mana": 24, "res_cold": 20, "dex": 5}},
	"Ashen Pendant": {"name": "Depthward Seal", "affixes": {"res_all": 16, "str": 5, "life": 12}},
}

# 독자 세트 장비. 동일 set_id 두 부위를 함께 장착하면 SET_BONUSES가 활성화된다.
const SETS := {
	"Short Sword": {"set_id": "ember_oath", "set_name": "Ember Oath", "piece_name": "Oathspark", "affixes": {"ed": 32, "fdmg": 7}},
	"Quilted Armor": {"set_id": "ember_oath", "set_name": "Ember Oath", "piece_name": "Oathweave", "affixes": {"def": 22, "res_fire": 18}},
	"Mace": {"set_id": "storm_vigil", "set_name": "Storm Vigil", "piece_name": "Vigil Bell", "affixes": {"ed": 28, "ldmg": 10}},
	"Ring Mail": {"set_id": "storm_vigil", "set_name": "Storm Vigil", "piece_name": "Vigil Links", "affixes": {"def": 38, "res_light": 22}}
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
		if int(a["alvl"]) <= ilvl and (a["slot"] == "any" or a["slot"] == slot):
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
	var indestructible := slot in ["ring", "amulet"]
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
			it["affixes"][k] = int(u["affixes"][k])
		return it
	if quality == "set" and SETS.has(String(base["name"])):
		var set_piece: Dictionary = SETS[String(base["name"])]
		it["set_id"] = String(set_piece["set_id"])
		it["set_name"] = String(set_piece["set_name"])
		it["prefix"] = String(set_piece["piece_name"])
		for k in set_piece["affixes"]:
			it["affixes"][k] = int(set_piece["affixes"][k])
		return it
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
	return it

static func requirement_failures(it: Dictionary, character_level: int, strength: int, dexterity: int) -> Array:
	var failures: Array = []
	if character_level < int(it.get("req_level", 1)): failures.append("Lv %d" % int(it.get("req_level", 1)))
	if strength < int(it.get("req_str", 0)): failures.append("STR %d" % int(it.get("req_str", 0)))
	if dexterity < int(it.get("req_dex", 0)): failures.append("DEX %d" % int(it.get("req_dex", 0)))
	return failures

static func can_equip(it: Dictionary, character_level: int, strength: int, dexterity: int) -> bool:
	return requirement_failures(it, character_level, strength, dexterity).is_empty()

static func requirement_text(it: Dictionary) -> String:
	return "Req Lv%d STR%d DEX%d" % [int(it.get("req_level", 1)), int(it.get("req_str", 0)), int(it.get("req_dex", 0))]

# 드롭 롤(Part 1 §4 근사 + Part 5 §5 MF): {} = NoDrop
static func roll_drop(rng: RandomNumberGenerator, monster_level: int, magic_find: int) -> Dictionary:
	if rng.randf() < 0.40:
		return {}
	var base: Dictionary
	var base_roll := rng.randf()
	if base_roll < 0.42:
		base = WEAPON_BASES[rng.randi_range(0, WEAPON_BASES.size() - 1)]
	elif base_roll < 0.84:
		base = ARMOR_BASES[rng.randi_range(0, ARMOR_BASES.size() - 1)]
	else:
		base = ACCESSORY_BASES[rng.randi_range(0, ACCESSORY_BASES.size() - 1)]
	var ilvl := monster_level + 8   # 데모: 접사 다양성 위해 상향(정식은 mlvl 그대로)
	var eff_mf := (magic_find * 600.0) / (magic_find + 600.0) if magic_find > 0 else 0.0
	var rare_chance := 4.0 * (1.0 + eff_mf / 100.0)
	var uniq_mf := (magic_find * 250.0) / (magic_find + 250.0) if magic_find > 0 else 0.0
	var uniq_chance := 2.0 * (1.0 + uniq_mf / 100.0)
	var set_mf := (magic_find * 400.0) / (magic_find + 400.0) if magic_find > 0 else 0.0
	var set_chance := 2.5 * (1.0 + set_mf / 100.0)
	var r := rng.randf() * 100.0
	var quality := "magic"
	if r < uniq_chance and UNIQUES.has(String(base["name"])):
		quality = "unique"
	elif r < uniq_chance + set_chance and SETS.has(String(base["name"])):
		quality = "set"
	elif r < uniq_chance + set_chance + rare_chance:
		quality = "rare"
	elif r >= 92.0:
		quality = "normal"
	return generate(rng, base, ilvl, quality)

static func display_name(it: Dictionary) -> String:
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
	var quality_multiplier: int = int({"normal": 1, "magic": 2, "rare": 3, "set": 4, "unique": 5}.get(String(it.get("quality", "normal")), 1))
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
	if is_broken(it):
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

static func equipped_set_bonus(items: Array) -> Dictionary:
	var counts := {}
	for raw in items:
		if not raw is Dictionary:
			continue
		var it: Dictionary = raw
		if not it.is_empty() and not is_broken(it) and String(it.get("quality", "")) == "set":
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
