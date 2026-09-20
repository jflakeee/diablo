extends RefCounted
# 아이템/접사/드롭 시스템 — Part 1 §3(접사 규칙) + Part 3 §2(접사 테이블) + Part 5 §5(MF).
# 접사 값·테이블은 부분집합(정식은 MagicPrefix/Suffix.txt). preload로 사용.
# 아이템은 Dictionary로 표현: {name,slot,quality,ilvl,dmin,dmax,defense,affixes{stat:val},prefix,suffix}

const WEAPON_BASES := [
	{"name": "Short Sword", "slot": "weapon", "dmin": 2, "dmax": 7},
	{"name": "Hand Axe", "slot": "weapon", "dmin": 3, "dmax": 10},
	{"name": "Mace", "slot": "weapon", "dmin": 3, "dmax": 8},
]
const ARMOR_BASES := [
	{"name": "Quilted Armor", "slot": "armor", "defense": 9},
	{"name": "Leather Armor", "slot": "armor", "defense": 14},
	{"name": "Ring Mail", "slot": "armor", "defense": 26},
]

# stat 코드: ed(%ED) ar(+AR) def(+방어) life(+생명) mana(+마나) str dex res_all(+전저항)
const PREFIXES := [
	{"name": "Jagged", "stat": "ed", "min": 10, "max": 20, "alvl": 1, "slot": "weapon"},
	{"name": "Deadly", "stat": "ed", "min": 21, "max": 30, "alvl": 5, "slot": "weapon"},
	{"name": "Vicious", "stat": "ed", "min": 31, "max": 40, "alvl": 8, "slot": "weapon"},
	{"name": "Bronze", "stat": "ar", "min": 10, "max": 20, "alvl": 1, "slot": "any"},
	{"name": "Gold", "stat": "ar", "min": 40, "max": 60, "alvl": 8, "slot": "any"},
	{"name": "Sturdy", "stat": "def", "min": 5, "max": 14, "alvl": 1, "slot": "armor"},
]
const SUFFIXES := [
	{"name": "of the Jackal", "stat": "life", "min": 1, "max": 5, "alvl": 1, "slot": "any"},
	{"name": "of the Wolf", "stat": "life", "min": 11, "max": 20, "alvl": 15, "slot": "any"},
	{"name": "of Energy", "stat": "mana", "min": 1, "max": 6, "alvl": 1, "slot": "any"},
	{"name": "of Strength", "stat": "str", "min": 1, "max": 4, "alvl": 1, "slot": "any"},
	{"name": "of Dexterity", "stat": "dex", "min": 1, "max": 4, "alvl": 1, "slot": "any"},
	{"name": "of the Fox", "stat": "res_all", "min": 3, "max": 8, "alvl": 5, "slot": "any"},
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
	var it := {
		"name": String(base["name"]), "slot": String(base["slot"]), "quality": quality, "ilvl": ilvl,
		"dmin": int(base.get("dmin", 0)), "dmax": int(base.get("dmax", 0)),
		"defense": int(base.get("defense", 0)),
		"affixes": {}, "prefix": "", "suffix": "",
	}
	if quality == "normal":
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

# 드롭 롤(Part 1 §4 근사 + Part 5 §5 MF): {} = NoDrop
static func roll_drop(rng: RandomNumberGenerator, monster_level: int, magic_find: int) -> Dictionary:
	if rng.randf() < 0.40:
		return {}
	var base: Dictionary
	if rng.randf() < 0.5:
		base = WEAPON_BASES[rng.randi_range(0, WEAPON_BASES.size() - 1)]
	else:
		base = ARMOR_BASES[rng.randi_range(0, ARMOR_BASES.size() - 1)]
	var ilvl := monster_level + 8   # 데모: 접사 다양성 위해 상향(정식은 mlvl 그대로)
	var eff_mf := (magic_find * 600.0) / (magic_find + 600.0) if magic_find > 0 else 0.0
	var rare_chance := 4.0 * (1.0 + eff_mf / 100.0)
	var r := rng.randf() * 100.0
	var quality := "magic"
	if r < rare_chance:
		quality = "rare"
	elif r >= 92.0:
		quality = "normal"
	return generate(rng, base, ilvl, quality)

static func display_name(it: Dictionary) -> String:
	if String(it["quality"]) == "normal":
		return String(it["name"])
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
	return Color(0.85, 0.85, 0.85)
