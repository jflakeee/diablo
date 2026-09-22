extends Node

const OnlineAuthority := preload("res://online_authority.gd")
const PORT := 18910

var _peer: ENetMultiplayerPeer
var _authority := OnlineAuthority.new()
var _role := "server"
var _elapsed := 0.0
var _login_ok := false
var _position_ok := false
var _trade_ok := false
var _token := ""
var _account_id := "hero_a"
var _seen_remote := false
var _multi := false
var _logged_accounts := {}
var _position_accounts := {}
var _trade_accounts := {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_role = "client" if args.has("net_client") or args.has("net_client2") else "server"
	_account_id = "hero_b" if args.has("net_client2") else "hero_a"
	_multi = args.has("net_multi")
	if _role == "server":
		_authority.create_account("hero_a", ["rift_cleaver_a"], 0)
		_authority.create_account("hero_b", ["rift_cleaver_b"], 0)
		_authority.create_account("merchant", [], 500)
		_peer = ENetMultiplayerPeer.new()
		var error := _peer.create_server(PORT, 4)
		if error != OK:
			print("[NET][RESULT] role=server error=%d verdict=FAIL" % error)
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = _peer
		print("[NET] server listening port=%d" % PORT)
	else:
		_peer = ENetMultiplayerPeer.new()
		var error := _peer.create_client("127.0.0.1", PORT)
		if error != OK:
			print("[NET][RESULT] role=client error=%d verdict=FAIL" % error)
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = _peer
		multiplayer.connected_to_server.connect(func(): rpc_id(1, "request_login", _account_id))
		print("[NET] client connecting account=%s" % _account_id)

@rpc("any_peer", "reliable")
func request_login(account_id: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	var token := _authority.login(account_id)
	_login_ok = not token.is_empty()
	if _login_ok: _logged_accounts[account_id] = true
	rpc_id(sender, "login_result", token)
	for known_account in _authority.world_snapshot():
		if String(known_account) != "merchant":
			rpc_id(sender, "world_snapshot", String(known_account), _authority.world_snapshot()[known_account])

@rpc("authority", "reliable")
func login_result(token: String) -> void:
	_token = token
	_login_ok = not token.is_empty()
	var offset := 4.0 if _account_id == "hero_b" else 2.0
	rpc_id(1, "request_position", token, 1, Vector2(offset, 2))
	rpc_id(1, "request_trade", token, "tx-%s" % _account_id, "merchant", "rift_cleaver_%s" % _account_id.right(1), 125)

@rpc("any_peer", "reliable")
func request_position(token: String, sequence: int, position: Vector2) -> void:
	if not multiplayer.is_server(): return
	var result := _authority.update_position(token, sequence, position)
	_position_ok = bool(result.get("ok", false))
	var account_id := _authority.account_id_for_token(token)
	if _position_ok:
		_position_accounts[account_id] = true
		rpc("world_snapshot", account_id, position)
	rpc_id(multiplayer.get_remote_sender_id(), "position_result", _position_ok)

@rpc("authority", "reliable")
func position_result(ok: bool) -> void:
	_position_ok = ok

@rpc("authority", "reliable")
func world_snapshot(account_id: String, _position: Vector2) -> void:
	if account_id != _account_id:
		_seen_remote = true

@rpc("any_peer", "reliable")
func request_trade(token: String, transaction_id: String, buyer_id: String, item_id: String, price: int) -> void:
	if not multiplayer.is_server(): return
	var result := _authority.trade(token, transaction_id, buyer_id, item_id, price)
	_trade_ok = bool(result.get("ok", false))
	if _trade_ok: _trade_accounts[_authority.account_id_for_token(token)] = true
	rpc_id(multiplayer.get_remote_sender_id(), "trade_result", _trade_ok, transaction_id)

@rpc("authority", "reliable")
func trade_result(ok: bool, transaction_id: String) -> void:
	_trade_ok = ok and transaction_id == "tx-%s" % _account_id

func _process(delta: float) -> void:
	_elapsed += delta
	var limit := 25.0 if _role == "server" else 8.0
	if _elapsed < limit: return
	var ok: bool
	if _role == "server" and _multi:
		ok = _logged_accounts.size() == 2 and _position_accounts.size() == 2 and _trade_accounts.size() == 2
	elif _role == "client" and _multi:
		ok = _login_ok and _position_ok and _trade_ok and _seen_remote
	else:
		ok = _login_ok and _position_ok and _trade_ok
	print("[NET][RESULT] role=%s account=%s login=%s position=%s escrow=%s remote=%s peers=%d verdict=%s" % [_role, _account_id, str(_login_ok), str(_position_ok), str(_trade_ok), str(_seen_remote), _logged_accounts.size(), "PASS" if ok else "FAIL"])
	if _peer != null:
		_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().quit(0 if ok else 1)
