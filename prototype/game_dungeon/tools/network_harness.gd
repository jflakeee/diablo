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

func _ready() -> void:
	_role = "client" if OS.get_cmdline_user_args().has("net_client") else "server"
	if _role == "server":
		_authority.create_account("hero", ["rift_cleaver"], 0)
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
		multiplayer.connected_to_server.connect(func(): rpc_id(1, "request_login", "hero"))
		print("[NET] client connecting")

@rpc("any_peer", "reliable")
func request_login(account_id: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	var token := _authority.login(account_id)
	_login_ok = not token.is_empty()
	rpc_id(sender, "login_result", token)

@rpc("authority", "reliable")
func login_result(token: String) -> void:
	_token = token
	_login_ok = not token.is_empty()
	rpc_id(1, "request_position", token, 1, Vector2(3, 2))
	rpc_id(1, "request_trade", token, "tx-net-1", "merchant", "rift_cleaver", 125)

@rpc("any_peer", "reliable")
func request_position(token: String, sequence: int, position: Vector2) -> void:
	if not multiplayer.is_server(): return
	var result := _authority.update_position(token, sequence, position)
	_position_ok = bool(result.get("ok", false))
	rpc_id(multiplayer.get_remote_sender_id(), "position_result", _position_ok)

@rpc("authority", "reliable")
func position_result(ok: bool) -> void:
	_position_ok = ok

@rpc("any_peer", "reliable")
func request_trade(token: String, transaction_id: String, buyer_id: String, item_id: String, price: int) -> void:
	if not multiplayer.is_server(): return
	var result := _authority.trade(token, transaction_id, buyer_id, item_id, price)
	_trade_ok = bool(result.get("ok", false))
	rpc_id(multiplayer.get_remote_sender_id(), "trade_result", _trade_ok, transaction_id)

@rpc("authority", "reliable")
func trade_result(ok: bool, transaction_id: String) -> void:
	_trade_ok = ok and transaction_id == "tx-net-1"

func _process(delta: float) -> void:
	_elapsed += delta
	var limit := 20.0 if _role == "server" else 5.0
	if _elapsed < limit: return
	var ok := _login_ok and _position_ok and _trade_ok
	print("[NET][RESULT] role=%s login=%s position=%s escrow=%s verdict=%s" % [_role, str(_login_ok), str(_position_ok), str(_trade_ok), "PASS" if ok else "FAIL"])
	if _peer != null:
		_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().quit(0 if ok else 1)
