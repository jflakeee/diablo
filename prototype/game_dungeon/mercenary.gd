extends RefCounted

const SLOTS := ["weapon", "armor"]

static func empty_equipment() -> Dictionary:
	return {"weapon": {}, "armor": {}}

static func normalize_equipment(raw) -> Dictionary:
	var equipment := empty_equipment()
	if not raw is Dictionary:
		return equipment
	for slot in SLOTS:
		var item = raw.get(slot, {})
		if item is Dictionary and not (item as Dictionary).is_empty() and String(item.get("slot", "")) == slot:
			equipment[slot] = (item as Dictionary).duplicate(true)
	return equipment

static func strength(level: int) -> int:
	return 20 + maxi(1, level) * 3

static func dexterity(level: int) -> int:
	return 15 + maxi(1, level) * 2

static func can_equip(item: Dictionary, level: int = 99) -> bool:
	return String(item.get("slot", "")) in SLOTS and level >= int(item.get("req_level", 1)) and strength(level) >= int(item.get("req_str", 0)) and dexterity(level) >= int(item.get("req_dex", 0))

static func stats(level: int, equipment: Dictionary, item_script: GDScript) -> Dictionary:
	var result := {
		"life": 60 + level * 22, "attack_rating": 120 + level * 18,
		"dmg_min": 6 + level * 2, "dmg_max": 12 + level * 3,
		"defense": 20 + level * 3,
		"res_fire": mini(75, level), "res_cold": mini(75, level),
		"res_light": mini(75, level), "res_poison": mini(75, level),
	}
	var affixes := {}
	for slot in SLOTS:
		var item: Dictionary = equipment.get(slot, {})
		if item.is_empty():
			continue
		if slot == "weapon" and not item_script.is_broken(item):
			result["dmg_min"] += int(item.get("dmin", 0))
			result["dmg_max"] += int(item.get("dmax", 0))
		elif slot == "armor" and not item_script.is_broken(item):
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
