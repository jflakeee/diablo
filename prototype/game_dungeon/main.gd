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
const Data := preload("res://data.gd")
const LevelGen := preload("res://level_gen.gd")

var _grid: Array = []
var _astar: AStarGrid2D
var _gw := 45
var _gh := 45
var _ent_cell := Vector2i(1, 1)
var _exit_cell := Vector2i(1, 1)
var _tiles_node: Node2D
var _dlevel := 1
var _levels_cleared := 0

const TILE_W := 64
const TILE_H := 32
const GRID := 20
const ATTACK_RANGE := 1.5
const PLAYER_ATTACK_CD := 0.45
const MONSTER_ATTACK_CD := 1.2
const MANA_REGEN := 4.0
const PICKUP_RANGE := 1.1
const RANGED_RANGE := 5.0
const NOVA_RADIUS := 3.5
const SPELL_RANGE := 7.0
const FIREBALL_CD := 0.6

var _class := "barbarian"
var _projectiles: Array = []
var _spells_cast := 0
var _spell_hits := 0

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
var _boss: ActorScript
var _boss_melee_cnt := 0
var _boss_nova_cnt := 0
var _boss_spray_cnt := 0
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
	if ix < 0 or ix >= _gw or iy < 0 or iy >= _gh:
		return false
	return int(_grid[iy][ix]) == 1

func _make_actor(nm: String, col: Color, w: int, h: int) -> ActorScript:
	var a := ActorScript.new()
	a.actor_name = nm
	a.setup(_tex_rect(w, h, col))
	_world.add_child(a)
	return a

func _build_astar(w: int, h: int, grid: Array) -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in h:
		for x in w:
			if int(grid[y][x]) == 0:
				astar.set_point_solid(Vector2i(x, y), true)
	return astar

func _generate_dungeon() -> void:
	if is_instance_valid(_tiles_node):
		_tiles_node.queue_free()
	_tiles_node = Node2D.new()
	_world.add_child(_tiles_node)
	var lvl := LevelGen.generate(1000 + _dlevel)  # 레벨별 결정론적 시드
	_gw = int(lvl["w"])
	_gh = int(lvl["h"])
	_grid = lvl["grid"]
	_ent_cell = lvl["entrance"]
	_exit_cell = lvl["exit"]
	var floor_tex := _tex_diamond(TILE_W, TILE_H, Color(0.22, 0.42, 0.28))
	var wall_tex := _tex_diamond(TILE_W, TILE_H, Color(0.30, 0.28, 0.26))
	for y in _gh:
		for x in _gw:
			var s := Sprite2D.new()
			s.texture = floor_tex if int(_grid[y][x]) == 1 else wall_tex
			s.position = _iso(x, y)
			_tiles_node.add_child(s)
	var em := Sprite2D.new()
	em.texture = _tex_rect(16, 16, Color(0.95, 0.3, 0.3))
	em.position = _iso(_exit_cell.x, _exit_cell.y)
	em.z_index = 2
	_tiles_node.add_child(em)
	_astar = _build_astar(_gw, _gh, _grid)

func _random_floor_cell() -> Vector2i:
	for i in 300:
		var x := _rng.randi_range(1, _gw - 2)
		var y := _rng.randi_range(1, _gh - 2)
		if int(_grid[y][x]) == 1 and Vector2(x, y).distance_to(Vector2(_ent_cell.x, _ent_cell.y)) > 6.0:
			return Vector2i(x, y)
	return _exit_cell

func _spawn_dungeon_monsters() -> void:
	for m in _monsters:
		if is_instance_valid(m):
			m.queue_free()
	_monsters.clear()
	_boss = null
	var trash := 0
	for md in Data.monsters():
		var kind := String(md.get("kind", "melee"))
		if kind == "boss" and _dlevel < 3:
			continue  # 보스는 3레벨 이상에서만 등장(초반은 클리어→워프 데모)
		if kind != "boss":
			trash += 1
			if trash > 3:
				continue  # 초반 레벨 잡몹 3마리로 제한
		var col := Color(float(md["color"][0]), float(md["color"][1]), float(md["color"][2]))
		var cell := _random_floor_cell() if kind != "boss" else _random_floor_cell()
		var m := _spawn_monster(String(md["name"]), col, int(md["w"]), int(md["h"]), int(md["level"]), int(md["hp"]), int(md["ar"]), int(md["def"]), int(md["dmin"]), int(md["dmax"]), float(md["speed"]), cell.x, cell.y)
		if kind != "melee":
			m.set_meta("kind", kind)
		if kind == "boss":
			m.set_meta("nova_cd", float(md.get("nova_cd", 3.0)))
			m.set_meta("spray_cd", float(md.get("spray_cd", 1.5)))
			m.res_fire = -50   # 안다리엘 화염 약점 (Part 3 §4) → 파이어볼 150%
			_boss = m
		else:
			m.res_fire = int(md.get("res_fire", 0))

func _next_level() -> void:
	_levels_cleared += 1
	_dlevel += 1
	for g in _ground:
		if is_instance_valid(g):
			g.queue_free()
	_ground.clear()
	_projectiles.clear()
	_generate_dungeon()
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)
	_spawn_dungeon_monsters()
	if is_instance_valid(_cam):
		_cam.position = _player.position
	_combat_log = "▶ Dungeon Level %d" % _dlevel

# A* 내비게이션: actor를 (tgx,tgy)로 경로 따라 이동 (경로 400ms 캐시)
func _nav_toward(actor: ActorScript, tgx: float, tgy: float, delta: float) -> void:
	var d := Vector2(tgx - actor.gx, tgy - actor.gy)
	if d.length() <= 1.5:
		_step(actor, d.normalized(), delta)
		return
	var from := Vector2i(int(round(actor.gx)), int(round(actor.gy)))
	var to := Vector2i(int(round(tgx)), int(round(tgy)))
	var nxt := _path_next(actor, from, to)
	var dir := Vector2(nxt.x - actor.gx, nxt.y - actor.gy)
	if dir.length() < 0.01:
		dir = d
	_step(actor, dir.normalized(), delta)

func _path_next(actor: ActorScript, from: Vector2i, to: Vector2i) -> Vector2i:
	var now := Time.get_ticks_msec()
	var last := int(actor.get_meta("path_ms", 0))
	var cached_to: Vector2i = actor.get_meta("path_to", Vector2i(-1, -1))
	var path: Array = actor.get_meta("path", [])
	if to != cached_to or now - last > 400 or path.size() < 2:
		if _astar != null:
			path = _astar.get_id_path(from, to)
		actor.set_meta("path", path)
		actor.set_meta("path_to", to)
		actor.set_meta("path_ms", now)
	if path.size() >= 2:
		return path[1]
	return from

func _step(actor: ActorScript, dir: Vector2, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var nx: float = actor.gx + dir.x * actor.speed * delta
	var ny: float = actor.gy + dir.y * actor.speed * delta
	if _walkable(nx, actor.gy):
		actor.gx = nx
	if _walkable(actor.gx, ny):
		actor.gy = ny
	actor.position = _iso(actor.gx, actor.gy)

var _menu_layer: CanvasLayer
var _started := false
var _leech_total := 0

func _ready() -> void:
	_auto_quit = OS.get_cmdline_user_args().has("autoquit")
	if OS.get_cmdline_user_args().has("sorc"):
		_class = "sorceress"
		_start_game()
	elif OS.get_cmdline_user_args().has("barb"):
		_class = "barbarian"
		_start_game()
	elif _auto_quit:
		_start_game()
	else:
		_show_class_select()

func _show_class_select() -> void:
	_menu_layer = CanvasLayer.new()
	add_child(_menu_layer)
	var vp := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 1.0)
	bg.size = vp
	_menu_layer.add_child(bg)
	var title := Label.new()
	title.text = "DIABLO CLONE — Dungeon"
	title.add_theme_font_size_override("font_size", 44)
	title.position = Vector2(vp.x * 0.5 - 240, vp.y * 0.2)
	_menu_layer.add_child(title)
	var sub := Label.new()
	sub.text = "클래스 선택 / Choose your class"
	sub.add_theme_font_size_override("font_size", 22)
	sub.position = Vector2(vp.x * 0.5 - 160, vp.y * 0.2 + 60)
	_menu_layer.add_child(sub)
	_add_class_button("⚔  Barbarian  — 근접 · 탱커", Color(0.9, 0.75, 0.2), Vector2(vp.x * 0.5 - 220, vp.y * 0.45), "barbarian")
	_add_class_button("✦  Sorceress  — 원거리 · 스펠", Color(0.6, 0.5, 0.95), Vector2(vp.x * 0.5 - 220, vp.y * 0.45 + 96), "sorceress")

func _add_class_button(text: String, col: Color, pos: Vector2, cls: String) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(440, 74)
	btn.size = Vector2(440, 74)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(_choose_class.bind(cls))
	_menu_layer.add_child(btn)

func _choose_class(cls: String) -> void:
	_class = cls
	if is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
	_start_game()

func _start_game() -> void:
	_started = true
	_run_start = Time.get_ticks_msec()
	if _auto_quit:
		_rng.seed = 42  # 검증 재현성
	else:
		_rng.randomize()

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_generate_dungeon()

	if _class == "sorceress":
		_player = _make_actor("Sorceress", Color(0.5, 0.35, 0.85), 20, 32)
		_player.stat_str = 10
		_player.stat_dex = 15
		_player.stat_vit = 20
		_player.stat_energy = 35
		_player.max_life = 40 + 2 * _player.stat_vit + 1  # Part 1 §2
		_player.max_mana = 35 + 2 * _player.stat_energy + 2
		_player.speed = 5.5
		_player.skills = {"fireball": 3, "static": 1, "teleport": 1}
		_player.res_fire = 30    # 소서리스 화염 저항
		_player.leech_pct = 8    # 스펠 생명 흡혈 8%
	else:
		_player = _make_actor("Barbarian", Color(0.9, 0.75, 0.2), 22, 34)
		_player.stat_str = 30
		_player.stat_dex = 25
		_player.stat_vit = 25
		_player.stat_energy = 15
		_player.max_life = CombatLib.barbarian_max_life(25, 1)
		_player.max_mana = CombatLib.barbarian_max_mana(15, 1)
		_player.speed = 6.0
		_player.skills = {"bash": 1, "berserk": 1, "battle_orders": 1, "mastery": 1}
		_player.block_val = 30   # 방패 블록
		_player.leech_pct = 6    # 물리 생명 흡혈 6%
	_player.is_player = true
	_player.level = 1
	_player.base_max_life = _player.max_life
	_player.life = _player.max_life
	_player.base_max_mana = _player.max_mana
	_player.mana = _player.max_mana
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)

	_spawn_dungeon_monsters()

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
	_joy.position = Vector2(50, vp.y - 370)   # 모바일 확대
	ui.add_child(_joy)
	# 스킬 버튼(확대): 우하단 2개 + 위 1개
	if _class == "sorceress":
		_add_skill_button(ui, "fireball", "Fire", Color.ORANGE_RED, Vector2(vp.x - 160, vp.y - 160))
		_add_skill_button(ui, "static", "Stat", Color.SKY_BLUE, Vector2(vp.x - 300, vp.y - 160))
		_add_skill_button(ui, "teleport", "Tele", Color.MEDIUM_PURPLE, Vector2(vp.x - 230, vp.y - 300))
	else:
		_add_skill_button(ui, "bash", "Bash", Color.ORANGE_RED, Vector2(vp.x - 160, vp.y - 160))
		_add_skill_button(ui, "berserk", "Bsrk", Color.CRIMSON, Vector2(vp.x - 300, vp.y - 160))
		_add_skill_button(ui, "battle_orders", "BO", Color.GOLD, Vector2(vp.x - 230, vp.y - 300))

	var bag := Button.new()
	bag.text = "Bag"
	bag.position = Vector2(vp.x - 150, 20)
	bag.custom_minimum_size = Vector2(120, 56)
	bag.size = Vector2(120, 56)
	bag.add_theme_font_size_override("font_size", 24)
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
	_hud.position = Vector2(14, 12)
	_hud.add_theme_font_size_override("font_size", 24)
	ui.add_child(_hud)

	if _class == "barbarian":
		_equip(Item.generate(_rng, Item.WEAPON_BASES[1], 1, "normal"))  # Hand Axe 3-10
	else:
		_recompute_player()

	_data_selftest()
	print("[GD] ready — class=%s life=%d dungeon=%dx%d entrance=(%d,%d) exit=(%d,%d)" % [
		_class, _player.max_life, _gw, _gh, _ent_cell.x, _ent_cell.y, _exit_cell.x, _exit_cell.y])

func _data_selftest() -> void:
	var mons := Data.monsters()
	var bases := Data.item_bases()
	var afx := Data.affixes()
	var w: Array = bases.get("weapons", [])
	var a: Array = bases.get("armor", [])
	var pre: Array = afx.get("prefixes", [])
	var suf: Array = afx.get("suffixes", [])
	print("[DD] data loaded — monsters=%d weapons=%d armor=%d prefixes=%d suffixes=%d" % [
		mons.size(), w.size(), a.size(), pre.size(), suf.size()])
	var ok: bool = mons.size() > 0 and w.size() > 0 and pre.size() > 0 and suf.size() > 0
	print("[DD] data_selftest verdict=", ("PASS" if ok else "FAIL"))

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

func _spawn_monster(nm: String, col: Color, w: int, h: int, lvl: int, hp: int, ar: int, df: int, dmin: int, dmax: int, spd: float, gx: int, gy: int) -> ActorScript:
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
	return m

func _physics_process(delta: float) -> void:
	if not _started:
		return
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

	# 출구 도달 → 다음 던전 레벨(워프)
	if Vector2(_player.gx, _player.gy).distance_to(Vector2(_exit_cell.x, _exit_cell.y)) < 1.3:
		_next_level()
		return

	for m in _monsters:
		if not m.alive:
			continue
		m.attack_cd = maxf(0.0, m.attack_cd - delta)
		var kind := String(m.get_meta("kind", "melee"))
		if kind == "boss":
			_boss_ai(m, delta)
		elif kind == "ranged":
			_ranged_ai(m, delta)
		else:
			_melee_ai(m, delta)

func _approach(m: ActorScript, delta: float, stop_dist: float) -> float:
	var d := Vector2(_player.gx - m.gx, _player.gy - m.gy).length()
	if d > stop_dist:
		_nav_toward(m, _player.gx, _player.gy, delta)  # A* 경로 추격
	return d

func _melee_ai(m: ActorScript, delta: float) -> void:
	var d := _approach(m, delta, ATTACK_RANGE)
	if d <= ATTACK_RANGE and m.attack_cd <= 0.0:
		_monster_attack(m)
		m.attack_cd = MONSTER_ATTACK_CD

func _ranged_ai(m: ActorScript, delta: float) -> void:
	var d := _approach(m, delta, RANGED_RANGE)
	if d <= RANGED_RANGE + 0.5 and m.attack_cd <= 0.0:
		_attacks += 1
		_flash(m.position, _player.position)
		if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
			var dmg := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
			_player.take_damage(dmg)
			_spawn_text(_player.position, str(dmg), Color(1, 0.6, 0.2))
		m.attack_cd = 1.6

# 보스 공격 루틴 상태머신 (Part 3 §4 안다리엘): 독노바(주기)/근접/독분사(원거리)
func _boss_ai(m: ActorScript, delta: float) -> void:
	var d := Vector2(_player.gx - m.gx, _player.gy - m.gy).length()
	var nova_cd := float(m.get_meta("nova_cd", 0.0)) - delta
	if nova_cd <= 0.0:
		_boss_nova(m)
		nova_cd = 4.0
	m.set_meta("nova_cd", nova_cd)

	var spray_cd := float(m.get_meta("spray_cd", 0.0)) - delta
	if d <= ATTACK_RANGE and m.attack_cd <= 0.0:
		_boss_melee(m)
		m.attack_cd = 1.2
	elif spray_cd <= 0.0 and d > ATTACK_RANGE:
		_boss_spray(m)
		spray_cd = 2.5
	else:
		_approach(m, delta, ATTACK_RANGE)
	m.set_meta("spray_cd", spray_cd)

func _boss_melee(m: ActorScript) -> void:
	_boss_melee_cnt += 1
	_flash(m.position, _player.position)
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		var dmg := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
		_player.take_damage(dmg)
		_spawn_text(_player.position, str(dmg), Color(1, 0.3, 0.3))

func _boss_nova(m: ActorScript) -> void:
	_boss_nova_cnt += 1
	_spawn_text(m.position, "POISON NOVA", Color(0.4, 0.9, 0.3))
	if Vector2(_player.gx - m.gx, _player.gy - m.gy).length() <= NOVA_RADIUS:
		var dmg := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 30.0)
		_player.take_damage(dmg)
		_spawn_text(_player.position, str(dmg), Color(0.4, 0.9, 0.3))

func _boss_spray(m: ActorScript) -> void:
	_boss_spray_cnt += 1
	_flash(m.position, _player.position)
	_spawn_text(m.position, "poison spray", Color(0.5, 0.8, 0.4))
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		var dmg := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
		_player.take_damage(dmg)
		_spawn_text(_player.position, str(dmg), Color(0.5, 0.8, 0.4))

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
	if _class == "barbarian" and not _bo_done:
		_cast_battle_orders()
		_bo_done = true
	var tgt := _nearest_monster()
	# 소서리스: 적이 너무 가까우면 Teleport로 카이팅(생존)
	if _class == "sorceress" and tgt != null:
		if Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy)) < 3.2 and _player.mana >= 8:
			_blink_away(tgt)
			return
	if tgt != null:
		var dd := Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy))
		var rng_use := SPELL_RANGE if _class == "sorceress" else ATTACK_RANGE
		if dd <= rng_use:
			if _player.attack_cd <= 0.0:
				if _class == "sorceress":
					_cast_fireball(tgt)
				else:
					_player_attack(tgt, "bash")
		else:
			_nav_toward(_player, tgt.gx, tgt.gy, delta)
		return
	var gi := _nearest_ground()
	if gi != null:
		_nav_toward(_player, float(gi.get_meta("gx")), float(gi.get_meta("gy")), delta)
		return
	# 몬스터·아이템 없음 → 출구로 A* 이동(다음 레벨 워프)
	_nav_toward(_player, _exit_cell.x, _exit_cell.y, delta)

func _check_pickup() -> void:
	for n in _ground.duplicate():
		if not is_instance_valid(n):
			_ground.erase(n)
			continue
		var d := Vector2(_player.gx, _player.gy).distance_to(Vector2(float(n.get_meta("gx")), float(n.get_meta("gy"))))
		if d < PICKUP_RANGE:
			_pickup(n)

func _process(delta: float) -> void:
	if not _started:
		return
	if _cam:
		_cam.position = _cam.position.lerp(_player.position, clampf(delta * 8.0, 0.0, 1.0))
	_update_projectiles(delta)
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
	_hud.text = "%s Lv%d  Life %d/%d  Mana %d/%d\nWpn: %s (%d-%d)  Arm: %s  Def %d\nkills %d  drops %d  bag %d  MF %d\n%s" % [
		_player.actor_name, _player.level, _player.life, _player.max_life, _player.mana, _player.max_mana,
		wn, _player.dmg_min, _player.dmg_max, an, _player.defense,
		_kills, _items_dropped, _inventory.size(), _player_mf, _combat_log]

	if _auto_quit and elapsed >= 50.0:
		var dex := Vector2(_player.gx, _player.gy).distance_to(Vector2(_exit_cell.x, _exit_cell.y))
		print("[GD][RESULT] class=%s dungeon_level=%d levels_cleared=%d kills=%d life=%d/%d leech_total=%d dist=%.1f" % [
			_class, _dlevel, _levels_cleared, _kills, _player.life, _player.max_life, _leech_total, dex])
		var ok: bool = _kills > 0 and _player.alive
		print("[GD][RESULT] verdict=", ("PASS" if ok else "PLAYER_DIED"))
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
	if id == "teleport":
		_cast_teleport(tgt)
		return
	if tgt == null:
		_combat_log = "no target"
		return
	if id == "fireball":
		_cast_fireball(tgt)
	elif id == "static":
		_cast_static(tgt)
	else:
		if Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy)) > ATTACK_RANGE + 0.6:
			_combat_log = "out of range"
			return
		_player_attack(tgt, id)

func _cast_fireball(target: ActorScript) -> void:
	if target == null or not _player.alive or _player.attack_cd > 0.0:
		return
	if not _player.spend_mana(3):
		_combat_log = "no mana"
		return
	_player.attack_cd = FIREBALL_CD
	_spells_cast += 1
	var lvl := _player.skill_level("fireball")
	var dmg := _rng.randi_range(14, 26) + lvl * 4
	_spawn_projectile(_player.position, target, dmg)
	_combat_log = "Fireball (dmg~%d)" % dmg

func _cast_static(target: ActorScript) -> void:
	if target == null or not target.alive or not _player.spend_mana(4):
		return
	_spells_cast += 1
	var dmg := maxi(1, int(target.life * 0.25))   # Static Field: 현재 생명 25% 감소
	target.take_damage(dmg)
	_spell_hits += 1
	_flash(_player.position, target.position)
	_spawn_text(target.position, "static %d" % dmg, Color(0.6, 0.8, 1.0))
	if not target.alive:
		_grant_xp(target.level * 40)

func _cast_teleport(target: ActorScript) -> void:
	if not _player.spend_mana(6):
		return
	_spells_cast += 1
	var tx := _player.gx
	var ty := _player.gy
	if target != null:
		var dir := (Vector2(target.gx, target.gy) - Vector2(_player.gx, _player.gy)).normalized()
		tx = clampf(_player.gx + dir.x * 4.0, 1.0, GRID - 2)
		ty = clampf(_player.gy + dir.y * 4.0, 1.0, GRID - 2)
	if _walkable(tx, ty):
		_player.gx = tx
		_player.gy = ty
		_player.position = _iso(tx, ty)
	_combat_log = "Teleport"

func _blink_away(target: ActorScript) -> void:
	if not _player.spend_mana(6):
		return
	_spells_cast += 1
	var dir := (Vector2(_player.gx, _player.gy) - Vector2(target.gx, target.gy)).normalized()
	var tx := clampf(_player.gx + dir.x * 5.0, 1.0, GRID - 2)
	var ty := clampf(_player.gy + dir.y * 5.0, 1.0, GRID - 2)
	if _walkable(tx, ty):
		_player.gx = tx
		_player.gy = ty
		_player.position = _iso(tx, ty)
	_combat_log = "Teleport (kite)"

func _spawn_projectile(from_pos: Vector2, target: ActorScript, dmg: int) -> void:
	var n := Sprite2D.new()
	n.texture = _tex_rect(10, 10, Color(1, 0.5, 0.15))
	n.position = from_pos
	n.z_index = 50
	_world.add_child(n)
	_projectiles.append({"node": n, "target": target, "dmg": dmg})

func _update_projectiles(delta: float) -> void:
	for p in _projectiles.duplicate():
		var n = p["node"]
		var t = p["target"]
		if not is_instance_valid(n):
			_projectiles.erase(p)
			continue
		if not is_instance_valid(t) or not t.alive:
			n.queue_free()
			_projectiles.erase(p)
			continue
		n.position = n.position.move_toward(t.position, 420.0 * delta)
		if n.position.distance_to(t.position) < 12.0:
			# 파이어볼 = 화염 데미지 → 대상 화염 저항/약점 적용 (Part 5 §2)
			var dmg: int = CombatLib.apply_resistance(int(p["dmg"]), t.res_fire)
			t.take_damage(dmg)
			_spell_hits += 1
			# 소서리스 스펠 생명 흡혈 (Part 5 §4)
			if _player.leech_pct > 0 and _player.alive:
				var h := CombatLib.leech_life(dmg, _player.leech_pct)
				_player.life = mini(_player.max_life, _player.life + h)
				_leech_total += h
				_player.queue_redraw()
			var txt := "%d🔥" % dmg
			if t.res_fire < 0:
				txt = "%d! 약점" % dmg
			_spawn_text(t.position, txt, Color(1, 0.55, 0.15))
			if not t.alive:
				_grant_xp(t.level * 40)
			n.queue_free()
			_projectiles.erase(p)

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
		# 크러싱 블로우(바바리안 20%): 현재 생명 비율 감소 (Part 5 §4)
		var cb := 0
		if _class == "barbarian" and _rng.randf() < 0.20:
			cb = CombatLib.crushing_blow(target.life, false, String(target.get_meta("kind", "melee")) == "boss")
		target.take_damage(dmg + cb)
		# 생명 흡혈(물리) (Part 5 §4)
		if _player.leech_pct > 0:
			var h := CombatLib.leech_life(dmg, _player.leech_pct)
			_player.life = mini(_player.max_life, _player.life + h)
			_leech_total += h
			_player.queue_redraw()
		_spawn_text(target.position, ("%d!" % dmg) if crit else str(dmg), Color(1, 0.5, 0.2) if crit else Color(1, 0.9, 0.3))
		if cb > 0:
			_spawn_text(target.position + Vector2(16, 0), "CB %d" % cb, Color(1, 0.7, 0.2))
		_combat_log = "%s→%s %d%s%s" % [label, target.actor_name, dmg, (" CRIT" if crit else ""), (" +CB%d" % cb if cb > 0 else "")]
		if not target.alive:
			_grant_xp(target.level * 40)
	else:
		_spawn_text(target.position, "miss", Color(0.85, 0.85, 0.85))
		_combat_log = "%s→%s MISS (%.0f%%)" % [label, target.actor_name, chance]
	_flash(_player.position, target.position)

func _monster_attack(m: ActorScript) -> void:
	_attacks += 1
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		# 플레이어 블록 판정 (Part 5 §3)
		if _player.block_val > 0 and CombatLib.roll_block(_rng, _player.block_val, _player.stat_dex, _player.level):
			_spawn_text(_player.position, "BLOCK", Color(0.6, 0.8, 1.0))
			return
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
	if _class == "sorceress":
		_player.base_max_life = 40 + 2 * _player.stat_vit + _player.level + int(eq["life"])
		_player.base_max_mana = 35 + 2 * _player.stat_energy + 2 * _player.level + int(eq["mana"])
	else:
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
