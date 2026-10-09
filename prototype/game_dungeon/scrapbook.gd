extends RefCounted
# 장비 습득 시 발급되는 소모형 "복원 티켓" 보관함. 기존 습득→자동장착 흐름은
# 전혀 바뀌지 않는다 — 이 스크립트는 그 흐름과 별개로, 같은 베이스/등급/ilvl로
# 하나 더 뽑을 수 있는 영수증만 쌓아둔다. 복원(redeem)은 항상 수동이며,
# 복원된 아이템은 자동장착되지 않고 가방에 들어가 사용자가 직접 장착해야
# 한다. 상세: docs/superpowers/specs/2026-10-09-item-scrapbook-design.md

const RESTORE_BASE := {"normal": 15, "magic": 60, "rare": 160, "set": 350, "unique": 500}

var tickets: Array = []

func add_ticket(base_name: String, slot: String, quality: String, ilvl: int) -> void:
	if not RESTORE_BASE.has(quality):
		return
	tickets.append({"base_name": base_name, "slot": slot, "quality": quality, "ilvl": ilvl})

func cost(ticket: Dictionary) -> int:
	var base_cost: int = int(RESTORE_BASE.get(String(ticket.get("quality", "")), 0))
	var ilvl := int(ticket.get("ilvl", 1))
	return roundi(float(base_cost) * (1.0 + float(ilvl) / 20.0))

func can_restore(ticket: Dictionary, gold: int) -> bool:
	return tickets.has(ticket) and gold >= cost(ticket)

# item_script는 main.gd가 항상 Item(item.gd)을 넘긴다 — craft.gd의 기존
# 의존성 주입 패턴(reroll/add_sockets가 item_script: GDScript를 받는 것)과
# 동일하게 맞춰 scrapbook.gd가 item.gd를 직접 preload하지 않도록 했다.
func redeem(rng: RandomNumberGenerator, ticket: Dictionary, item_script: GDScript) -> Dictionary:
	if not tickets.has(ticket):
		return {}
	var base: Dictionary = item_script.find_base(String(ticket.get("base_name", "")), String(ticket.get("slot", "")))
	if base.is_empty():
		return {}
	tickets.erase(ticket)
	return item_script.generate(rng, base, int(ticket.get("ilvl", 1)), String(ticket.get("quality", "")))

func snapshot() -> Dictionary:
	return {"tickets": tickets.duplicate(true)}

func restore(raw: Variant) -> void:
	if not raw is Dictionary:
		return
	tickets = ((raw as Dictionary).get("tickets", []) as Array).duplicate(true)

func selftest() -> bool:
	var item_script := load("res://item.gd")
	add_ticket("Short Sword", "weapon", "magic", 15)
	var ok := tickets.size() == 1
	var ticket: Dictionary = tickets[0]
	var expected_cost := roundi(60.0 * (1.0 + 15.0 / 20.0))
	ok = ok and cost(ticket) == expected_cost
	ok = ok and not can_restore(ticket, expected_cost - 1)
	ok = ok and can_restore(ticket, expected_cost)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var redeemed := redeem(rng, ticket, item_script)
	ok = ok and not redeemed.is_empty() and String(redeemed.get("quality", "")) == "magic" and tickets.is_empty()
	ok = ok and redeem(rng, ticket, item_script).is_empty()
	add_ticket("Hand Axe", "weapon", "unique", 10)
	var saved := snapshot()
	tickets.clear()
	restore(saved)
	ok = ok and tickets.size() == 1 and String(tickets[0]["quality"]) == "unique"
	return ok
