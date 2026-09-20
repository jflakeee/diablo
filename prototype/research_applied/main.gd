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
const InvCell := preload("res://inv_cell.gd")
const EquipSlot := preload("res://equip_slot.gd")

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
var _inv_grid: GridContainer
var _slot_weapon
var _slot_armor
var _char_panel: Panel
var _char_vbox: VBoxContainer
var _stat_points := 0
var _rng := RandomNumberGenerator.new()
var _combat_log := "-"
var _mana_acc := 0.0

var _inventory: Array = []
var _equipped := {"weapon": {}, "armor": {}}
var _eq := {"str": 0, "dex": 0, "ar": 0, "ed": 0, "life": 0, "mana": 0, "def": 0, "res_all": 0}
var _player_mf := 50
var _difficulty := 0     # 0 Normal / 1 Nightmare / 2 Hell
var _player_fcr := 63    # 소서리스 FCR (데모: 63 → 9프레임)

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
	if OS.get_cmdline_user_args().has("sorc"):
		_class = "sorceress"
	elif OS.get_cmdline_user_args().has("barb"):
		_class = "barbarian"
	if OS.get_cmdline_user_args().has("hell"):
		_difficulty = 2
	elif OS.get_cmdline_user_args().has("nm"):
		_difficulty = 1
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
	_player.is_player = true
	_player.level = 1
	_player.base_max_life = _player.max_life
	_player.life = _player.max_life
	_player.base_max_mana = _player.max_mana
	_player.mana = _player.max_mana
	_player.gx = 10.0
	_player.gy = 10.0
	_player.position = _iso(_player.gx, _player.gy)
	if _class == "barbarian":
		_player.block_val = 30   # 방패 블록값
		_player.leech_pct = 6    # 생명 흡혈 6%
	# 난이도 저항 페널티 (Part 2 §3): Normal 0 / NM -40 / Hell -100
	_player.res_fire += CombatLib.diff_player_resist_penalty(_difficulty)

	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.4, 5, 5)
	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.4, 6, 4)
	var sf1 := _spawn_monster("Spike Fiend", Color(0.8, 0.5, 0.2), 18, 20, 3, 18, 60, 10, 1, 4, 3.0, 14, 6)
	sf1.set_meta("kind", "ranged")
	var sf2 := _spawn_monster("Spike Fiend", Color(0.8, 0.5, 0.2), 18, 20, 3, 18, 60, 10, 1, 4, 3.0, 6, 14)
	sf2.set_meta("kind", "ranged")
	_spawn_monster("Zombie", Color(0.45, 0.55, 0.25), 24, 32, 4, 40, 80, 40, 2, 5, 2.0, 14, 14)
	var boss := _spawn_monster("Andariel", Color(0.7, 0.15, 0.5), 30, 44, 12, 500, 120, 60, 3, 8, 2.0, 10, 2)
	boss.set_meta("kind", "boss")
	boss.set_meta("nova_cd", 3.0)
	boss.set_meta("spray_cd", 1.5)
	boss.res_fire = -50 + CombatLib.diff_monster_resist_bonus(_difficulty)  # 약점 -50 + 난이도(Hell시 상쇄)
	_boss = boss

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
	if _class == "sorceress":
		_add_skill_button(ui, "fireball", "Fire", Color.ORANGE_RED, Vector2(vp.x - 110, vp.y - 120))
		_add_skill_button(ui, "static", "Stat", Color.SKY_BLUE, Vector2(vp.x - 210, vp.y - 120))
		_add_skill_button(ui, "teleport", "Tele", Color.MEDIUM_PURPLE, Vector2(vp.x - 160, vp.y - 220))
	else:
		_add_skill_button(ui, "bash", "Bash", Color.ORANGE_RED, Vector2(vp.x - 110, vp.y - 120))
		_add_skill_button(ui, "berserk", "Bsrk", Color.CRIMSON, Vector2(vp.x - 210, vp.y - 120))
		_add_skill_button(ui, "battle_orders", "BO", Color.GOLD, Vector2(vp.x - 160, vp.y - 220))

	var bag := Button.new()
	bag.text = "Bag (I)"
	bag.position = Vector2(vp.x - 100, 12)
	bag.pressed.connect(_toggle_bag)
	ui.add_child(bag)
	var charb := Button.new()
	charb.text = "Char (C)"
	charb.position = Vector2(vp.x - 100, 44)
	charb.pressed.connect(_toggle_char)
	ui.add_child(charb)

	# 인벤토리 패널: 좌측 장비 슬롯 + 우측 아이템 그리드(드래그&드롭)
	_inv_panel = Panel.new()
	_inv_panel.position = Vector2(vp.x - 430, 80)
	_inv_panel.size = Vector2(420, 470)
	_inv_panel.visible = false
	ui.add_child(_inv_panel)
	var title := Label.new()
	title.text = "  Inventory  (아이템 클릭=장착, 드래그→슬롯, 슬롯 클릭=해제)"
	title.position = Vector2(8, 6)
	title.add_theme_font_size_override("font_size", 12)
	_inv_panel.add_child(title)
	_slot_weapon = EquipSlot.new()
	_inv_panel.add_child(_slot_weapon)  # add_child 먼저 → _ready 실행
	_slot_weapon.set_slot("weapon")
	_slot_weapon.position = Vector2(10, 30)
	_slot_weapon.unequip_requested.connect(_unequip)
	_slot_weapon.equip_dropped.connect(_on_equip_dropped)
	_slot_armor = EquipSlot.new()
	_inv_panel.add_child(_slot_armor)
	_slot_armor.set_slot("armor")
	_slot_armor.position = Vector2(10, 90)
	_slot_armor.unequip_requested.connect(_unequip)
	_slot_armor.equip_dropped.connect(_on_equip_dropped)
	_inv_grid = GridContainer.new()
	_inv_grid.columns = 4
	_inv_grid.position = Vector2(180, 30)
	_inv_panel.add_child(_inv_grid)

	# 캐릭터 패널: 스탯/스킬 배분
	_char_panel = Panel.new()
	_char_panel.position = Vector2(vp.x - 430, 80)
	_char_panel.size = Vector2(300, 470)
	_char_panel.visible = false
	ui.add_child(_char_panel)
	_char_vbox = VBoxContainer.new()
	_char_vbox.position = Vector2(12, 10)
	_char_vbox.custom_minimum_size = Vector2(280, 450)
	_char_panel.add_child(_char_vbox)

	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 16)
	ui.add_child(_hud)

	if _class == "barbarian":
		_equip(Item.generate(_rng, Item.WEAPON_BASES[1], 1, "normal"))  # Hand Axe 3-10
	else:
		_recompute_player()

	_research_selftest()
	var dn: String = ["Normal", "Nightmare", "Hell"][_difficulty]
	print("[RA] ready — class=%s diff=%s player_res_fire=%d fireball_frames=%d" % [
		_class, dn, _player.res_fire, CombatLib.sorc_fcr_frames(_player_fcr)])

func _research_selftest() -> void:
	# 브레이크포인트 (Part 2 §1)
	var t1: bool = CombatLib.sorc_fcr_frames(0) == 13 and CombatLib.sorc_fcr_frames(63) == 9 and CombatLib.sorc_fcr_frames(105) == 8
	var t2: bool = CombatLib.barb_fhr_frames(0) == 9 and CombatLib.barb_fhr_frames(27) == 6
	# 난이도 (Part 2 §3)
	var t3: bool = absf(CombatLib.diff_monster_hp_mult(2) - 3.5) < 0.001 and CombatLib.diff_monster_resist_bonus(2) == 50
	var t4: bool = CombatLib.diff_player_resist_penalty(2) == -100 and CombatLib.diff_hell_physical_floor(2) == 50
	var t5: bool = CombatLib.monster_life_players(100, 8) == 450   # 100×(8+1)/2
	print("[RA] FCR: 0→%df 63→%df 105→%df / FHR: 0→%df 27→%df" % [
		CombatLib.sorc_fcr_frames(0), CombatLib.sorc_fcr_frames(63), CombatLib.sorc_fcr_frames(105),
		CombatLib.barb_fhr_frames(0), CombatLib.barb_fhr_frames(27)])
	print("[RA] diff: HP×%.1f res+%d / playerPen%d hellFloor%d / life(100,p8)=%d" % [
		CombatLib.diff_monster_hp_mult(2), CombatLib.diff_monster_resist_bonus(2),
		CombatLib.diff_player_resist_penalty(2), CombatLib.diff_hell_physical_floor(2), CombatLib.monster_life_players(100, 8)])
	print("[RA][RESULT] research_selftest verdict=", ("PASS" if (t1 and t2 and t3 and t4 and t5) else "FAIL"))

func _combat_deep_selftest() -> void:
	# 저항/블록/흡혈/크러싱/캡 공식 검증 (Part 5 §2~4)
	var t1: bool = CombatLib.apply_resistance(100, 50) == 50       # 50% 저항
	var t2: bool = CombatLib.apply_resistance(100, -50) == 150     # 화염 약점(-50)=150%
	var t3: bool = CombatLib.apply_resistance(100, 100) == 0       # 면역
	var t4: bool = CombatLib.apply_resistance(100, 90) == 25       # 캡75 → 25뎀
	var bc := CombatLib.block_chance(30, 100, 20)                  # (30×85)/40=63.75
	var t5: bool = absf(bc - 63.75) < 0.01
	var t6: bool = CombatLib.leech_life(100, 6) == 6               # 6% 흡혈
	var t7: bool = CombatLib.crushing_blow(400, false, false) == 100  # 근접 일반 1/4
	print("[CD] resist 50%%→%d(50) / 약점-50→%d(150) / 면역100→%d(0) / 캡90→%d(25)" % [
		CombatLib.apply_resistance(100, 50), CombatLib.apply_resistance(100, -50),
		CombatLib.apply_resistance(100, 100), CombatLib.apply_resistance(100, 90)])
	print("[CD] block(30,dex100,clvl20)=%.2f(63.75) / leech(100,6%%)=%d(6) / CB(400,근접)=%d(100)" % [
		bc, CombatLib.leech_life(100, 6), CombatLib.crushing_blow(400, false, false)])
	var ok: bool = t1 and t2 and t3 and t4 and t5 and t6 and t7
	print("[CD][RESULT] combat_deep_selftest verdict=", ("PASS" if ok else "FAIL"))

func _ui_selftest() -> void:
	# UI 로직 자체검증(대화 없이): 장착 스왑 / 스탯 배분 / 스킬 배분
	var def0 := _player.defense
	var arm := Item.generate(_rng, Item.ARMOR_BASES[2], 20, "rare")  # Ring Mail rare
	_inventory.append(arm)
	var bag0 := _inventory.size()
	_equip(arm)  # 인벤 → 장비
	var t1: bool = not _equipped["armor"].is_empty() and _inventory.size() == bag0 - 1 and _player.defense > def0
	print("[UI] equip: def %d→%d bag %d→%d : %s" % [def0, _player.defense, bag0, _inventory.size(), str(t1)])

	_unequip("armor")  # 장비 → 인벤
	var t2: bool = _equipped["armor"].is_empty() and _inventory.size() == bag0
	print("[UI] unequip: armor cleared, bag=%d : %s" % [_inventory.size(), str(t2)])

	var str0 := _player.stat_str
	_stat_points = 3
	_alloc_stat("str")
	var t3: bool = _player.stat_str == str0 + 1 and _stat_points == 2
	print("[UI] alloc stat: str %d→%d pts→%d : %s" % [str0, _player.stat_str, _stat_points, str(t3)])

	var first_skill := String(_player.skills.keys()[0])
	var lvl0 := _player.skill_level(first_skill)
	_player.skill_points = 2
	_alloc_skill(first_skill)
	var t4: bool = _player.skill_level(first_skill) == lvl0 + 1 and _player.skill_points == 1
	print("[UI] alloc skill: %s %d→%d pts→%d : %s" % [first_skill, lvl0, _player.skill_level(first_skill), _player.skill_points, str(t4)])

	# 검증 상태 초기화(게임 시작 상태로)
	_stat_points = 0
	_player.skill_points = 0
	print("[UI][RESULT] ui_selftest verdict=", ("PASS" if (t1 and t2 and t3 and t4) else "FAIL"))

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
	# 난이도 스케일링 (Part 2 §3): HP 배수 + 저항 보너스
	var shp := int(hp * CombatLib.diff_monster_hp_mult(_difficulty))
	m.base_max_life = shp
	m.max_life = shp
	m.life = shp
	m.res_fire = CombatLib.diff_monster_resist_bonus(_difficulty)
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
		var kind := String(m.get_meta("kind", "melee"))
		if kind == "boss":
			_boss_ai(m, delta)
		elif kind == "ranged":
			_ranged_ai(m, delta)
		else:
			_melee_ai(m, delta)

func _approach(m: ActorScript, delta: float, stop_dist: float) -> float:
	var to := Vector2(_player.gx - m.gx, _player.gy - m.gy)
	var d := to.length()
	if d > stop_dist:
		var step: Vector2 = to.normalized() * m.speed * delta
		if _walkable(m.gx + step.x, m.gy):
			m.gx += step.x
		if _walkable(m.gx, m.gy + step.y):
			m.gy += step.y
		m.position = _iso(m.gx, m.gy)
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

	if _auto_quit and elapsed >= 12.0:
		var dn: String = ["Normal", "Nightmare", "Hell"][_difficulty]
		print("[RA][RESULT] class=%s diff=%s kills=%d life=%d/%d player_res_fire=%d" % [
			_class, dn, _kills, _player.life, _player.max_life, _player.res_fire])
		var ok: bool = _kills > 0 or not _player.alive   # Hell은 죽을 수도(정상), 전투 발생만 확인
		print("[RA][RESULT] game verdict=", ("PASS" if (ok and _attacks > 0) else "FAIL"))
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
	# FCR 브레이크포인트 → 시전 프레임 → 쿨다운 (Part 2 §1)
	_player.attack_cd = CombatLib.frames_to_sec(CombatLib.sorc_fcr_frames(_player_fcr))
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
			# 파이어볼 = 화염 데미지 → 대상 화염 저항 적용 (음수 저항=약점 증폭). Part 5 §2
			var raw := int(p["dmg"])
			var dmg: int = CombatLib.apply_resistance(raw, t.res_fire)
			t.take_damage(dmg)
			_spell_hits += 1
			var txt := "%d🔥" % dmg
			if t.res_fire < 0:
				txt = "%d! (약점)" % dmg
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
		# Hell 물리 저항 바닥 50% (Part 2 §3) — 몬스터 물리 감산
		dmg = CombatLib.apply_resistance(dmg, CombatLib.diff_hell_physical_floor(_difficulty))
		# 크러싱 블로우(바바리안, 20% 확률): 대상 현재 생명 비율 감소 (Part 5 §4)
		var cb := 0
		if _class == "barbarian" and _rng.randf() < 0.20:
			cb = CombatLib.crushing_blow(target.life, false, String(target.get_meta("kind", "melee")) == "boss")
		target.take_damage(dmg + cb)
		# 생명 흡혈(Part 5 §4)
		if _player.leech_pct > 0:
			var heal := CombatLib.leech_life(dmg, _player.leech_pct)
			_player.life = mini(_player.max_life, _player.life + heal)
			_player.queue_redraw()
		_spawn_text(target.position, ("%d!" % dmg) if crit else str(dmg), Color(1, 0.5, 0.2) if crit else Color(1, 0.9, 0.3))
		if cb > 0:
			_spawn_text(target.position + Vector2(14, 0), "CB %d" % cb, Color(1, 0.7, 0.2))
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
		_player.skill_points += 1     # 배분 가능 스킬 포인트
		_stat_points += 5             # 배분 가능 스탯 포인트
		if _auto_quit:
			_player.skills["mastery"] = _player.skill_level("mastery") + 1  # 자동전투는 자동투자
			_player.skill_points -= 1
		_recompute_player()
		_combat_log = "LEVEL UP → %d (+5 stat, +1 skill)" % _player.level
		need = _player.level * 100
	_rebuild_char()

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
	var slot := String(it["slot"])
	var prev: Dictionary = _equipped[slot]
	_inventory.erase(it)
	_equipped[slot] = it
	if not prev.is_empty():
		_inventory.append(prev)   # 기존 장비는 가방으로
	_recompute_player()
	_combat_log = "equipped %s" % Item.display_name(it)
	_rebuild_inv()

func _unequip(slot: String) -> void:
	var it: Dictionary = _equipped[slot]
	if it.is_empty():
		return
	_inventory.append(it)
	_equipped[slot] = {}
	_recompute_player()
	_combat_log = "unequipped %s" % Item.display_name(it)
	_rebuild_inv()

func _on_equip_dropped(slot: String, it: Dictionary) -> void:
	if String(it.get("slot", "")) == slot:
		_equip(it)

func _toggle_bag() -> void:
	_inv_panel.visible = not _inv_panel.visible
	if _inv_panel.visible:
		_char_panel.visible = false
		_rebuild_inv()

func _toggle_char() -> void:
	_char_panel.visible = not _char_panel.visible
	if _char_panel.visible:
		_inv_panel.visible = false
		_rebuild_char()

func _slot_display(slot: String, es) -> void:
	var it: Dictionary = _equipped[slot]
	if it.is_empty():
		es.set_display("(비어있음)", "", Color(1, 1, 1, 0.25))
	else:
		es.set_display(Item.display_name(it), _tooltip(it), Item.quality_color(String(it["quality"])))

func _tooltip(it: Dictionary) -> String:
	return "%s\n%s" % [Item.display_name(it), Item.affix_text(it)]

func _rebuild_inv() -> void:
	if _inv_grid == null:
		return
	_slot_display("weapon", _slot_weapon)
	_slot_display("armor", _slot_armor)
	for c in _inv_grid.get_children():
		c.queue_free()
	for it in _inventory:
		var cell := InvCell.new()
		_inv_grid.add_child(cell)
		cell.set_item(it, Item.display_name(it), _tooltip(it), Item.quality_color(String(it["quality"])))
		var captured: Dictionary = it
		cell.clicked.connect(func(_i): _equip(captured))
	# 빈 셀 채우기(그리드 느낌)
	var fill := 12 - _inventory.size()
	for i in maxi(fill, 0):
		var empty := InvCell.new()
		_inv_grid.add_child(empty)
		empty.set_item({}, "", "", Color(1, 1, 1, 0.08))

func _rebuild_char() -> void:
	if _char_vbox == null:
		return
	for c in _char_vbox.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "%s  Lv %d\nStat pts: %d   Skill pts: %d\nLife %d/%d  Mana %d/%d\nAR %d  Def %d  Dmg %d-%d\n— Attributes —" % [
		_player.actor_name, _player.level, _stat_points, _player.skill_points,
		_player.life, _player.max_life, _player.mana, _player.max_mana,
		CombatLib.character_ar(_player.stat_dex + int(_eq["dex"]), Skills.mastery_ar_pct(_player.skill_level("mastery"))) + int(_eq["ar"]),
		_player.defense, _player.dmg_min, _player.dmg_max]
	_char_vbox.add_child(head)
	for st in [["str", _player.stat_str], ["dex", _player.stat_dex], ["vit", _player.stat_vit], ["energy", _player.stat_energy]]:
		_char_vbox.add_child(_alloc_row("%s: %d" % [st[0], int(st[1])], _stat_points > 0, func(): _alloc_stat(String(st[0]))))
	var sk := Label.new()
	sk.text = "— Skills —"
	_char_vbox.add_child(sk)
	for id in _player.skills:
		_char_vbox.add_child(_alloc_row("%s: %d" % [Skills.def_name(id) if Skills.DEFS.has(id) else id, _player.skill_level(id)], _player.skill_points > 0, func(): _alloc_skill(String(id))))

func _alloc_row(text: String, can_add: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)
	if can_add:
		var btn := Button.new()
		btn.text = " + "
		btn.pressed.connect(cb)
		row.add_child(btn)
	return row

func _alloc_stat(stat: String) -> void:
	if _stat_points <= 0:
		return
	_stat_points -= 1
	match stat:
		"str": _player.stat_str += 1
		"dex": _player.stat_dex += 1
		"vit": _player.stat_vit += 1
		"energy": _player.stat_energy += 1
	_recompute_player()
	_rebuild_char()

func _alloc_skill(id: String) -> void:
	if _player.skill_points <= 0:
		return
	_player.skill_points -= 1
	_player.skills[id] = _player.skill_level(id) + 1
	_recompute_player()
	_rebuild_char()

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_I:
			_toggle_bag()
		elif e.keycode == KEY_C:
			_toggle_char()

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
