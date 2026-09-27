extends RefCounted

const SLOTS_PER_PAGE := 8
const BASE_PAGE_COST := 10000

var records := {}
var stored: Array = []
var pages := 1

func accepts(it: Dictionary) -> bool:
	return String(it.get("quality", "")) in ["set", "unique"]

func item_id(it: Dictionary) -> String:
	var quality := String(it.get("quality", ""))
	if quality == "set":
		return "set:%s:%s" % [String(it.get("set_id", "unknown")), String(it.get("prefix", it.get("name", "unknown")))]
	return "unique:%s" % String(it.get("prefix", it.get("name", "unknown")))

func register(it: Dictionary, combat_power: float) -> bool:
	if not accepts(it):
		return false
	var id := item_id(it)
	var previous: Dictionary = records.get(id, {})
	var option_bests: Dictionary = (previous.get("option_bests", {}) as Dictionary).duplicate(true)
	for stat in (it.get("affixes", {}) as Dictionary):
		option_bests[stat] = maxi(int(option_bests.get(stat, 0)), int(it["affixes"][stat]))
	var best_power := maxf(float(previous.get("best_power", 0.0)), combat_power)
	records[id] = {
		"id": id, "name": String(it.get("prefix", it.get("name", id))),
		"base_name": String(it.get("name", "")), "quality": String(it.get("quality", "")),
		"set_name": String(it.get("set_name", "")), "slot": String(it.get("slot", "")),
		"found": int(previous.get("found", 0)) + 1, "best_power": best_power,
		"option_bests": option_bests,
	}
	return previous.is_empty()

func capacity() -> int:
	return pages * SLOTS_PER_PAGE

func next_page_cost() -> int:
	if pages == 1: return BASE_PAGE_COST
	if pages == 2: return 50000
	if pages == 3: return 200000
	return 200000 * int(pow(2.0, float(pages - 3)))

func buy_page(gold: int) -> int:
	var cost := next_page_cost()
	if gold < cost:
		return -1
	pages += 1
	return cost

func store(it: Dictionary) -> bool:
	if not accepts(it) or stored.size() >= capacity():
		return false
	it["salvage_protected"] = true
	stored.append(it)
	return true

func take(it: Dictionary) -> bool:
	if not stored.has(it):
		return false
	stored.erase(it)
	return true

func rankings() -> Array:
	var out: Array = records.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("best_power", 0.0)) > float(b.get("best_power", 0.0)))
	return out

func option_leaders() -> Dictionary:
	var leaders := {}
	for record in records.values():
		for stat in (record.get("option_bests", {}) as Dictionary):
			var value := int(record["option_bests"][stat])
			if not leaders.has(stat) or value > int(leaders[stat].get("value", 0)):
				leaders[stat] = {"value": value, "name": String(record.get("name", ""))}
	return leaders

func snapshot() -> Dictionary:
	return {"records": records.duplicate(true), "stored": stored.duplicate(true), "pages": pages}

func restore(raw: Variant) -> void:
	if not raw is Dictionary:
		return
	var state: Dictionary = raw
	records = (state.get("records", {}) as Dictionary).duplicate(true)
	stored = (state.get("stored", []) as Array).duplicate(true)
	pages = maxi(1, int(state.get("pages", 1)))
	if stored.size() > capacity():
		stored.resize(capacity())

func selftest() -> bool:
	var first := {"name": "Sword", "prefix": "Emberneedle", "quality": "unique", "slot": "weapon", "affixes": {"ed": 50, "ar": 40}}
	var better := first.duplicate(true)
	better["affixes"] = {"ed": 55, "ar": 30}
	var set_item := {"name": "Armor", "prefix": "Oathweave", "quality": "set", "slot": "armor", "set_id": "ember", "set_name": "Ember Oath", "affixes": {"def": 22}}
	var ok := register(first, 100.0) and not register(better, 120.0) and register(set_item, 90.0)
	ok = ok and int(records[item_id(first)]["found"]) == 2 and int(records[item_id(first)]["option_bests"]["ed"]) == 55
	ok = ok and String((rankings()[0] as Dictionary)["name"]) == "Emberneedle" and int(option_leaders()["def"]["value"]) == 22
	ok = ok and store(first) and bool(first["salvage_protected"]) and buy_page(BASE_PAGE_COST) == BASE_PAGE_COST and pages == 2
	var saved := snapshot()
	var restored = get_script().new()
	restored.restore(saved)
	return ok and restored.records.size() == 2 and restored.stored.size() == 1 and restored.pages == 2
