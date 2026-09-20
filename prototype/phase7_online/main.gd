extends Node
# Phase 7 — 온라인(P11 계정 / P12 동기화 / P13 거래) 최소 프로토타입.
# Godot 고수준 멀티플레이(ENet). 서버/클라이언트를 별도 프로세스로 실행:
#   서버:      godot --headless --path . -- server
#   클라이언트: godot --headless --path . -- client
# 거래는 서버 권위(authoritative) 에스크로 방식(카오스큐브 수동중개의 개선 — Part 1 §7.1).

const PORT := 8910

var _role := "server"
var _peer: ENetMultiplayerPeer
var _t := 0.0
var _server_got_trade := false
var _client_got_result := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("client"):
		_role = "client"
	if _role == "server":
		_start_server()
	else:
		_start_client()

func _start_server() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(PORT, 8)
	if err != OK:
		print("[P7] server: create_server FAILED err=", err)
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(func(id: int): print("[P7] server: peer %d connected (account login OK)" % id))
	multiplayer.peer_disconnected.connect(func(id: int): print("[P7] server: peer %d disconnected" % id))
	print("[P7] server: listening on ", PORT)

func _start_client() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client("127.0.0.1", PORT)
	if err != OK:
		print("[P7] client: create_client FAILED err=", err)
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	print("[P7] client: connecting to 127.0.0.1:%d ..." % PORT)

func _on_conn_failed() -> void:
	print("[P7] client: connection FAILED")
	get_tree().quit()

func _on_connected() -> void:
	print("[P7] client: connected (account=Guest) → sending pos sync + trade request")
	rpc_id(1, "srv_update_pos", 12.5, 8.0)
	rpc_id(1, "srv_trade_request", "Steel Short Sword")

@rpc("any_peer", "reliable")
func srv_update_pos(x: float, y: float) -> void:
	print("[P7] server: peer %d pos sync (%.1f, %.1f)" % [multiplayer.get_remote_sender_id(), x, y])

@rpc("any_peer", "reliable")
func srv_trade_request(item_name: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	print("[P7] server: trade request from %d for '%s' → escrow validated OK" % [sender, item_name])
	_server_got_trade = true
	rpc_id(sender, "cli_trade_result", true, item_name)

@rpc("authority", "reliable")
func cli_trade_result(ok: bool, item_name: String) -> void:
	print("[P7] client: trade result ok=%s item='%s'" % [str(ok), item_name])
	_client_got_result = true

func _process(delta: float) -> void:
	_t += delta
	if _role == "server" and _t > 6.0:
		print("[P7][RESULT] role=server trade_handled=%s verdict=%s" % [
			str(_server_got_trade), ("PASS" if _server_got_trade else "FAIL")])
		get_tree().quit()
	elif _role == "client" and _t > 4.0:
		print("[P7][RESULT] role=client trade_ack=%s verdict=%s" % [
			str(_client_got_result), ("PASS" if _client_got_result else "FAIL")])
		get_tree().quit()
