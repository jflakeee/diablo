extends SceneTree

# Production UI/casting paths in an isolated fixture; never reads or writes the
# player's save. --headless --script res://tools/progression_combat_test.gd
const Main := preload("res://main.gd")
const Actor := preload("res://actor.gd")
const FX := preload("res://combat_fx.gd")
const Item := preload("res://item.gd")
const Skills := preload("res://skills.gd")
const SystemTests := preload("res://system_tests.gd")
const SaveStore := preload("res://save_store.gd")
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text:
			return child
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _run() -> void:
	var system := SystemTests.run()
	_check(bool(system["ok"]), "system suite: %s" % str(system["failures"]))
	var saves := SaveStore.selftest()
	_check(bool(saves["ok"]), "save suite: %s" % str(saves["failures"]))
	var game := Main.new()
	var player := Actor.new()
	player.is_player = true
	player.level = 20
	player.stat_str = 100
	player.stat_dex = 100
	player.skills = {"iron_chant": 1, "storm_lance": 1}
	game._player = player
	var target := Actor.new()
	player.gx = 2; player.gy = 2
	target.gx = 4; target.gy = 2
	target.res_fire = 100; target.res_light = 100
	target.life = 10000; target.max_life = 10000
	var fx := FX.new()
	root.add_child(fx)
	game._fx = fx
	var panel := VBoxContainer.new()
	root.add_child(panel)
	game._inv_vbox = panel
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var item := Item.generate(rng, Item.WEAPON_BASES[0], 12, "rare")
	item["identified"] = false
	game._inventory.append(item)
	game._rebuild_inv()
	game._equip_from_inventory(item)
	game._equip_merc_from_inventory(item)
	_check(game._equipped["weapon"].is_empty() and game._merc_equipped["weapon"].is_empty(), "unidentified equip paths reject")
	game._sell_all()
	game._sell_inventory_item(item)
	_check(game._inventory.has(item), "unidentified batch and single sale protected")
	var identify := _find_button(panel, "Identify (Free)")
	_check(identify != null, "identification entry in Bag")
	if identify != null:
		identify.pressed.emit()
		identify.pressed.emit()
	_check(Item.is_identified(item) and game._item_event_history.size() == 1 and game._inventory.has(item), "real identify signal and duplicate input")
	_check(_find_button(panel, "Identify (Free)") == null, "identify button removed after reveal")
	game._equip_from_inventory(item)
	_check(game._equipped["weapon"] == item and not game._inventory.has(item), "identified item can equip")
	game._equip_from_inventory(item)
	_check(game._inventory.is_empty(), "stale equip does not duplicate gear")
	for y in 20:
		var row := PackedInt32Array()
		row.resize(20)
		row.fill(1)
		game._grid.append(row)
	player.bo_timer = 10.0
	_check(game._target_resist(target, "fire") == 96, "nearby aura breaks 100 immunity at one-fifth potency")
	target.gx = 8.01
	_check(game._target_resist(target, "fire") == 100, "aura stops beyond six tiles")
	target.gx = 8.0
	_check(game._target_resist(target, "fire") == 96, "aura includes radius boundary")
	target.gx = 4
	game._grid[2][3] = 0
	_check(game._target_resist(target, "fire") == 100, "aura blocked by wall")
	var mana_before := player.mana
	game._cast_storm_lance(target)
	_check(target.hex_timer == 0.0 and player.mana == mana_before and player.attack_cd == 0.0, "blocked lance spends nothing")
	game._grid[2][3] = 1
	game._in_town = true
	_check(game._target_resist(target, "fire") == 100, "aura inactive in town")
	game._in_town = false
	player.bo_timer = 0.0
	_check(game._target_resist(target, "fire") == 100, "expired aura no longer reduces resistance")
	player.mana = 0
	game._cast_storm_lance(target)
	_check(target.hex_timer == 0.0, "no mana cannot apply hex")
	player.mana = 20
	var life_before := target.life
	game._cast_storm_lance(target)
	_check(target.hex_timer == 6.0 and target.hex_reduction == 32 and target.life < life_before and player.mana == 16, "cast applies hex before damage and charges mana")
	player.bo_timer = 10.0
	_check(game._target_resist(target, "fire") == 90, "hex and aura combine against original immunity")
	player.alive = false
	_check(game._target_resist(target, "fire") == 94, "dead caster aura disabled; hex persists")
	player.alive = true
	target.tick_hex(6.0)
	_check(game._target_resist(target, "fire") == 96 and target.res_fire == 100, "hex expiry retains aura without mutating base resistance")
	target.apply_hex(32, 6.0)
	game._monsters.append(target)
	game._capture_floor_state()
	var saved_target: Dictionary = game._floor_states[str(game._dlevel)]["monsters"][0]
	_check(float(saved_target.get("hex_timer", 0)) == 6.0 and int(saved_target.get("hex_reduction", 0)) == 32, "floor snapshot keeps hex state")
	_check(float(game._gather_save_state("test").get("iron_chant_timer", 0)) == 10.0, "player snapshot keeps aura duration")
	print("[PROGRESSION_COMBAT] system_checks=%d save_checks=%d failures=%s verdict=%s" % [system["checks"], saves["checks"], failures, "PASS" if failures.is_empty() else "FAIL"])
	fx.clear_all()
	game.free()
	player.free()
	target.free()
	panel.queue_free()
	fx.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
