extends RefCounted
# 파밍 자동화 정책/저장소. UI나 월드 노드와 분리해 결정론적으로 검증한다.

const QUALITY_RANK := {"normal": 0, "magic": 1, "rare": 2, "set": 3, "unique": 4}

var pickup_min := "magic"
var equip_min := "rare"
var auction_min := "rare"
var potion_tier := {"health": 0, "mana": 0}
var materials := {}
var auctions: Array = []
var salvage := 0
var auto_sell := true
var sell_replaced_gear := true
var auto_sell_max_quality := "rare"
var keep_market_value := 10000

func rank(quality: String) -> int:
	return int(QUALITY_RANK.get(quality, 0))

func accepts(it: Dictionary) -> bool:
	var slot := String(it.get("slot", ""))
	if auto_sell and slot in ["weapon", "armor", "ring", "amulet"]:
		return true
	return slot in ["gold", "potion", "material", "skill_book", "vision_relic", "arc_flask"] or rank(String(it.get("quality", "normal"))) >= rank(pickup_min)

func should_auto_sell(it: Dictionary, sale_value: int, requirement_locked: bool) -> bool:
	if not auto_sell or requirement_locked or not bool(it.get("identified", true)) or bool(it.get("salvage_protected", false)):
		return false
	if not String(it.get("slot", "")) in ["weapon", "armor", "ring", "amulet"]:
		return false
	var quality := String(it.get("quality", "normal"))
	if quality in ["set", "unique"] or rank(quality) > rank(auto_sell_max_quality):
		return false
	return sale_value < keep_market_value

func snapshot() -> Dictionary:
	return {"pickup_min": pickup_min, "equip_min": equip_min, "auction_min": auction_min,
		"auto_sell": auto_sell, "sell_replaced_gear": sell_replaced_gear, "auto_sell_max_quality": auto_sell_max_quality,
		"keep_market_value": keep_market_value, "potion_tier": potion_tier.duplicate(true),
		"materials": materials.duplicate(true), "salvage": salvage}

func restore(raw: Variant) -> void:
	if not raw is Dictionary:
		return
	var state: Dictionary = raw
	pickup_min = String(state.get("pickup_min", pickup_min))
	equip_min = String(state.get("equip_min", equip_min))
	auction_min = String(state.get("auction_min", auction_min))
	auto_sell = bool(state.get("auto_sell", auto_sell))
	sell_replaced_gear = bool(state.get("sell_replaced_gear", sell_replaced_gear))
	auto_sell_max_quality = String(state.get("auto_sell_max_quality", auto_sell_max_quality))
	keep_market_value = maxi(0, int(state.get("keep_market_value", keep_market_value)))
	potion_tier = (state.get("potion_tier", potion_tier) as Dictionary).duplicate(true)
	materials = (state.get("materials", materials) as Dictionary).duplicate(true)
	salvage = maxi(0, int(state.get("salvage", salvage)))

func add_material(it: Dictionary) -> void:
	var id := String(it.get("id", it.get("name", "unknown")))
	materials[id] = int(materials.get(id, 0)) + int(it.get("amount", 1))

func potion_upgrade(ptype: String, tier: int) -> bool:
	if tier <= int(potion_tier.get(ptype, 0)):
		return false
	potion_tier[ptype] = tier
	return true

func item_score(it: Dictionary) -> int:
	if not bool(it.get("identified", true)):
		return 0
	var score := rank(String(it.get("quality", "normal"))) * 10000
	if String(it.get("slot", "")) == "weapon":
		score += int(it.get("dmax", 0)) * 100 + int(it.get("dmin", 0)) * 40
	else:
		score += int(it.get("defense", 0)) * 100
	for value in it.get("affixes", {}).values():
		score += int(value)
	return score

func should_equip(it: Dictionary, current: Dictionary) -> bool:
	return bool(it.get("identified", true)) and rank(String(it.get("quality", "normal"))) >= rank(equip_min) and (current.is_empty() or item_score(it) > item_score(current))

func list_auction(it: Dictionary, now: int, duration: int = 120) -> bool:
	if not bool(it.get("identified", true)) or rank(String(it.get("quality", "normal"))) < rank(auction_min):
		return false
	var entry := {"item": it.duplicate(true), "expires": now + duration, "protected": bool(it.get("salvage_protected", false))}
	auctions.append(entry)
	return true

func expire_auctions(now: int) -> int:
	var gained := 0
	for entry in auctions.duplicate():
		if int(entry["expires"]) > now:
			continue
		auctions.erase(entry)
		if not bool(entry["protected"]):
			var it: Dictionary = entry["item"]
			var amount := 1 + rank(String(it.get("quality", "normal")))
			salvage += amount
			gained += amount
	return gained

func selftest() -> bool:
	var rare := {"name": "Rare Axe", "slot": "weapon", "quality": "rare", "dmin": 3, "dmax": 12, "affixes": {"ed": 20}}
	var unique := {"name": "Unique Axe", "slot": "weapon", "quality": "unique", "dmin": 3, "dmax": 10, "affixes": {}}
	var set_item := {"name": "Set Axe", "slot": "weapon", "quality": "set", "dmin": 3, "dmax": 11, "affixes": {}}
	add_material({"id": "ruby", "amount": 999999, "slot": "material"})
	var ok := accepts(rare) and accepts({"slot": "armor", "quality": "normal"})
	ok = ok and int(materials["ruby"]) == 999999 and potion_upgrade("health", 2) and not potion_upgrade("health", 1)
	ok = ok and should_equip(unique, set_item) and should_equip(set_item, rare) and list_auction(rare, 10, 5)
	ok = ok and expire_auctions(14) == 0 and expire_auctions(15) == 3
	ok = ok and should_auto_sell(rare, 500, false) and not should_auto_sell(unique, 500, false) and not should_auto_sell(rare, 500, true)
	var saved := snapshot()
	auto_sell = false
	restore(saved)
	ok = ok and auto_sell
	return ok
