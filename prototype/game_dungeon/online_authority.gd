extends RefCounted

const MAX_STEP := 6.0

var _accounts := {}
var _sessions := {}
var _transactions := {}
var _next_token := 1000

func create_account(account_id: String, inventory: Array = [], gold: int = 0) -> bool:
	if account_id.is_empty() or _accounts.has(account_id):
		return false
	_accounts[account_id] = {"inventory": inventory.duplicate(true), "gold": maxi(gold, 0), "position": Vector2.ZERO, "last_seq": -1}
	return true

func login(account_id: String) -> String:
	if not _accounts.has(account_id):
		return ""
	_next_token += 1
	var token := "%s-%d" % [account_id, _next_token]
	_sessions[token] = account_id
	return token

func reconnect(account_id: String, token: String) -> bool:
	return String(_sessions.get(token, "")) == account_id and _accounts.has(account_id)

func update_position(token: String, sequence: int, requested: Vector2) -> Dictionary:
	var account_id := String(_sessions.get(token, ""))
	if account_id.is_empty():
		return {"ok": false, "reason": "invalid_session"}
	var state: Dictionary = _accounts[account_id]
	if sequence <= int(state["last_seq"]):
		return {"ok": false, "reason": "stale_sequence"}
	var current: Vector2 = state["position"]
	if current.distance_to(requested) > MAX_STEP:
		return {"ok": false, "reason": "movement_limit", "position": current}
	state["position"] = requested
	state["last_seq"] = sequence
	return {"ok": true, "position": requested, "sequence": sequence}

func trade(token: String, transaction_id: String, buyer_id: String, item_id: String, price: int) -> Dictionary:
	if _transactions.has(transaction_id):
		return (_transactions[transaction_id] as Dictionary).duplicate(true)
	var seller_id := String(_sessions.get(token, ""))
	var result := {"ok": false, "transaction_id": transaction_id, "reason": "invalid"}
	if transaction_id.is_empty() or seller_id.is_empty() or not _accounts.has(buyer_id) or price < 0:
		_transactions[transaction_id] = result
		return result.duplicate(true)
	var seller: Dictionary = _accounts[seller_id]
	var buyer: Dictionary = _accounts[buyer_id]
	var inventory: Array = seller["inventory"]
	if not inventory.has(item_id):
		result["reason"] = "not_owner"
	elif int(buyer["gold"]) < price:
		result["reason"] = "insufficient_gold"
	else:
		inventory.erase(item_id)
		(buyer["inventory"] as Array).append(item_id)
		buyer["gold"] = int(buyer["gold"]) - price
		seller["gold"] = int(seller["gold"]) + price
		result = {"ok": true, "transaction_id": transaction_id, "item_id": item_id, "price": price}
	_transactions[transaction_id] = result
	return result.duplicate(true)

func account_snapshot(account_id: String) -> Dictionary:
	return (_accounts.get(account_id, {}) as Dictionary).duplicate(true)

func account_id_for_token(token: String) -> String:
	return String(_sessions.get(token, ""))

func world_snapshot() -> Dictionary:
	var snapshot := {}
	for account_id in _accounts:
		snapshot[account_id] = (_accounts[account_id] as Dictionary).get("position", Vector2.ZERO)
	return snapshot

static func selftest() -> Dictionary:
	var failures: Array = []
	var authority = load("res://online_authority.gd").new()
	authority.create_account("hero", ["rift_cleaver"], 0)
	authority.create_account("merchant", [], 500)
	var token: String = authority.login("hero")
	if token.is_empty() or not authority.reconnect("hero", token): failures.append("session reconnect")
	if not bool(authority.update_position(token, 1, Vector2(3, 2)).get("ok", false)): failures.append("position accept")
	if bool(authority.update_position(token, 1, Vector2(4, 2)).get("ok", false)): failures.append("sequence replay")
	if bool(authority.update_position(token, 2, Vector2(100, 2)).get("ok", false)): failures.append("movement authority")
	var trade_a: Dictionary = authority.trade(token, "tx-1", "merchant", "rift_cleaver", 125)
	var trade_b: Dictionary = authority.trade(token, "tx-1", "merchant", "rift_cleaver", 125)
	if not bool(trade_a.get("ok", false)) or trade_a != trade_b: failures.append("idempotent escrow")
	var hero: Dictionary = authority.account_snapshot("hero")
	var merchant: Dictionary = authority.account_snapshot("merchant")
	if int(hero.get("gold", 0)) != 125 or not (merchant.get("inventory", []) as Array).has("rift_cleaver"): failures.append("atomic ownership")

	var load_authority = load("res://online_authority.gd").new()
	load_authority.create_account("market", [], 20000)
	var monotonic := true
	for index in 100:
		var account_id := "load_%03d" % index
		var item_id := "item_%03d" % index
		load_authority.create_account(account_id, [item_id], 0)
		var load_token: String = load_authority.login(account_id)
		for sequence in [1, 2, 4, 5]: # sequence 3 is intentionally lost
			load_authority.update_position(load_token, sequence, Vector2(sequence, 0))
		var replay: Dictionary = load_authority.update_position(load_token, 2, Vector2(2, 0))
		monotonic = monotonic and not bool(replay.get("ok", false))
		var tx_id := "load-tx-%03d" % index
		load_authority.trade(load_token, tx_id, "market", item_id, 125)
		load_authority.trade(load_token, tx_id, "market", item_id, 125) # duplicated packet
	if not monotonic: failures.append("loss replay monotonicity")
	var market: Dictionary = load_authority.account_snapshot("market")
	if int(market.get("gold", -1)) != 7500 or (market.get("inventory", []) as Array).size() != 100: failures.append("100 account conservation")
	return {"ok": failures.is_empty(), "checks": 8, "failures": failures}
