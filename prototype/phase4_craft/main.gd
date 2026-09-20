extends Node2D
# Phase 3 — 아이템 + 접사 + 드롭 + 인벤토리 (P4+P6+P9)
# 수직 슬라이스 완성점: 이동 → 전투 → 드롭 → 줍기 → 장착 → 스탯 변화.
# 실행: godot --path . --rendering-driver opengl3   (검증: "-- autoquit")

const JoystickScript := preload("res://virtual_joystick.gd")
const SkillButtonScript := preload("res://skill_button.gd")
const ActorScript := preload("res://actor.gd")
const CombatLib := preload("res://combat.gd")
const Skills := preload("res://skills.gd")
const Item := preload("res://item.gd")
const Craft := preload("res://craft.gd")

const TILE_W := 64
const TILE_H := 32
const GRID := 20
const ATTACK_RANGE := 1.5
const PLAYER_ATTACK_CD := 0.45
const MONSTER_ATTACK_CD := 1.2
const MANA_REGEN := 4.0
const PICKUP_RANGE := 1.1

var _world: Node2D
var _cam: Camera2D
var _player: ActorScript
var _monsters: Array = []
var _ground: Array = []
var _blocked := {}
var _attack_line: Line2D
var _attack_ttl := 0.0

var _joy: JoystickScript
var _hud: Label
var _inv_panel: Panel
var _inv_vbox: VBoxContainer
var _rng := RandomNumberGenerator.new()
var _combat_log := "-"
var _mana_acc := 0.0

var _inventory: Array = []
var _equipped := {"weapon": {}, "armor": {}}
var _eq := {"str": 0, "dex": 0, "ar": 0, "ed": 0, "life": 0, "mana": 0, "def": 0, "res_all": 0}
var _player_mf := 50

var _logic_ticks := 0
var _attacks := 0
var _hits := 0
var _kills := 0
var _bo_casts := 0
var _bo_done := false
var _items_dropped := 0
var _items_picked := 0
var _run_start := 0
var _auto_quit := false

func _iso(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * TILE_W * 0.5, (gx + gy) * TILE_H * 0.5)

func _screen_dir_to_grid(v: Vector2) -> Vector2:
	if v.length() < 0.05:
		return Vector2.ZERO
	var gx := (v.x / (TILE_W * 0.5) + v.y / (TILE_H * 0.5)) * 0.5
	var gy := (v.y / (TILE_H * 0.5) - v.x / (TILE_W * 0.5)) * 0.5
	return Vector2(gx, gy).normalized()

func _tex_rect(w: int, h: int, col: Color) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)

func _tex_diamond(w: int, h: int, col: Color) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx := absf(x - w / 2.0) / (w / 2.0)
			var dy := absf(y - h / 2.0) / (h / 2.0)
			if dx + dy <= 1.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _walkable(gx: float, gy: float) -> bool:
	var ix := int(round(gx))
	var iy := int(round(gy))
	if ix < 1 or ix > GRID - 2 or iy < 1 or iy > GRID - 2:
		return false
	return not _blocked.has(Vector2i(ix, iy))

func _make_actor(nm: String, col: Color, w: int, h: int) -> ActorScript:
	var a := ActorScript.new()
	a.actor_name = nm
	a.setup(_tex_rect(w, h, col))
	_world.add_child(a)
	return a

func _ready() -> void:
	_auto_quit = OS.get_cmdline_user_args().has("autoquit")
	_run_start = Time.get_ticks_msec()
	_rng.randomize()

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	for b in [Vector2i(7, 7), Vector2i(12, 6), Vector2i(13, 13), Vector2i(6, 13)]:
		_blocked[b] = true

	var floor_tex := _tex_diamond(TILE_W, TILE_H, Color(0.22, 0.45, 0.28))
	var wall_tex := _tex_diamond(TILE_W, TILE_H, Color(0.35, 0.33, 0.30))
	for gx in GRID:
		for gy in GRID:
			var edge := gx == 0 or gy == 0 or gx == GRID - 1 or gy == GRID - 1
			var s := Sprite2D.new()
			s.texture = wall_tex if (edge or _blocked.has(Vector2i(gx, gy))) else floor_tex
			s.position = _iso(gx, gy)
			s.y_sort_enabled = false
			_world.add_child(s)

	_player = _make_actor("Barbarian", Color(0.9, 0.75, 0.2), 22, 34)
	_player.is_player = true
	_player.level = 1
	_player.stat_str = 30
	_player.stat_dex = 25
	_player.stat_vit = 25
	_player.stat_energy = 15
	_player.max_life = CombatLib.barbarian_max_life(_player.stat_vit, _player.level)
	_player.base_max_life = _player.max_life
	_player.life = _player.max_life
	_player.max_mana = CombatLib.barbarian_max_mana(_player.stat_energy, _player.level)
	_player.base_max_mana = _player.max_mana
	_player.mana = _player.max_mana
	_player.speed = 6.0
	_player.gx = 10.0
	_player.gy = 10.0
	_player.position = _iso(_player.gx, _player.gy)
	_player.skills = {"bash": 1, "berserk": 1, "battle_orders": 1, "mastery": 1}

	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.8, 4, 4)
	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.8, 15, 5)
	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.8, 5, 15)
	_spawn_monster("Zombie", Color(0.45, 0.55, 0.25), 24, 32, 4, 40, 80, 40, 2, 5, 2.4, 15, 15)
	_spawn_monster("Zombie", Color(0.45, 0.55, 0.25), 24, 32, 4, 40, 80, 40, 2, 5, 2.4, 3, 11)

	_attack_line = Line2D.new()
	_attack_line.width = 3.0
	_attack_line.default_color = Color(1, 1, 0.4, 0.9)
	_world.add_child(_attack_line)

	_cam = Camera2D.new()
	_cam.position = _player.position
	_cam.zoom = Vector2(1.1, 1.1)
	_world.add_child(_cam)
	_cam.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)
	var vp := get_viewport_rect().size
	_joy = JoystickScript.new()
	_joy.position = Vector2(40, vp.y - 260)
	ui.add_child(_joy)
	_add_skill_button(ui, "bash", "Bash", Color.ORANGE_RED, Vector2(vp.x - 110, vp.y - 120))
	_add_skill_button(ui, "berserk", "Bsrk", Color.CRIMSON, Vector2(vp.x - 210, vp.y - 120))
	_add_skill_button(ui, "battle_orders", "BO", Color.GOLD, Vector2(vp.x - 160, vp.y - 220))

	var bag := Button.new()
	bag.text = "Bag"
	bag.position = Vector2(vp.x - 90, 16)
	bag.pressed.connect(_toggle_bag)
	ui.add_child(bag)

	_inv_panel = Panel.new()
	_inv_panel.position = Vector2(vp.x - 380, 50)
	_inv_panel.size = Vector2(360, 430)
	_inv_panel.visible = false
	ui.add_child(_inv_panel)
	_inv_vbox = VBoxContainer.new()
	_inv_vbox.position = Vector2(10, 10)
	_inv_vbox.custom_minimum_size = Vector2(340, 410)
	_inv_panel.add_child(_inv_vbox)

	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 16)
	ui.add_child(_hud)

	# 시작 무기 장착 (Short Sword) — 이후 드롭으로 업그레이드
	_equip(Item.generate(_rng, Item.WEAPON_BASES[0], 1, "normal"))

	print("[P4] ready — life=%d dmg=%d-%d def=%d MF=%d" % [
		_player.max_life, _player.dmg_min, _player.dmg_max, _player.defense, _player_mf])
	_craft_selftest()

func _craft_selftest() -> void:
	# 1) 보석 소켓 → 스탯 (Perfect Ruby → armor +38 life)
	var arm := Item.make_socketed(Item.ARMOR_BASES[1], 3)
	Item.socket_insert(arm, {"kind": "gem", "id": "ruby"})
	var e1 := Item.effective_affixes(arm)
	var t1: bool = int(e1.get("life", 0)) >= 38
	print("[P4] gem  : Ruby→armor +life=%d (>=38) : %s" % [int(e1.get("life", 0)), str(t1)])

	# 2) 룬워드 Steel = Tir + El (weapon 2소켓)
	var wpn := Item.make_socketed(Item.WEAPON_BASES[0], 2)
	Item.socket_insert(wpn, {"kind": "rune", "id": "Tir"})
	Item.socket_insert(wpn, {"kind": "rune", "id": "El"})
	var e2 := Item.effective_affixes(wpn)
	var t2: bool = String(wpn.get("runeword", "")) == "Steel" and int(e2.get("ed", 0)) == 20
	print("[P4] rword: Tir+El → %s (ed=%d ar=%d) : %s" % [String(wpn.get("runeword", "")), int(e2.get("ed", 0)), int(e2.get("ar", 0)), str(t2)])

	# 3) 룬워드 순서 오류(El+Tir) → 미형성
	var wpn2 := Item.make_socketed(Item.WEAPON_BASES[0], 2)
	Item.socket_insert(wpn2, {"kind": "rune", "id": "El"})
	Item.socket_insert(wpn2, {"kind": "rune", "id": "Tir"})
	Item.effective_affixes(wpn2)
	var t3: bool = String(wpn2.get("runeword", "")) == ""
	print("[P4] order: El+Tir → runeword='%s' (없어야 함) : %s" % [String(wpn2.get("runeword", "")), str(t3)])

	# 4) 큐브: El×3 → Eld
	var up := Craft.upgrade_rune("El")
	var t4: bool = up == "Eld"
	print("[P4] cube : El×3 → %s (Eld) : %s" % [up, str(t4)])

	print("[P4][RESULT] craft_selftest verdict=", ("PASS" if (t1 and t2 and t3 and t4) else "FAIL"))

func _add_skill_button(ui: CanvasLayer, id: String, label: String, col: Color, pos: Vector2) -> void:
	var b := SkillButtonScript.new()
	b.skill_id = id
	b.label_text = label
	b.color = col
	b.position = pos
	b.used.connect(_on_skill_used)
	ui.add_child(b)

func _spawn_monster(nm: String, col: Color, w: int, h: int, lvl: int, hp: int, ar: int, df: int, dmin: int, dmax: int, spd: float, gx: int, gy: int) -> void:
	var m := _make_actor(nm, col, w, h)
	m.level = lvl
	m.base_max_life = hp
	m.max_life = hp
	m.life = hp
	m.attack_rating = ar
	m.defense = df
	m.dmg_min = dmin
	m.dmg_max = dmax
	m.speed = spd
	m.gx = gx
	m.gy = gy
	m.position = _iso(gx, gy)
	m.died.connect(_on_monster_died)
	_monsters.append(m)

func _physics_process(delta: float) -> void:
	_logic_ticks += 1
	if not _player.alive:
		return

	_mana_acc += MANA_REGEN * delta
	var whole := int(_mana_acc)
	if whole > 0:
		_player.mana = mini(_player.max_mana, _player.mana + whole)
		_mana_acc -= whole

	if _player.bo_timer > 0.0:
		_player.bo_timer -= delta
		if _player.bo_timer <= 0.0:
			_player.bo_pct = 0.0
			_recompute_vitals(_player)

	_player.attack_cd = maxf(0.0, _player.attack_cd - delta)

	if _auto_quit:
		_auto_play(delta)
	else:
		var dir := _screen_dir_to_grid(_joy.value if _joy else Vector2.ZERO)
		if dir != Vector2.ZERO:
			_walk_toward(_player.gx + dir.x, _player.gy + dir.y, delta)

	_check_pickup()

	for m in _monsters:
		if not m.alive:
			continue
		m.attack_cd = maxf(0.0, m.attack_cd - delta)
		var to := Vector2(_player.gx - m.gx, _player.gy - m.gy)
		if to.length() > ATTACK_RANGE:
			var step: Vector2 = to.normalized() * m.speed * delta
			if _walkable(m.gx + step.x, m.gy):
				m.gx += step.x
			if _walkable(m.gx, m.gy + step.y):
				m.gy += step.y
			m.position = _iso(m.gx, m.gy)
		elif m.attack_cd <= 0.0:
			_monster_attack(m)
			m.attack_cd = MONSTER_ATTACK_CD

func _walk_toward(tx: float, ty: float, delta: float) -> void:
	var st: Vector2 = (Vector2(tx, ty) - Vector2(_player.gx, _player.gy))
	if st.length() < 0.001:
		return
	st = st.normalized() * _player.speed * delta
	if _walkable(_player.gx + st.x, _player.gy):
		_player.gx += st.x
	if _walkable(_player.gx, _player.gy + st.y):
		_player.gy += st.y
	_player.position = _iso(_player.gx, _player.gy)

func _auto_play(delta: float) -> void:
	if not _bo_done:
		_cast_battle_orders()
		_bo_done = true
	var tgt := _nearest_monster()
	if tgt != null:
		var dd := Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy))
		if dd <= ATTACK_RANGE:
			if _player.attack_cd <= 0.0:
				_player_attack(tgt, "bash")
		else:
			_walk_toward(tgt.gx, tgt.gy, delta)
		return
	var gi := _nearest_ground()
	if gi != null:
		_walk_toward(float(gi.get_meta("gx")), float(gi.get_meta("gy")), delta)

func _check_pickup() -> void:
	for n in _ground.duplicate():
		if not is_instance_valid(n):
			_ground.erase(n)
			continue
		var d := Vector2(_player.gx, _player.gy).distance_to(Vector2(float(n.get_meta("gx")), float(n.get_meta("gy"))))
		if d < PICKUP_RANGE:
			_pickup(n)

func _process(delta: float) -> void:
	if _cam:
		_cam.position = _cam.position.lerp(_player.position, clampf(delta * 8.0, 0.0, 1.0))
	if _attack_ttl > 0.0:
		_attack_ttl -= delta
		if _attack_ttl <= 0.0:
			_attack_line.clear_points()

	var alive_cnt := 0
	for m in _monsters:
		if m.alive:
			alive_cnt += 1
	var wn := Item.display_name(_equipped["weapon"]) if not _equipped["weapon"].is_empty() else "-"
	var an := Item.display_name(_equipped["armor"]) if not _equipped["armor"].is_empty() else "-"
	var elapsed := float(Time.get_ticks_msec() - _run_start) / 1000.0
	_hud.text = "Barbarian Lv%d  Life %d/%d  Mana %d/%d\nWpn: %s (%d-%d)  Arm: %s  Def %d\nkills %d  drops %d  bag %d  MF %d\n%s\n(이동·Bash/Bsrk/BO·Bag)" % [
		_player.level, _player.life, _player.max_life, _player.mana, _player.max_mana,
		wn, _player.dmg_min, _player.dmg_max, an, _player.defense,
		_kills, _items_dropped, _inventory.size(), _player_mf, _combat_log]

	if _auto_quit and elapsed >= 6.0:
		# Phase 4 검증은 _craft_selftest([P4][RESULT])가 담당. 여기선 렌더+루프 무결만 확인.
		print("[P4B][RESULT] render+loop OK (ran %.0fs, kills=%d drops=%d, no error)" % [elapsed, _kills, _items_dropped])
		get_tree().quit()

func _nearest_monster() -> ActorScript:
	var best: ActorScript = null
	var bestd := 1.0e9
	for m in _monsters:
		if not m.alive:
			continue
		var d := Vector2(_player.gx, _player.gy).distance_to(Vector2(m.gx, m.gy))
		if d < bestd:
			bestd = d
			best = m
	return best

func _nearest_ground() -> Node:
	var best: Node = null
	var bestd := 1.0e9
	for n in _ground:
		if not is_instance_valid(n):
			continue
		var d := Vector2(_player.gx, _player.gy).distance_to(Vector2(float(n.get_meta("gx")), float(n.get_meta("gy"))))
		if d < bestd:
			bestd = d
			best = n
	return best

func _on_skill_used(id: String) -> void:
	if id == "battle_orders":
		_cast_battle_orders()
		return
	var tgt := _nearest_monster()
	if tgt == null:
		_combat_log = "no target"
		return
	if Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy)) > ATTACK_RANGE + 0.6:
		_combat_log = "out of range"
		return
	_player_attack(tgt, id)

func _player_attack(target: ActorScript, skill_id: String) -> void:
	if target == null or not target.alive or not _player.alive or _player.attack_cd > 0.0:
		return
	var m_lvl := _player.skill_level("mastery")
	var s_lvl := _player.skill_level(skill_id)
	var use_skill := s_lvl > 0 and _player.spend_mana(Skills.mana_cost(skill_id))
	var ar_bonus := Skills.mastery_ar_pct(m_lvl)
	var dmg_bonus := Skills.mastery_damage_pct(m_lvl) + float(_eq["ed"])
	var ignore_def := false
	var label := "Attack"
	if use_skill:
		label = Skills.def_name(skill_id)
		if skill_id == "bash":
			ar_bonus += Skills.bash_ar_pct(s_lvl)
			dmg_bonus += Skills.bash_damage_pct(s_lvl)
		elif skill_id == "berserk":
			dmg_bonus += Skills.berserk_damage_pct(s_lvl)
			ignore_def = true

	_player.attack_cd = PLAYER_ATTACK_CD
	var eff_dex := _player.stat_dex + int(_eq["dex"])
	var ar := CombatLib.character_ar(eff_dex, ar_bonus) + int(_eq["ar"])
	var def_val := 0 if ignore_def else int(target.defense)
	var chance := CombatLib.chance_to_hit(ar, def_val, _player.level, target.level)
	_attacks += 1
	if CombatLib.roll_hit(_rng, ar, def_val, _player.level, target.level):
		_hits += 1
		var dmg := CombatLib.physical_damage(_rng, _player.dmg_min, _player.dmg_max, dmg_bonus)
		var crit := CombatLib.roll_deadly_strike(_rng, Skills.mastery_deadly_strike(m_lvl))
		if crit:
			dmg *= 2
		target.take_damage(dmg)
		_spawn_text(target.position, ("%d!" % dmg) if crit else str(dmg), Color(1, 0.5, 0.2) if crit else Color(1, 0.9, 0.3))
		_combat_log = "%s→%s %d%s" % [label, target.actor_name, dmg, (" CRIT" if crit else "")]
		if not target.alive:
			_grant_xp(target.level * 40)
	else:
		_spawn_text(target.position, "miss", Color(0.85, 0.85, 0.85))
		_combat_log = "%s→%s MISS (%.0f%%)" % [label, target.actor_name, chance]
	_flash(_player.position, target.position)

func _monster_attack(m: ActorScript) -> void:
	_attacks += 1
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		var dmg := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
		_player.take_damage(dmg)
		_spawn_text(_player.position, str(dmg), Color(1, 0.4, 0.4))
	else:
		_spawn_text(_player.position, "miss", Color(0.85, 0.85, 0.85))

func _cast_battle_orders() -> void:
	var lvl := _player.skill_level("battle_orders")
	if lvl <= 0 or not _player.spend_mana(Skills.mana_cost("battle_orders")):
		return
	_player.bo_pct = Skills.bo_bonus_pct(lvl)
	_player.bo_timer = Skills.bo_duration(lvl)
	_recompute_vitals(_player)
	_bo_casts += 1
	_combat_log = "Battle Orders! +%.0f%%" % _player.bo_pct

func _recompute_vitals(a: ActorScript) -> void:
	var old_ml := a.max_life
	var old_mm := a.max_mana
	a.max_life = int(a.base_max_life * (1.0 + a.bo_pct / 100.0))
	a.max_mana = int(a.base_max_mana * (1.0 + a.bo_pct / 100.0))
	a.life = clampi(a.life + (a.max_life - old_ml), 0, a.max_life)
	a.mana = clampi(a.mana + (a.max_mana - old_mm), 0, a.max_mana)
	a.queue_redraw()

func _recompute_player() -> void:
	var eq := {"str": 0, "dex": 0, "ar": 0, "ed": 0, "life": 0, "mana": 0, "def": 0, "res_all": 0}
	for slot in ["weapon", "armor"]:
		var it: Dictionary = _equipped[slot]
		if it.is_empty():
			continue
		var eff := Item.effective_affixes(it)
		for stat in eff:
			eq[stat] = int(eq.get(stat, 0)) + int(eff[stat])
	_eq = eq
	var eff_dex := _player.stat_dex + int(eq["dex"])
	var arm_def := int(_equipped["armor"]["defense"]) if not _equipped["armor"].is_empty() else 0
	_player.defense = CombatLib.character_defense(eff_dex, 15) + arm_def + int(eq["def"])
	if not _equipped["weapon"].is_empty():
		_player.dmg_min = int(_equipped["weapon"]["dmin"])
		_player.dmg_max = int(_equipped["weapon"]["dmax"])
	else:
		_player.dmg_min = 1
		_player.dmg_max = 2
	_player.base_max_life = CombatLib.barbarian_max_life(_player.stat_vit, _player.level) + int(eq["life"])
	_player.base_max_mana = CombatLib.barbarian_max_mana(_player.stat_energy, _player.level) + int(eq["mana"])
	_recompute_vitals(_player)

func _grant_xp(amount: int) -> void:
	_player.xp += amount
	var need := _player.level * 100
	while _player.xp >= need and _player.level < 20:
		_player.xp -= need
		_player.level += 1
		_player.skills["mastery"] = _player.skill_level("mastery") + 1
		_recompute_player()
		_combat_log = "LEVEL UP → %d" % _player.level
		need = _player.level * 100

func _on_monster_died(m: Node) -> void:
	_kills += 1
	var it := Item.roll_drop(_rng, int(m.level), _player_mf)
	if not it.is_empty():
		_items_dropped += 1
		_spawn_ground(it, m.gx, m.gy)
		_combat_log = "%s dropped %s" % [m.actor_name, Item.display_name(it)]
	else:
		_combat_log = "%s slain" % m.actor_name

func _spawn_ground(it: Dictionary, gx: float, gy: float) -> void:
	var n := Node2D.new()
	var spr := Sprite2D.new()
	spr.texture = _tex_rect(14, 14, Item.quality_color(String(it["quality"])))
	n.add_child(spr)
	var lbl := Label.new()
	lbl.text = Item.display_name(it)
	lbl.position = Vector2(-30, -26)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Item.quality_color(String(it["quality"])))
	n.add_child(lbl)
	n.position = _iso(gx, gy)
	n.set_meta("item", it)
	n.set_meta("gx", gx)
	n.set_meta("gy", gy)
	_world.add_child(n)
	_ground.append(n)

func _pickup(n: Node) -> void:
	var it: Dictionary = n.get_meta("item")
	_inventory.append(it)
	_items_picked += 1
	_ground.erase(n)
	n.queue_free()
	_spawn_text(_player.position, "+" + Item.display_name(it), Item.quality_color(String(it["quality"])))
	if _auto_quit:
		_auto_equip(it)
	_rebuild_inv()

func _auto_equip(it: Dictionary) -> void:
	var slot := String(it["slot"])
	var cur: Dictionary = _equipped[slot]
	var better := cur.is_empty()
	if not better:
		if slot == "weapon":
			better = int(it["dmax"]) > int(cur["dmax"])
		else:
			better = int(it["defense"]) > int(cur["defense"])
	if better:
		_equip(it)

func _equip(it: Dictionary) -> void:
	_equipped[String(it["slot"])] = it
	_recompute_player()
	_combat_log = "equipped %s" % Item.display_name(it)
	_rebuild_inv()

func _toggle_bag() -> void:
	_inv_panel.visible = not _inv_panel.visible
	if _inv_panel.visible:
		_rebuild_inv()

func _rebuild_inv() -> void:
	if _inv_vbox == null:
		return
	for c in _inv_vbox.get_children():
		c.queue_free()
	var wn := Item.display_name(_equipped["weapon"]) if not _equipped["weapon"].is_empty() else "-"
	var an := Item.display_name(_equipped["armor"]) if not _equipped["armor"].is_empty() else "-"
	var head := Label.new()
	head.text = "Weapon: %s\nArmor: %s\n— Inventory (%d) — 클릭=장착" % [wn, an, _inventory.size()]
	_inv_vbox.add_child(head)
	for it in _inventory:
		var btn := Button.new()
		btn.text = "%s  [%s]" % [Item.display_name(it), Item.affix_text(it)]
		btn.add_theme_color_override("font_color", Item.quality_color(String(it["quality"])))
		var captured: Dictionary = it
		btn.pressed.connect(func(): _equip(captured))
		_inv_vbox.add_child(btn)

func _flash(from: Vector2, to: Vector2) -> void:
	_attack_line.clear_points()
	_attack_line.add_point(from)
	_attack_line.add_point(to)
	_attack_ttl = 0.18

func _spawn_text(pos: Vector2, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-8, -46)
	lbl.z_index = 100
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 18)
	_world.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -28), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.finished.connect(lbl.queue_free)
