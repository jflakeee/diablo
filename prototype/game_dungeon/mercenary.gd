extends RefCounted

const Item := preload("res://item.gd")

const SLOTS := ["weapon", "armor", "helm"]

const TYPE_ORDER := ["scout", "guard", "acolyte"]

const TYPES := {
	"scout": {
		"display": "Ember Scout", "art_kind": "scout", "color": Color(0.5, 0.15, 0.2), "seed": 7,
		"range": 6.0, "cooldown": 1.1, "melee": false, "element": "fire",
		"life": 60, "life_per_lv": 22, "ar": 120, "ar_per_lv": 18,
		"dmin": 6, "dmin_per_lv": 2, "dmax": 12, "dmax_per_lv": 3,
		"defense": 20, "defense_per_lv": 3,
	},
	"guard": {
		"display": "Iron Guard", "art_kind": "guard", "color": Color(0.38, 0.38, 0.45), "seed": 11,
		"range": 1.5, "cooldown": 1.4, "melee": true, "element": "",
		"life": 95, "life_per_lv": 30, "ar": 100, "ar_per_lv": 15,
		"dmin": 10, "dmin_per_lv": 3, "dmax": 18, "dmax_per_lv": 4,
		"defense": 35, "defense_per_lv": 5,
	},
	"acolyte": {
		"display": "Frost Acolyte", "art_kind": "acolyte", "color": Color(0.3, 0.45, 0.62), "seed": 13,
		"range": 6.5, "cooldown": 1.3, "melee": false, "element": "cold",
		"life": 50, "life_per_lv": 18, "ar": 115, "ar_per_lv": 16,
		"dmin": 4, "dmin_per_lv": 1, "dmax": 9, "dmax_per_lv": 2,
		"defense": 15, "defense_per_lv": 2,
	},
}

static func empty_equipment() -> Dictionary:
	var equipment := {}
	for slot in SLOTS:
		equipment[slot] = {}
	return equipment

static func normalize_equipment(raw) -> Dictionary:
	var equipment := empty_equipment()
	if not raw is Dictionary:
		return equipment
	for slot in SLOTS:
		var item = raw.get(slot, {})
		if item is Dictionary and not (item as Dictionary).is_empty() and String(item.get("slot", "")) == slot:
			equipment[slot] = (item as Dictionary).duplicate(true)
	return equipment

static func normalize_type(raw) -> String:
	var type_id := String(raw)
	return type_id if TYPES.has(type_id) else TYPE_ORDER[0]

static func next_type(current: String) -> String:
	var idx := TYPE_ORDER.find(normalize_type(current))
	return TYPE_ORDER[(idx + 1) % TYPE_ORDER.size()]

static func strength(level: int) -> int:
	return 20 + maxi(1, level) * 3

static func dexterity(level: int) -> int:
	return 15 + maxi(1, level) * 2

static func can_equip(item: Dictionary, level: int = 99) -> bool:
	return bool(item.get("identified", true)) and String(item.get("slot", "")) in SLOTS and level >= int(item.get("req_level", 1)) and strength(level) >= int(item.get("req_str", 0)) and dexterity(level) >= int(item.get("req_dex", 0))

static func stats(level: int, equipment: Dictionary, item_script: GDScript, merc_type: String = "scout") -> Dictionary:
	var tmpl: Dictionary = TYPES.get(normalize_type(merc_type), TYPES["scout"])
	var lv := maxi(1, level)
	var result := {
		"life": int(tmpl["life"]) + lv * int(tmpl["life_per_lv"]),
		"attack_rating": int(tmpl["ar"]) + lv * int(tmpl["ar_per_lv"]),
		"dmg_min": int(tmpl["dmin"]) + lv * int(tmpl["dmin_per_lv"]),
		"dmg_max": int(tmpl["dmax"]) + lv * int(tmpl["dmax_per_lv"]),
		"defense": int(tmpl["defense"]) + lv * int(tmpl["defense_per_lv"]),
		"res_fire": mini(75, level), "res_cold": mini(75, level),
		"res_light": mini(75, level), "res_poison": mini(75, level),
	}
	var affixes := {}
	for slot in SLOTS:
		var item: Dictionary = equipment.get(slot, {})
		if item.is_empty() or not item_script.is_identified(item):
			continue
		if slot == "weapon" and not item_script.is_broken(item):
			result["dmg_min"] += int(item.get("dmin", 0))
			result["dmg_max"] += int(item.get("dmax", 0))
		elif slot in ["armor", "helm"] and not item_script.is_broken(item):
			result["defense"] += int(item.get("defense", 0))
		var effective: Dictionary = item_script.effective_affixes(item)
		for stat in effective:
			affixes[stat] = int(affixes.get(stat, 0)) + int(effective[stat])
	var enhanced_damage := int(affixes.get("ed", 0))
	result["dmg_min"] = maxi(1, roundi(float(result["dmg_min"]) * (1.0 + enhanced_damage / 100.0)))
	result["dmg_max"] = maxi(int(result["dmg_min"]), roundi(float(result["dmg_max"]) * (1.0 + enhanced_damage / 100.0)))
	result["attack_rating"] += int(affixes.get("ar", 0)) + int(affixes.get("dex", 0)) * 4
	result["defense"] += int(affixes.get("def", 0))
	result["life"] += int(affixes.get("life", 0)) + int(affixes.get("str", 0)) * 2
	var all_res := int(affixes.get("res_all", 0))
	for element in ["fire", "cold", "light", "poison"]:
		var key: String = "res_" + element
		result[key] = clampi(int(result[key]) + all_res + int(affixes.get(key, 0)), -100, 75)
	return result

static func selftest() -> bool:
	var ok := true
	ok = ok and normalize_type("nonsense") == TYPE_ORDER[0]
	ok = ok and normalize_type("guard") == "guard"
	ok = ok and next_type("scout") == "guard" and next_type("guard") == "acolyte" and next_type("acolyte") == "scout"
	var empty_equip := empty_equipment()
	var scout_stats := stats(20, empty_equip, Item, "scout")
	var guard_stats := stats(20, empty_equip, Item, "guard")
	var acolyte_stats := stats(20, empty_equip, Item, "acolyte")
	# Guard is the melee tank: more life/defense than the ranged types at equal level.
	ok = ok and int(guard_stats["life"]) > int(scout_stats["life"]) and int(guard_stats["defense"]) > int(scout_stats["defense"])
	ok = ok and float(TYPES["guard"]["range"]) < float(TYPES["scout"]["range"])
	ok = ok and bool(TYPES["guard"]["melee"]) and not bool(TYPES["scout"]["melee"]) and not bool(TYPES["acolyte"]["melee"])
	ok = ok and String(TYPES["acolyte"]["element"]) == "cold" and String(TYPES["scout"]["element"]) == "fire"
	ok = ok and int(acolyte_stats["life"]) < int(scout_stats["life"])
	return ok
