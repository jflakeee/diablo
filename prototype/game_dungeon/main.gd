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
const PixelGen := preload("res://art/pixel_gen.gd")
const SfxGen := preload("res://sfx_gen.gd")
const MinimapScript := preload("res://minimap.gd")
const Automation := preload("res://automation.gd")
const AssetCatalog := preload("res://asset_catalog.gd")
const MobileUI := preload("res://mobile_ui.gd")
const Accessibility := preload("res://accessibility.gd")
const Identity := preload("res://identity.gd")
const SystemTests := preload("res://system_tests.gd")
const SaveStore := preload("res://save_store.gd")
const OnlineAuthority := preload("res://online_authority.gd")
const Coverage := preload("res://coverage.gd")
const PerformanceBudget := preload("res://performance_budget.gd")
const Quest := preload("res://quest.gd")
const Waypoint := preload("res://waypoint.gd")
const Mercenary := preload("res://mercenary.gd")
const Stamina := preload("res://stamina.gd")
const DeathSystem := preload("res://death_system.gd")
const Stash := preload("res://stash.gd")
const DEPLOYED_AT_KST := "2026-09-26 13:14 KST"

var _grid: Array = []
var _astar: AStarGrid2D
var _gw := 45
var _gh := 45
var _ent_cell := Vector2i(1, 1)
var _exit_cell := Vector2i(1, 1)
var _tiles_node: Node2D
var _dlevel := 1
var _levels_cleared := 0
# ── 액트 구조(보스 클라이맥스 + 퀘스트) ──
const ACT_LEN := 3            # 액트당 던전 층수(마지막 층=보스)
var _act := 1
var _acts_cleared := 0
var _exit_locked := false
var _quest_defs: Array = []
var _quest_state: Dictionary = {}
var _waypoint_defs: Array = []
var _waypoint_state: Dictionary = {}

func _level_in_act() -> int:
	return ((_dlevel - 1) % ACT_LEN) + 1

func _is_boss_level() -> bool:
	return _level_in_act() == ACT_LEN

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
const EQUIPMENT_SLOTS := ["weapon", "armor", "ring_left", "ring_right", "amulet"]

var _class := "warden"
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
# ── 포션 & 벨트 (P6 생존) ──
const BELT_MAX := 8
const POT_HEAL_PCT := 0.45   # 생명 포션: 최대 생명의 45% 회복
const POT_MANA_PCT := 0.45   # 마나 포션: 최대 마나의 45% 회복
var _belt_hp := 2            # 시작 생명 포션
var _belt_mp := 2            # 시작 마나 포션
var _potions_quaffed := 0
var _pot_hp_btn: Button
var _pot_mp_btn: Button
# ── 동료(Ember Scout) — 원거리 화염 화살 아군 ──
var _merc: ActorScript
var _merc_cd := 0.0
var _merc_kills := 0
var _merc_revive_t := 0.0
var _merc_equipped := Mercenary.empty_equipment()
const MERC_RANGE := 6.0
const MERC_CD := 1.1
# ── 골드 경제 & 상인 ──
var _gold := 0
const COST_HP_POT := 45
const COST_MP_POT := 35
var _vendor_panel: Panel
var _gold_sold := 0
var _gambles := 0
# ── 스탯/스킬 포인트 분배(성장) ──
var _stat_points := 0
var _char_panel: Panel
var _char_vbox: VBoxContainer
var _settings_panel: Panel
var _settings_scale_button: Button
var _settings_text_button: Button
var _minimap: Control
var _inv_panel: Panel
var _inv_vbox: VBoxContainer
var _rng := RandomNumberGenerator.new()
var _combat_log := "-"
var _stamina := 100.0
var _stamina_max := 100.0
var _stamina_recovery_delay := 0.0
var _player_moved_last_tick := false
var _player_running := false
var _death_respawn_t := 0.0
var _corpse_state: Dictionary = {}
var _corpse_marker: Node2D
var _player_deaths := 0
var _mana_acc := 0.0

var _inventory: Array = []
var _stash: Array = []
var _equipped := {"weapon": {}, "armor": {}, "ring_left": {}, "ring_right": {}, "amulet": {}}
var _eq := {"str": 0, "dex": 0, "ar": 0, "ed": 0, "life": 0, "mana": 0, "def": 0, "res_all": 0}
var _player_mf := 50
var _automation := Automation.new()
var _accessibility := Accessibility.new()
var _automation_last_expire := 0
var _assets := AssetCatalog.new()

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
var _compiled_monsters := 0
var _generated_monsters := 0
var _run_start := 0
var _auto_quit := false
var _ui_selftest_ok := true
var _identity_selftest_ok := true
var _system_selftest_ok := true
var _save_selftest_ok := true
var _online_selftest_ok := true
var _coverage_selftest_ok := true
var _waypoint_selftest_ok := true
var _quitting := false
var _perf_start_memory := 0
var _perf_peak_memory := 0
var _perf_peak_active := 0

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

# 미니맵 지형 텍스처(레벨당 1회): 벽=투명 어둠 / 바닥=밝은 회갈색
func _build_minimap_tex() -> void:
	if _minimap == null:
		return
	var img := Image.create(_gw, _gh, false, Image.FORMAT_RGBA8)
	for y in _gh:
		for x in _gw:
			var wall: bool = int(_grid[y][x]) == 0
			img.set_pixel(x, y, Color(0.08, 0.07, 0.09, 0.0) if wall else Color(0.55, 0.5, 0.42, 0.92))
	_minimap.tex = ImageTexture.create_from_image(img)
	_minimap.gw = _gw
	_minimap.gh = _gh

func _update_minimap() -> void:
	if _minimap == null:
		return
	_minimap.player_cell = Vector2(_player.gx, _player.gy)
	_minimap.exit_cell = Vector2(_exit_cell.x, _exit_cell.y)
	var mc: Array = []
	for m in _monsters:
		if m.alive:
			mc.append(Vector2(m.gx, m.gy))
	_minimap.monster_cells = mc
	_minimap.merc_cell = (Vector2(_merc.gx, _merc.gy) if (_merc != null and _merc.alive) else null)
	_minimap.queue_redraw()

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
	# 제작기로 타일 변종 몇 개 미리 생성(성능: 재사용)
	var floor_texs := [
		PixelGen.iso_tile(TILE_W, TILE_H, Color(0.26, 0.42, 0.28), 1, true),
		PixelGen.iso_tile(TILE_W, TILE_H, Color(0.24, 0.40, 0.26), 5, true),
		PixelGen.iso_tile(TILE_W, TILE_H, Color(0.28, 0.44, 0.30), 9, false),
	]
	var wall_texs := [
		PixelGen.iso_tile(TILE_W, TILE_H, Color(0.30, 0.28, 0.26), 2, true),
		PixelGen.iso_tile(TILE_W, TILE_H, Color(0.26, 0.24, 0.23), 6, true),
	]
	for y in _gh:
		for x in _gw:
			var s := Sprite2D.new()
			if int(_grid[y][x]) == 1:
				s.texture = floor_texs[(x * 7 + y) % 3]
			else:
				s.texture = wall_texs[(x * 5 + y) % 2]
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
	# 풀에서 보스/잡몹 분리
	var pool: Array = []
	var boss_def := {}
	for md in Data.monsters():
		if String(md.get("kind", "melee")) == "boss":
			boss_def = md
		else:
			pool.append(md)
	var boss_lv := _is_boss_level()
	_exit_locked = boss_lv and not boss_def.is_empty()
	# 잡몹 수: 일반 층은 4+레벨(최대 8), 보스 층은 줄여서 보스에 집중
	var count := 3 if boss_lv else mini(4 + _dlevel, 8)
	for i in count:
		if pool.is_empty():
			break
		var md: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		_spawn_one(md, _random_floor_cell())
	# 보스: 액트 마지막 층에만 등장(퀘스트 목표)
	if boss_lv and not boss_def.is_empty():
		_spawn_one(boss_def, _random_floor_cell())

# 유니크 보스 모디파이어(Part 3 §4 몬스터 팩) — D2 상징 접두 능력
const UNIQ_MODS := [
	{"id": "extra_fast", "name": "Extra Fast"},
	{"id": "extra_strong", "name": "Extra Strong"},
	{"id": "cold_ench", "name": "Cold Enchanted"},
	{"id": "fire_ench", "name": "Fire Enchanted"},
	{"id": "light_ench", "name": "Lightning Enchanted"},
	{"id": "stone_skin", "name": "Stone Skin"},
]
var _champs := 0
var _uniques := 0
var _forced_rank := false

func _spawn_one(md: Dictionary, cell: Vector2i) -> void:
	var kind := String(md.get("kind", "melee"))
	var col := Color(float(md["color"][0]), float(md["color"][1]), float(md["color"][2]))
	var m := _spawn_monster(String(md["name"]), col, int(md["w"]), int(md["h"]), int(md["level"]), int(md["hp"]), int(md["ar"]), int(md["def"]), int(md["dmin"]), int(md["dmax"]), float(md["speed"]), cell.x, cell.y)
	var monster_seed := cell.x * 13 + cell.y
	var monster_name := String(md["name"])
	var monster_compiled := _assets.monster_frames(String(md.get("id", monster_name)))
	if not monster_compiled.is_empty():
		_compiled_monsters += 1
		m.set_sprite_frames(monster_compiled["idle"], monster_compiled["walk"], 1.7 if kind == "boss" else 1.0)
	else:
		_generated_monsters += 1
		_assets.record_fallback("monster/" + String(md.get("id", monster_name)))
		if not _assets.allows_fallback():
			return
		m.set_sprite_frames(PixelGen.monster_named(monster_name, col, monster_seed, 0), [
			PixelGen.monster_named(monster_name, col, monster_seed, 1),
			PixelGen.monster_named(monster_name, col, monster_seed, 0),
			PixelGen.monster_named(monster_name, col, monster_seed, 2),
		], 1.7 if kind == "boss" else 1.0)
	# 난이도 HP 스케일링 (Part 2 §3)
	m.max_life = int(m.max_life * CombatLib.diff_monster_hp_mult(_difficulty))
	m.base_max_life = m.max_life
	m.life = m.max_life
	var rbonus := CombatLib.diff_monster_resist_bonus(_difficulty)
	m.res_fire = int(md.get("res_fire", 0)) + rbonus
	m.res_cold = int(md.get("res_cold", 0)) + rbonus
	m.res_light = int(md.get("res_light", 0)) + rbonus
	m.res_poison = int(md.get("res_poison", 0)) + rbonus
	if kind != "melee":
		m.set_meta("kind", kind)
	if kind == "boss":
		m.set_meta("nova_cd", float(md.get("nova_cd", 3.0)))
		m.set_meta("spray_cd", float(md.get("spray_cd", 1.5)))
		m.res_fire = -50 + rbonus
		_boss = m
		return
	# 챔피언/유니크 등급 롤 (일반 몬스터만)
	var roll := _rng.randf()
	if _auto_quit and not _forced_rank:      # 셀프테스트: 첫 몬스터 유니크 강제
		_forced_rank = true
		_apply_rank(m, "unique")
	elif roll < 0.05:
		_apply_rank(m, "unique")
	elif roll < 0.15:
		_apply_rank(m, "champion")

# 등급 강화: 스탯 배수 + 인챈트 + 이름표 (Part 3 §4)
func _apply_rank(m: ActorScript, rank: String) -> void:
	var base_name := String(m.actor_name)
	if rank == "champion":
		_champs += 1
		m.max_life = int(m.max_life * 1.9)
		m.dmg_min = int(m.dmg_min * 1.4); m.dmg_max = int(m.dmg_max * 1.4)
		m.attack_rating = int(m.attack_rating * 1.15)
		m.speed *= 1.1
		m.actor_name = "Champion " + base_name
		m.set_meta("rank", "champion")
		m.modulate = Color(0.7, 0.85, 1.0)                 # 푸른 광휘
		_add_name_tag(m, m.actor_name, Color(0.55, 0.75, 1.0))
	else:
		_uniques += 1
		m.max_life = int(m.max_life * 3.0)
		m.dmg_min = int(m.dmg_min * 1.4); m.dmg_max = int(m.dmg_max * 1.4)
		m.attack_rating = int(m.attack_rating * 1.25)
		var mod: Dictionary = UNIQ_MODS[_rng.randi_range(0, UNIQ_MODS.size() - 1)]
		var mid := String(mod["id"])
		m.set_meta("rank", "unique")
		m.set_meta("umod", mid)
		match mid:
			"extra_fast": m.speed *= 1.4
			"extra_strong": m.dmg_min = int(m.dmg_min * 1.6); m.dmg_max = int(m.dmg_max * 1.6)
			"cold_ench": m.set_meta("enchant", "cold"); m.res_cold += 80
			"fire_ench": m.set_meta("enchant", "fire"); m.res_fire += 80
			"light_ench": m.set_meta("enchant", "light"); m.res_light += 80
			"stone_skin": m.defense = int(m.defense * 4.0); m.max_life = int(m.max_life * 1.3)
		m.actor_name = "%s %s" % [String(mod["name"]), base_name]
		m.modulate = Color(1.0, 0.82, 0.35)                # 금색 광휘
		_add_name_tag(m, m.actor_name, Color(1.0, 0.82, 0.3))
	m.base_max_life = m.max_life
	m.life = m.max_life

func _add_name_tag(m: ActorScript, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _accessibility.font_size(11))
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(-float(text.length()) * 3.0, -52)
	m.add_child(lbl)

# 액트 보스 처치 보상 — 출구 해제 + 유니크 확정 + 스킬포인트 + 골드 보너스
func _complete_act(boss: Node) -> void:
	_exit_locked = false
	_acts_cleared += 1
	# 확정 유니크 드롭(가능한 베이스 중 랜덤)
	var uniq_bases: Array = Item.UNIQUES.keys()
	var pick_name := String(uniq_bases[_rng.randi_range(0, uniq_bases.size() - 1)])
	var base: Dictionary = {}
	for b in Item.WEAPON_BASES + Item.ARMOR_BASES + Item.ACCESSORY_BASES:
		if String(b["name"]) == pick_name:
			base = b
			break
	if not base.is_empty():
		var uq := Item.generate(_rng, base, _player.level + 10, "unique")
		_spawn_ground(uq, boss.gx, boss.gy)
		_items_dropped += 1
	# 스킬 포인트 + 골드 보너스
	_player.skill_points += 2
	if _auto_quit:
		_auto_spend_points()
	var bonus := 500 + _act * 300
	_gold += bonus
	_combat_log = "ACT %d 클리어! 출구 개방 / 고유 장비 / 스킬+2 / +%dg" % [_act, bonus]
	_act += 1

func _next_level() -> void:
	_levels_cleared += 1
	_dlevel += 1
	Waypoint.unlock(_waypoint_defs, _waypoint_state, _act, _level_in_act())
	for g in _ground:
		if is_instance_valid(g):
			g.queue_free()
	_ground.clear()
	_projectiles.clear()
	_generate_dungeon()
	_build_minimap_tex()
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)
	# 용병도 새 레벨 입구로 이동(죽었으면 부활)
	if _merc != null:
		if not _merc.alive:
			_merc_revive()
		else:
			_merc.gx = _player.gx + 1
			_merc.gy = _player.gy
			_merc.position = _iso(_merc.gx, _merc.gy)
	_spawn_dungeon_monsters()
	if is_instance_valid(_cam):
		_cam.position = _player.position
	_combat_log = "던전 레벨 %d" % _dlevel

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
	var sp := actor.speed * (0.5 if actor.slow_timer > 0.0 else 1.0)  # 냉기 슬로우
	if actor == _player:
		var wants_run := _auto_quit or (_joy != null and _joy.value.length() >= 0.72)
		var armor_penalty := Stamina.armor_speed_penalty(_equipped["armor"])
		var stamina_state := Stamina.update(_stamina, _stamina_max, true, wants_run, delta, _stamina_recovery_delay, armor_penalty)
		_stamina = float(stamina_state["stamina"])
		_stamina_recovery_delay = float(stamina_state["recovery_delay"])
		_player_running = bool(stamina_state["running"])
		_player_moved_last_tick = true
		if _player_running:
			sp *= Stamina.RUN_SPEED_MULTIPLIER
	var nx: float = actor.gx + dir.x * sp * delta
	var ny: float = actor.gy + dir.y * sp * delta
	if _walkable(nx, actor.gy):
		actor.gx = nx
	if _walkable(actor.gx, ny):
		actor.gy = ny
	actor.position = _iso(actor.gx, actor.gy)

var _menu_layer: CanvasLayer
var _started := false
var _leech_total := 0
var _difficulty := 0     # 0 Normal / 1 Nightmare / 2 Hell
var _player_fcr := 63    # 소서리스 FCR
var _diff_label: Label
var _base_res_fire := 0
var _base_res_cold := 0
var _base_res_light := 0
var _base_res_poison := 0

var _sfx := {}              # name -> AudioStreamWAV
var _sfx_pool: Array = []   # AudioStreamPlayer 라운드로빈 풀
var _sfx_idx := 0
var _sfx_ready := false

# 절차 생성 효과음 준비(코드 PCM). 실패해도 게임에 영향 X.
func _setup_sfx() -> void:
	for n in ["attack", "spell", "hit", "pickup", "levelup", "death"]:
		_sfx[n] = SfxGen.make(n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)
	_sfx_ready = true

func _play_sfx(name: String, vol_db: float = -6.0) -> void:
	if not _sfx_ready or not _sfx.has(name):
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()
	p.stream = _sfx[name]
	p.volume_db = vol_db
	p.play()

func _release_runtime_resources() -> void:
	for raw_player in _sfx_pool:
		var player := raw_player as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null
			player.free()
	_sfx_pool.clear()
	_sfx.clear()
	_sfx_ready = false
	_assets.clear()

func _ready() -> void:
	_accessibility.load_settings()
	_setup_sfx()
	_auto_quit = OS.get_cmdline_user_args().has("autoquit")
	_assets.configure(AssetCatalog.MissingPolicy.FAIL if OS.get_cmdline_user_args().has("strict_assets") else AssetCatalog.MissingPolicy.WARN)
	if OS.get_cmdline_user_args().has("hell"):
		_difficulty = 2
	elif OS.get_cmdline_user_args().has("nm"):
		_difficulty = 1
	if _auto_quit:
		print("[AUTO] selftest verdict=", "PASS" if _automation.selftest() else "FAIL")
		print("[ANIM] selftest verdict=", "PASS" if ActorScript.animation_selftest() else "FAIL")
		_ui_selftest_ok = MobileUI.selftest()
		print("[MOBILE_UI] ratios=4 targets>=48 primary>=72 safe_margin=16 verdict=", "PASS" if _ui_selftest_ok else "FAIL")
		print("[ACCESS] scales=80/100/120/140 text=normal/large persist=true verdict=", "PASS" if Accessibility.selftest() else "FAIL")
		var identity_report := Identity.selftest(Data)
		_identity_selftest_ok = bool(identity_report["ok"])
		print("[IDENTITY] project=Ashen Depths monsters=%d failures=%s verdict=%s" % [int(identity_report["monster_ids"]), str(identity_report["failures"]), "PASS" if bool(identity_report["ok"]) else "FAIL"])
		var system_report := SystemTests.run()
		_system_selftest_ok = bool(system_report["ok"])
		print("[SYSTEM] checks=%d failures=%s verdict=%s" % [int(system_report["checks"]), str(system_report["failures"]), "PASS" if _system_selftest_ok else "FAIL"])
		var save_report := SaveStore.selftest()
		_save_selftest_ok = bool(save_report["ok"])
		print("[SAVE] checks=%d failures=%s verdict=%s" % [int(save_report["checks"]), str(save_report["failures"]), "PASS" if _save_selftest_ok else "FAIL"])
		var online_report := OnlineAuthority.selftest()
		_online_selftest_ok = bool(online_report["ok"])
		print("[ONLINE] checks=%d failures=%s verdict=%s" % [int(online_report["checks"]), str(online_report["failures"]), "PASS" if _online_selftest_ok else "FAIL"])
		var coverage_report := Coverage.validate(Data, Skills, Item, Craft)
		_coverage_selftest_ok = bool(coverage_report["ok"])
		print("[COVERAGE] checks=%d monsters=%d skills=%d bases=%d quests=%d waypoints=%d failures=%s verdict=%s" % [int(coverage_report["checks"]), int(coverage_report.get("monsters", 0)), int(coverage_report.get("skills", 0)), int(coverage_report.get("bases", 0)), int(coverage_report.get("quests", 0)), int(coverage_report.get("waypoints", 0)), str(coverage_report["failures"]), "PASS" if _coverage_selftest_ok else "FAIL"])
		print("[PERF] budget_selftest verdict=", "PASS" if PerformanceBudget.selftest() else "FAIL")
		print("[ASSET] atlas=%s entries=%d selftest=%s" % [str(_assets.available()), _assets.entry_count(), "PASS" if _assets.selftest() else "FAIL"])
		_automation = Automation.new() # 셀프테스트 상태를 실제 플레이와 분리
		var uq := Item.generate(_rng, Item.WEAPON_BASES[1], 20, "unique")
		print("[UNIQ] ", Item.display_name(uq), " affixes=", uq["affixes"], " color=", Item.quality_color("unique"))
		var sok := 0
		for sn in _sfx:
			var st: AudioStreamWAV = _sfx[sn]
			if st != null and st.data.size() > 0:
				sok += 1
		print("[SFX] generator=%d generated=%d/%d players=%d bytes(attack)=%d" % [SfxGen.VERSION, sok, _sfx.size(), _sfx_pool.size(), int((_sfx["attack"] as AudioStreamWAV).data.size())])
	if OS.get_cmdline_user_args().has("sorc"):
		_class = "arcanist"
		_start_game()
	elif OS.get_cmdline_user_args().has("barb"):
		_class = "warden"
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
	title.text = "ASHEN DEPTHS"
	title.add_theme_font_size_override("font_size", _accessibility.font_size(44))
	title.position = Vector2(vp.x * 0.5 - 240, vp.y * 0.2)
	_menu_layer.add_child(title)
	var sub := Label.new()
	sub.text = "클래스 선택 / Choose your class"
	sub.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	sub.position = Vector2(vp.x * 0.5 - 160, vp.y * 0.2 + 60)
	_menu_layer.add_child(sub)
	_add_class_button("Iron Warden / 근접 / 방어", Color(0.9, 0.75, 0.2), Vector2(vp.x * 0.5 - 220, vp.y * 0.42), "warden")
	_add_class_button("Arcanist / 원거리 / 비전", Color(0.6, 0.5, 0.95), Vector2(vp.x * 0.5 - 220, vp.y * 0.42 + 90), "arcanist")
	# 난이도 선택
	_diff_label = Label.new()
	_diff_label.add_theme_font_size_override("font_size", _accessibility.font_size(20))
	_diff_label.position = Vector2(vp.x * 0.5 - 220, vp.y * 0.42 + 200)
	_menu_layer.add_child(_diff_label)
	_update_diff_label()
	var dnames := ["Normal", "Nightmare", "Hell"]
	var dcols := [Color(0.5, 0.8, 0.5), Color(0.9, 0.8, 0.3), Color(0.9, 0.3, 0.3)]
	for i in 3:
		var db := Button.new()
		db.text = dnames[i]
		db.position = Vector2(vp.x * 0.5 - 220 + i * 150, vp.y * 0.42 + 240)
		db.custom_minimum_size = Vector2(140, 50)
		db.size = Vector2(140, 50)
		db.add_theme_font_size_override("font_size", _accessibility.font_size(20))
		db.add_theme_color_override("font_color", dcols[i])
		db.pressed.connect(_set_difficulty.bind(i))
		_menu_layer.add_child(db)

func _set_difficulty(d: int) -> void:
	_difficulty = d
	_update_diff_label()

func _update_diff_label() -> void:
	if _diff_label:
		var dn: String = ["Normal", "Nightmare(어려움)", "Hell(극악)"][_difficulty]
		_diff_label.text = "난이도: %s  ← 아래에서 변경, 위 클래스로 시작" % dn

func _add_class_button(text: String, col: Color, pos: Vector2, cls: String) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(440, 74)
	btn.size = Vector2(440, 74)
	btn.add_theme_font_size_override("font_size", _accessibility.font_size(26))
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
	_quest_defs = Data.quests()
	_quest_state = Quest.new_state(_quest_defs)
	_waypoint_defs = Data.waypoints()
	_waypoint_state = Waypoint.new_state()
	Waypoint.unlock(_waypoint_defs, _waypoint_state, _act, _level_in_act())
	_run_start = Time.get_ticks_msec()
	_perf_start_memory = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_perf_peak_memory = _perf_start_memory
	if _auto_quit:
		_rng.seed = 42  # 검증 재현성
	else:
		_rng.randomize()

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_generate_dungeon()

	if _class == "arcanist":
		_player = _make_actor("Arcanist", Color(0.5, 0.35, 0.85), 20, 32)
		_player.stat_str = 10
		_player.stat_dex = 15
		_player.stat_vit = 20
		_player.stat_energy = 35
		_player.max_life = 40 + 2 * _player.stat_vit + 1  # Part 1 §2
		_player.max_mana = 35 + 2 * _player.stat_energy + 2
		_player.speed = 5.5
		_player.skills = {"ember_bolt": 1, "frost_shard": 0, "storm_lance": 0, "phase_step": 0}
		_base_res_fire = 30      # 소서리스 화염 기본 저항
		_player.leech_pct = 8    # 스펠 생명 흡혈 8%
	else:
		_player = _make_actor("Iron Warden", Color(0.9, 0.75, 0.2), 22, 34)
		_player.stat_str = 30
		_player.stat_dex = 25
		_player.stat_vit = 25
		_player.stat_energy = 15
		_player.max_life = CombatLib.warden_max_life(25, 1)
		_player.max_mana = CombatLib.warden_max_mana(15, 1)
		_player.speed = 6.0
		_player.skills = {"sundering_strike": 1, "void_fury": 0, "iron_chant": 0, "weapon_discipline": 1}
		_player.block_val = 30   # 방패 블록
		_player.leech_pct = 6    # 물리 생명 흡혈 6%
	# 종단 검증은 모든 스킬 실행 경로와 기존 50초 층 클리어 기준을 함께 검사한다.
	if _auto_quit:
		_player.skills = {"ember_bolt": 3, "frost_shard": 3, "storm_lance": 3, "phase_step": 1} if _class == "arcanist" else {"sundering_strike": 1, "void_fury": 1, "iron_chant": 1, "weapon_discipline": 1}
	_player.is_player = true
	_player.died.connect(_on_player_died)
	_player.level = 1
	_player.base_max_life = _player.max_life
	_player.life = _player.max_life
	_player.base_max_mana = _player.max_mana
	_player.mana = _player.max_mana
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)
	# 제작기 캐릭터 스프라이트
	var robe := Color(0.3, 0.3, 0.75) if _class == "arcanist" else Color(0.7, 0.2, 0.15)
	_set_hero_art(_player, _class, robe, 10, 1.1)
	# 초기 장비/저항 계산: 바바리안 시작 무기, 소서리스 스탯 재계산
	if _class == "warden":
		var w := Item.generate(_rng, Item.WEAPON_BASES[1], 1, "magic")  # Fiery Hand Axe
		w["affixes"]["fdmg"] = 6
		w["prefix"] = "Fiery"
		_equip(w)
	else:
		_recompute_player()

	_spawn_merc()
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
	var physical_vp := get_viewport_rect().size
	var ui_scale := MobileUI.effective_scale(_accessibility.ui_scale, physical_vp)
	ui.transform = Transform2D.IDENTITY.scaled(Vector2(ui_scale, ui_scale))
	add_child(ui)
	var vp := physical_vp / ui_scale
	var safe := MobileUI.logical_safe_area(physical_vp)
	safe = Rect2(safe.position / ui_scale, safe.size / ui_scale)
	var mobile_layout := MobileUI.layout(vp, safe)
	_joy = JoystickScript.new()
	_joy.position = mobile_layout["joystick"]
	ui.add_child(_joy)
	# 스킬 버튼(확대): 우하단 2개 + 위 1개
	if _class == "arcanist":
		_add_skill_button(ui, "ember_bolt", "Ember", Color.ORANGE_RED, mobile_layout["skill_primary"])
		_add_skill_button(ui, "frost_shard", "Frost", Color.SKY_BLUE, mobile_layout["skill_secondary"])
		_add_skill_button(ui, "storm_lance", "Storm", Color.YELLOW, mobile_layout["skill_utility"])
	else:
		_add_skill_button(ui, "sundering_strike", "Sunder", Color.ORANGE_RED, mobile_layout["skill_primary"])
		_add_skill_button(ui, "void_fury", "Fury", Color.CRIMSON, mobile_layout["skill_secondary"])
		_add_skill_button(ui, "iron_chant", "Chant", Color.GOLD, mobile_layout["skill_utility"])

	var bag := Button.new()
	bag.text = "Bag"
	bag.position = mobile_layout["bag"]
	bag.custom_minimum_size = MobileUI.MENU_SIZE
	bag.size = MobileUI.MENU_SIZE
	bag.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	bag.pressed.connect(_toggle_bag)
	ui.add_child(bag)

	_inv_panel = Panel.new()
	_inv_panel.position = mobile_layout["panel"]
	_inv_panel.size = Vector2(360, 430)
	_inv_panel.visible = false
	ui.add_child(_inv_panel)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.position = Vector2(8, 8)
	inventory_scroll.size = Vector2(344, 414)
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inv_panel.add_child(inventory_scroll)
	_inv_vbox = VBoxContainer.new()
	_inv_vbox.custom_minimum_size = Vector2(326, 410)
	inventory_scroll.add_child(_inv_vbox)

	var shop := Button.new()
	shop.text = "Shop"
	shop.position = mobile_layout["shop"]
	shop.custom_minimum_size = MobileUI.MENU_SIZE
	shop.size = MobileUI.MENU_SIZE
	shop.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	shop.pressed.connect(_toggle_vendor)
	ui.add_child(shop)

	_vendor_panel = Panel.new()
	_vendor_panel.position = mobile_layout["panel"]
	_vendor_panel.size = Vector2(360, 500)
	_vendor_panel.visible = false
	ui.add_child(_vendor_panel)
	_build_vendor()

	var charb := Button.new()
	charb.text = "Char"
	charb.position = mobile_layout["char"]
	charb.custom_minimum_size = MobileUI.MENU_SIZE
	charb.size = MobileUI.MENU_SIZE
	charb.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	charb.pressed.connect(_toggle_char)
	ui.add_child(charb)

	_char_panel = Panel.new()
	_char_panel.position = mobile_layout["panel"]
	_char_panel.size = Vector2(360, 480)
	_char_panel.visible = false
	ui.add_child(_char_panel)
	_build_char_panel()

	var settings_button := Button.new()
	settings_button.text = "UI"
	settings_button.position = mobile_layout["settings"]
	settings_button.custom_minimum_size = Vector2(96, 56)
	settings_button.size = Vector2(96, 56)
	settings_button.add_theme_font_size_override("font_size", _accessibility.font_size(20))
	settings_button.pressed.connect(_toggle_settings)
	ui.add_child(settings_button)

	var deploy_stamp := Label.new()
	deploy_stamp.text = "배포 %s" % DEPLOYED_AT_KST
	deploy_stamp.position = Vector2(mobile_layout["bag"].x - 224, mobile_layout["bag"].y + MobileUI.MENU_SIZE.y + 2)
	deploy_stamp.size = Vector2(328, 22)
	deploy_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deploy_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deploy_stamp.add_theme_font_size_override("font_size", _accessibility.font_size(13))
	deploy_stamp.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 0.9))
	ui.add_child(deploy_stamp)

	_settings_panel = Panel.new()
	_settings_panel.position = mobile_layout["settings_panel"]
	_settings_panel.size = Vector2(360, 370)
	_settings_panel.visible = false
	ui.add_child(_settings_panel)
	_build_settings_panel()

	# 자동 지도(미니맵) — 좌하단(조이스틱 위쪽 여백)
	_minimap = MinimapScript.new()
	_minimap.size = Vector2(190, 190)
	_minimap.position = mobile_layout["minimap"]
	ui.add_child(_minimap)
	_build_minimap_tex()

	_hud = Label.new()
	_hud.position = mobile_layout["hud"]
	_hud.size = Vector2(500, 0)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	ui.add_child(_hud)

	# 포션 벨트 버튼(모바일): 좌하단, 조이스틱 위. 빨강=생명 / 파랑=마나
	_pot_hp_btn = _make_potion_button("HP", Color(0.75, 0.15, 0.15), mobile_layout["potion_hp"], _quaff_health)
	_pot_mp_btn = _make_potion_button("MP", Color(0.15, 0.3, 0.8), mobile_layout["potion_mp"], _quaff_mana)
	ui.add_child(_pot_hp_btn)
	ui.add_child(_pot_mp_btn)

	if _class == "warden":
		_equip(Item.generate(_rng, Item.WEAPON_BASES[1], 1, "normal"))  # Hand Axe 3-10
	else:
		_recompute_player()

	_data_selftest()
	if _auto_quit:
		_craft_selftest()
		_act_reward_selftest()
		_waypoint_travel_selftest()
	print("[GD] ready — class=%s life=%d dungeon=%dx%d entrance=(%d,%d) exit=(%d,%d)" % [
		_class, _player.max_life, _gw, _gh, _ent_cell.x, _ent_cell.y, _exit_cell.x, _exit_cell.y])

# 액트 보상 경로(_complete_act) 결정론적 검증 — 더미 보스로 직접 실행
func _act_reward_selftest() -> void:
	var g0 := _gold
	var ground0 := _ground.size()
	var act0 := _acts_cleared
	var dummy := _make_actor("TestBoss", Color(1, 0, 0), 20, 20)
	dummy.gx = _player.gx
	dummy.gy = _player.gy
	_exit_locked = true
	_complete_act(dummy)
	var ok: bool = (not _exit_locked) and _gold > g0 and _ground.size() > ground0 and _acts_cleared == act0 + 1
	print("[ACTTEST] exit_unlocked=%s gold+=%d dropped=%s acts_cleared=%d verdict=%s" % [
		str(not _exit_locked), _gold - g0, str(_ground.size() > ground0), _acts_cleared, ("PASS" if ok else "FAIL")])
	# 상태 원복(실제 런 오염 방지)
	dummy.queue_free()
	for g in _ground.duplicate():
		if is_instance_valid(g) and g.get_meta("gx", -999) == _player.gx:
			g.queue_free()
			_ground.erase(g)
	_gold = g0
	_acts_cleared = act0
	_act = 1
	_exit_locked = false

func _waypoint_travel_selftest() -> void:
	var saved_state := _waypoint_state.duplicate(true)
	var saved_level := _dlevel
	Waypoint.unlock(_waypoint_defs, _waypoint_state, _act, 2)
	_waypoint_state["current"] = String(Waypoint.find_at(_waypoint_defs, _act, 1).get("id", ""))
	_travel_waypoint(0)
	var reached_second := _level_in_act() == 2 and String(_waypoint_state.get("current", "")) == String(Waypoint.find_at(_waypoint_defs, _act, 2).get("id", ""))
	_travel_waypoint(0)
	var returned_first := _level_in_act() == 1 and String(_waypoint_state.get("current", "")) == String(Waypoint.find_at(_waypoint_defs, _act, 1).get("id", ""))
	_waypoint_selftest_ok = reached_second and returned_first
	_waypoint_state = saved_state
	_dlevel = saved_level
	print("[WAYPOINT_TEST] forward=%s return=%s verdict=%s" % [str(reached_second), str(returned_first), "PASS" if _waypoint_selftest_ok else "FAIL"])

func _data_selftest() -> void:
	var mons := Data.monsters()
	var bases := Data.item_bases()
	var afx := Data.affixes()
	var w: Array = bases.get("weapons", [])
	var a: Array = bases.get("armor", [])
	var accessories: Array = bases.get("accessories", [])
	var pre: Array = afx.get("prefixes", [])
	var suf: Array = afx.get("suffixes", [])
	print("[DD] data loaded — monsters=%d weapons=%d armor=%d accessories=%d prefixes=%d suffixes=%d" % [
		mons.size(), w.size(), a.size(), accessories.size(), pre.size(), suf.size()])
	var ok: bool = mons.size() > 0 and w.size() > 0 and a.size() > 0 and accessories.size() > 0 and pre.size() > 0 and suf.size() > 0
	print("[DD] data_selftest verdict=", ("PASS" if ok else "FAIL"))

func _craft_selftest() -> void:
	# 1) 보석 소켓 → 스탯 (Perfect Ruby → armor +38 life)
	var arm := Item.make_socketed(Item.ARMOR_BASES[1], 3)
	Item.socket_insert(arm, {"kind": "gem", "id": "ruby"})
	var e1 := Item.effective_affixes(arm)
	var t1: bool = int(e1.get("life", 0)) >= 38
	print("[P4] gem  : Ruby→armor +life=%d (>=38) : %s" % [int(e1.get("life", 0)), str(t1)])

	# 2) 독자 각인 조합 Vey + Ahn (weapon 2소켓)
	var wpn := Item.make_socketed(Item.WEAPON_BASES[0], 2)
	Item.socket_insert(wpn, {"kind": "rune", "id": "Vey"})
	Item.socket_insert(wpn, {"kind": "rune", "id": "Ahn"})
	var e2 := Item.effective_affixes(wpn)
	var t2: bool = String(wpn.get("runeword", "")) == "Tempered Edge" and int(e2.get("ed", 0)) == 20
	print("[P4] sigil: Vey+Ahn → %s (ed=%d ar=%d) : %s" % [String(wpn.get("runeword", "")), int(e2.get("ed", 0)), int(e2.get("ar", 0)), str(t2)])

	# 3) 각인 순서 오류(Ahn+Vey) → 미형성
	var wpn2 := Item.make_socketed(Item.WEAPON_BASES[0], 2)
	Item.socket_insert(wpn2, {"kind": "rune", "id": "Ahn"})
	Item.socket_insert(wpn2, {"kind": "rune", "id": "Vey"})
	Item.effective_affixes(wpn2)
	var t3: bool = String(wpn2.get("runeword", "")) == ""
	print("[P4] order: Ahn+Vey → sigilword='%s' (없어야 함) : %s" % [String(wpn2.get("runeword", "")), str(t3)])

	# 4) 변환: Ahn×3 → Ahnor
	var up := Craft.upgrade_rune("Ahn")
	var t4: bool = up == "Ahnor"
	print("[P4] forge: Ahn×3 → %s (Ahnor) : %s" % [up, str(t4)])

	print("[P4][RESULT] craft_selftest verdict=", ("PASS" if (t1 and t2 and t3 and t4) else "FAIL"))

func _add_skill_button(ui: CanvasLayer, id: String, label: String, col: Color, pos: Vector2) -> void:
	var b := SkillButtonScript.new()
	b.skill_id = id
	b.label_text = label
	b.color = col
	b.position = pos
	b.used.connect(_on_skill_used)
	ui.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if not _started or _auto_quit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_quaff_health()
		elif event.keycode == KEY_2:
			_quaff_mana()
		elif event.keycode == KEY_F5:
			_save_game()
		elif event.keycode == KEY_F9:
			_load_game()

func _make_potion_button(glyph: String, col: Color, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = glyph
	b.position = pos
	b.custom_minimum_size = MobileUI.POTION_SIZE
	b.size = MobileUI.POTION_SIZE
	b.add_theme_font_size_override("font_size", _accessibility.font_size(24))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(roundi(MobileUI.POTION_SIZE.x * 0.5))
	b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(cb)
	return b

func _build_settings_panel() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(12, 12)
	box.custom_minimum_size = Vector2(336, 346)
	_settings_panel.add_child(box)
	var title := Label.new()
	title.text = "접근성 / UI 설정"
	title.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	box.add_child(title)
	_settings_scale_button = Button.new()
	_settings_scale_button.custom_minimum_size = Vector2(336, 52)
	_settings_scale_button.pressed.connect(_cycle_ui_scale)
	box.add_child(_settings_scale_button)
	_settings_text_button = Button.new()
	_settings_text_button.custom_minimum_size = Vector2(336, 52)
	_settings_text_button.pressed.connect(_cycle_text_scale)
	box.add_child(_settings_text_button)
	var save_button := Button.new()
	save_button.text = "게임 저장"
	save_button.custom_minimum_size = Vector2(336, 52)
	save_button.pressed.connect(_save_game)
	box.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "불러오기"
	load_button.custom_minimum_size = Vector2(336, 52)
	load_button.pressed.connect(_load_game)
	box.add_child(load_button)
	var note := Label.new()
	note.text = "변경 사항은 다음 전투 HUD 생성부터 적용됩니다."
	note.add_theme_font_size_override("font_size", _accessibility.font_size(14))
	box.add_child(note)
	_refresh_settings_labels()

func _refresh_settings_labels() -> void:
	if _settings_scale_button:
		_settings_scale_button.text = "UI 배율: %d%%" % roundi(_accessibility.ui_scale * 100.0)
	if _settings_text_button:
		_settings_text_button.text = "본문 텍스트: %s" % ("크게" if _accessibility.text_scale > 1.0 else "보통")

func _cycle_ui_scale() -> void:
	_accessibility.cycle_ui_scale()
	_refresh_settings_labels()

func _cycle_text_scale() -> void:
	_accessibility.cycle_text_scale()
	_refresh_settings_labels()

func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible

func _gather_save_state(reason: String = "manual") -> Dictionary:
	return {
		"saved_at_unix": int(Time.get_unix_time_from_system()), "save_reason": reason,
		"class": _class, "level": _player.level, "xp": _player.xp,
		"stat_points": _stat_points, "skill_points": _player.skill_points,
		"stat_str": _player.stat_str, "stat_dex": _player.stat_dex,
		"stat_vit": _player.stat_vit, "stat_energy": _player.stat_energy,
		"skills": _player.skills.duplicate(true), "inventory": _inventory.duplicate(true),
		"stash": _stash.duplicate(true),
		"equipped": {"weapon": (_equipped["weapon"] as Dictionary).duplicate(true), "armor": (_equipped["armor"] as Dictionary).duplicate(true), "ring_left": (_equipped["ring_left"] as Dictionary).duplicate(true), "ring_right": (_equipped["ring_right"] as Dictionary).duplicate(true), "amulet": (_equipped["amulet"] as Dictionary).duplicate(true)},
		"kills": _kills, "gold": _gold, "belt_hp": _belt_hp, "belt_mp": _belt_mp,
		"difficulty": _difficulty, "act": _act, "acts_cleared": _acts_cleared,
		"dungeon_level": _dlevel, "levels_cleared": _levels_cleared,
		"quest_state": _quest_state.duplicate(true),
		"waypoint_state": _waypoint_state.duplicate(true),
		"merc_equipped": _merc_equipped.duplicate(true),
		"stamina": _stamina,
		"corpse_state": _corpse_state.duplicate(true), "player_deaths": _player_deaths,
	}

func _save_game() -> void:
	_combat_log = "저장 완료" if SaveStore.save_state(_gather_save_state("manual")) else "저장 실패"

func _notification(what: int) -> void:
	if not _started or _player == null or _auto_quit:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveStore.save_state(_gather_save_state("lifecycle"))
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_combat_log = "플레이 재개 · 진행 자동 저장됨"

func _load_game() -> void:
	var state := SaveStore.load_state()
	if state.is_empty():
		_combat_log = "유효한 저장 없음"
		return
	if String(state["class"]) != _class:
		_combat_log = "현재 클래스와 저장 클래스가 다름"
		return
	_player.level = int(state.get("level", 1))
	_player.xp = int(state.get("xp", 0))
	_stat_points = int(state.get("stat_points", 0))
	_player.skill_points = int(state.get("skill_points", 0))
	_player.stat_str = int(state.get("stat_str", _player.stat_str))
	_player.stat_dex = int(state.get("stat_dex", _player.stat_dex))
	_player.stat_vit = int(state.get("stat_vit", _player.stat_vit))
	_player.stat_energy = int(state.get("stat_energy", _player.stat_energy))
	_player.skills = (state.get("skills", {}) as Dictionary).duplicate(true)
	_inventory = (state.get("inventory", []) as Array).duplicate(true)
	_stash = Stash.normalize(state.get("stash", []))
	var equipped: Dictionary = state.get("equipped", {})
	var legacy_ring: Dictionary = equipped.get("ring", {})
	_equipped = {"weapon": (equipped.get("weapon", {}) as Dictionary).duplicate(true), "armor": (equipped.get("armor", {}) as Dictionary).duplicate(true), "ring_left": (equipped.get("ring_left", legacy_ring) as Dictionary).duplicate(true), "ring_right": (equipped.get("ring_right", {}) as Dictionary).duplicate(true), "amulet": (equipped.get("amulet", {}) as Dictionary).duplicate(true)}
	_kills = int(state.get("kills", 0))
	_gold = int(state.get("gold", 0))
	_belt_hp = clampi(int(state.get("belt_hp", 2)), 0, BELT_MAX)
	_belt_mp = clampi(int(state.get("belt_mp", 2)), 0, BELT_MAX)
	_difficulty = clampi(int(state.get("difficulty", 0)), 0, 2)
	_act = maxi(int(state.get("act", 1)), 1)
	_acts_cleared = maxi(int(state.get("acts_cleared", 0)), 0)
	_dlevel = maxi(int(state.get("dungeon_level", 1)), 1)
	_levels_cleared = maxi(int(state.get("levels_cleared", 0)), 0)
	_quest_state = Quest.normalize_state(_quest_defs, state.get("quest_state", {}))
	_waypoint_state = Waypoint.normalize_state(_waypoint_defs, state.get("waypoint_state", {}))
	_merc_equipped = Mercenary.normalize_equipment(state.get("merc_equipped", {}))
	Waypoint.unlock(_waypoint_defs, _waypoint_state, _act, _level_in_act())
	_recompute_player()
	var saved_stamina := float(state.get("stamina", -1.0))
	_stamina = _stamina_max if saved_stamina < 0.0 else clampf(saved_stamina, 0.0, _stamina_max)
	_corpse_state = DeathSystem.normalize_corpse(state.get("corpse_state", {}))
	_player_deaths = maxi(0, int(state.get("player_deaths", 0)))
	_spawn_corpse_marker()
	if _merc != null:
		_merc_scale_stats()
	_rebuild_inv()
	_rebuild_char_panel()
	_refresh_vendor()
	_combat_log = "불러오기 완료 (Lv %d)" % _player.level

# 생명 포션 소비: 최대 생명의 45% 회복(즉시). 벨트 1개 소모.
func _quaff_health() -> void:
	if _belt_hp <= 0 or not _player.alive or _player.life >= _player.max_life:
		return
	_belt_hp -= 1
	_potions_quaffed += 1
	var heal := int(_player.max_life * POT_HEAL_PCT)
	_player.life = mini(_player.max_life, _player.life + heal)
	_player.queue_redraw()
	_spawn_text(_player.position, "+%d HP" % heal, Color(0.4, 0.9, 0.4))

func _quaff_mana() -> void:
	if _belt_mp <= 0 or not _player.alive or _player.mana >= _player.max_mana:
		return
	_belt_mp -= 1
	_potions_quaffed += 1
	var gain := int(_player.max_mana * POT_MANA_PCT)
	_player.mana = mini(_player.max_mana, _player.mana + gain)
	_spawn_text(_player.position, "+%d MP" % gain, Color(0.4, 0.6, 1.0))

func _add_potion_to_belt(ptype: String) -> bool:
	if ptype == "mana":
		if _belt_mp >= BELT_MAX:
			return false
		_belt_mp += 1
	else:
		if _belt_hp >= BELT_MAX:
			return false
		_belt_hp += 1
	return true

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
		_death_respawn_t = maxf(0.0, _death_respawn_t - delta)
		if _death_respawn_t <= 0.0:
			_respawn_player()
		return
	if not _player_moved_last_tick:
		var stamina_state := Stamina.update(_stamina, _stamina_max, false, false, delta, _stamina_recovery_delay)
		_stamina = float(stamina_state["stamina"])
		_stamina_recovery_delay = float(stamina_state["recovery_delay"])
		_player_running = false
	_player_moved_last_tick = false

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
	_check_corpse_recovery()

	# 출구 도달 → 다음 던전 레벨(워프). 보스 층은 보스 처치 전 잠금.
	if Vector2(_player.gx, _player.gy).distance_to(Vector2(_exit_cell.x, _exit_cell.y)) < 1.3:
		if _exit_locked:
			_combat_log = "출구 봉인: 보스를 처치하십시오"
		else:
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

# 용병 스폰(플레이어 옆). 스탯은 플레이어 레벨에 스케일.
func _spawn_merc() -> void:
	_merc = _make_actor("Ember Scout", Color(0.55, 0.25, 0.35), 20, 32)
	_merc.is_ally = true
	_merc.died.connect(_on_merc_died)
	var merc_col := Color(0.5, 0.15, 0.2)
	_set_hero_art(_merc, "scout", merc_col, 7, 1.0)
	_merc.level = _player.level
	_merc_scale_stats()
	_merc.gx = _player.gx + 1
	_merc.gy = _player.gy
	_merc.position = _iso(_merc.gx, _merc.gy)

func _set_hero_art(actor: ActorScript, kind: String, color: Color, seed: int, scale_v: float) -> void:
	var compiled := _assets.hero_directions(kind)
	if not compiled.is_empty():
		actor.set_directional_frames(compiled, scale_v)
		return
	_assets.record_fallback("hero/" + kind)
	if not _assets.allows_fallback():
		return
	var generated := {}
	for direction in 4:
		generated[direction] = {"idle": PixelGen.hero(kind, color, seed, direction, 0), "walk": [
			PixelGen.hero(kind, color, seed, direction, 1),
			PixelGen.hero(kind, color, seed, direction, 0),
			PixelGen.hero(kind, color, seed, direction, 2),
		]}
	actor.set_directional_frames(generated, scale_v)

func _merc_scale_stats() -> void:
	var lv := _player.level
	var stats := Mercenary.stats(lv, _merc_equipped, Item)
	_merc.max_life = int(stats["life"])
	_merc.base_max_life = _merc.max_life
	if _merc.alive:
		_merc.life = _merc.max_life
	_merc.attack_rating = int(stats["attack_rating"])
	_merc.dmg_min = int(stats["dmg_min"])
	_merc.dmg_max = int(stats["dmg_max"])
	_merc.defense = int(stats["defense"])
	_merc.res_fire = int(stats["res_fire"])
	_merc.res_cold = int(stats["res_cold"])
	_merc.res_light = int(stats["res_light"])
	_merc.res_poison = int(stats["res_poison"])
	_merc.speed = 5.6

# 용병 AI: 플레이어 추종 + 최근접 몬스터에 화염 화살(원거리)
func _merc_ai(delta: float) -> void:
	if _merc == null:
		return
	if not _merc.alive:
		# 레벨 전환/시간 경과 시 부활
		_merc_revive_t -= delta
		if _merc_revive_t <= 0.0:
			_merc_revive()
		return
	_merc.animate(delta)
	_merc_cd = maxf(0.0, _merc_cd - delta)
	var tgt := _nearest_monster()
	var pd := Vector2(_player.gx - _merc.gx, _player.gy - _merc.gy).length()
	if tgt != null and Vector2(_merc.gx, _merc.gy).distance_to(Vector2(tgt.gx, tgt.gy)) <= MERC_RANGE:
		if pd > 4.5:                       # 너무 멀면 플레이어에게 복귀 우선
			_nav_toward(_merc, _player.gx, _player.gy, delta)
		elif _merc_cd <= 0.0:
			_merc_fire(tgt)
			_merc_cd = MERC_CD
	elif pd > 2.2:                          # 몬스터 없음/사거리 밖 → 플레이어 추종
		_nav_toward(_merc, _player.gx, _player.gy, delta)

func _merc_fire(tgt: ActorScript) -> void:
	_merc.play_attack(Vector2(tgt.gx - _merc.gx, tgt.gy - _merc.gy))
	if CombatLib.roll_hit(_rng, _merc.attack_rating, tgt.defense, _merc.level, tgt.level):
		var phys := CombatLib.physical_damage(_rng, _merc.dmg_min, _merc.dmg_max, 0.0)
		var fire := _rng.randi_range(3, 8) + _merc.level
		# 물리 화살(저항 무시) 즉시 + 화염 부가(저항 적용)
		var pre_alive := tgt.alive
		tgt.take_damage(phys)
		var fdmg := CombatLib.apply_resistance(fire, _target_resist(tgt, "fire"))
		if fdmg > 0 and tgt.alive:
			tgt.take_damage(fdmg)
		_spawn_text(tgt.position + Vector2(0, -8), "%d+%d🔥" % [phys, fdmg], Color(1, 0.7, 0.3))
		_flash(_merc.position, tgt.position)
		if pre_alive and not tgt.alive:
			_merc_kills += 1
			_grant_xp(tgt.level * 40)     # 용병 킬도 플레이어 XP(D2)

func _on_merc_died(_a: Node) -> void:
	_merc_revive_t = 8.0                    # 8초 후 부활
	_combat_log = "용병 쓰러짐 (8초 후 부활)"

func _on_player_died(_actor: Node) -> void:
	_player_deaths += 1
	var lost_gold := DeathSystem.gold_loss(_gold)
	_gold -= lost_gold
	var lost_xp := mini(_player.xp, DeathSystem.experience_loss(_difficulty, _player.level * 100))
	_player.xp -= lost_xp
	var previous_gold := int(_corpse_state.get("held_gold", 0))
	_corpse_state = DeathSystem.create_corpse(_player.gx, _player.gy, lost_gold + previous_gold)
	_spawn_corpse_marker()
	_death_respawn_t = DeathSystem.RESPAWN_DELAY
	_combat_log = "쓰러짐 · 골드 %d, 경험치 %d 손실" % [lost_gold, lost_xp]

func _respawn_player() -> void:
	_player.alive = true
	_player.modulate = Color.WHITE
	_player.life = maxi(1, roundi(_player.max_life * 0.5))
	_player.mana = roundi(_player.max_mana * 0.5)
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)
	_combat_log = "체크포인트 부활 · 시체를 회수하십시오"

func _spawn_corpse_marker() -> void:
	if is_instance_valid(_corpse_marker):
		_corpse_marker.queue_free()
	_corpse_marker = null
	if _corpse_state.is_empty() or _world == null:
		return
	var marker := Node2D.new()
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0, -10), Vector2(14, 0), Vector2(0, 10), Vector2(-14, 0)])
	diamond.color = Color(0.65, 0.12, 0.08, 0.9)
	marker.add_child(diamond)
	var label := Label.new()
	label.text = "CORPSE"
	label.position = Vector2(-27, -34)
	label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
	marker.add_child(label)
	marker.position = _iso(float(_corpse_state["gx"]), float(_corpse_state["gy"]))
	marker.z_index = 4
	_world.add_child(marker)
	_corpse_marker = marker

func _check_corpse_recovery() -> void:
	if not DeathSystem.can_recover(_corpse_state, _player.gx, _player.gy):
		return
	var recovered_gold := int(_corpse_state.get("held_gold", 0))
	_gold += recovered_gold
	_corpse_state.clear()
	if is_instance_valid(_corpse_marker):
		_corpse_marker.queue_free()
	_corpse_marker = null
	_combat_log = "시체 회수 · 골드 +%d" % recovered_gold

func _merc_revive() -> void:
	if _merc == null:
		return
	_merc.alive = true
	_merc.modulate = Color(1, 1, 1, 1)
	_merc_scale_stats()
	_merc.life = _merc.max_life
	_merc.gx = _player.gx + 1
	_merc.gy = _player.gy
	_merc.position = _iso(_merc.gx, _merc.gy)
	_combat_log = "용병 부활"

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
			_damage_armor()
			_spawn_text(_player.position, str(dmg), Color(1, 0.6, 0.2))
			_apply_enchant(m)
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
		_damage_armor()
		_spawn_text(_player.position, str(dmg), Color(1, 0.3, 0.3))

func _boss_nova(m: ActorScript) -> void:
	_boss_nova_cnt += 1
	_spawn_text(m.position, "POISON NOVA", Color(0.4, 0.9, 0.3))
	if Vector2(_player.gx - m.gx, _player.gy - m.gy).length() <= NOVA_RADIUS:
		var raw := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 30.0)
		var dmg := CombatLib.apply_resistance(raw, _player.res_poison)  # 독 → 플레이어 독저항
		_player.take_damage(dmg)
		_spawn_text(_player.position, "%d☠" % dmg, Color(0.4, 0.9, 0.3))
	# 용병도 노바 범위면 피해(독저항 없음)
	if _merc != null and _merc.alive and Vector2(_merc.gx - m.gx, _merc.gy - m.gy).length() <= NOVA_RADIUS:
		var md := int(CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 30.0))
		_merc.take_damage(md)
		_spawn_text(_merc.position, "%d☠" % md, Color(0.4, 0.9, 0.3))

func _boss_spray(m: ActorScript) -> void:
	_boss_spray_cnt += 1
	_flash(m.position, _player.position)
	_spawn_text(m.position, "poison spray", Color(0.5, 0.8, 0.4))
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		var raw := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
		var dmg := CombatLib.apply_resistance(raw, _player.res_poison)  # 독 → 플레이어 독저항
		_player.take_damage(dmg)
		_spawn_text(_player.position, "%d☠" % dmg, Color(0.5, 0.8, 0.4))

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
	# 자동 포션: 생명 35% 미만 / 마나 20% 미만이면 소비(생존)
	if _player.life < _player.max_life * 0.35 and _belt_hp > 0:
		_quaff_health()
	if _player.mana < _player.max_mana * 0.20 and _belt_mp > 0:
		_quaff_mana()
	# 상인 이용(검증): 가방 5개↑ 판매, 골드 여유+벨트 부족 시 포션 구매
	if _inventory.size() >= 5:
		_sell_all()
	if _gold >= COST_HP_POT and _belt_hp < 3:
		_buy_potion("health")
	# 골드 여유 시 도박(검증)
	if _gold > _gamble_cost() + 400:
		_gamble()
	if _class == "warden" and not _bo_done and _player.skill_level("iron_chant") > 0:
		_cast_iron_chant()
		_bo_done = true
	var tgt := _nearest_monster()
	# 소서리스: 적이 너무 가까우면 Teleport로 카이팅(생존)
	if _class == "arcanist" and tgt != null:
		if Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy)) < 3.2 and _player.mana >= 8:
			_blink_away(tgt)
			return
	if tgt != null:
		var dd := Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy))
		var rng_use := SPELL_RANGE if _class == "arcanist" else ATTACK_RANGE
		if dd <= rng_use:
			if _player.attack_cd <= 0.0:
				if _class == "arcanist":
					var learned_spells: Array = []
					for spell_id in ["ember_bolt", "frost_shard", "storm_lance"]:
						if _player.skill_level(spell_id) > 0: learned_spells.append(spell_id)
					var selected_spell := String(learned_spells[_spells_cast % learned_spells.size()])
					if selected_spell == "ember_bolt":
						_cast_bolt(tgt, "fire", Color(1, 0.5, 0.15), 14, 26)
					elif selected_spell == "frost_shard":
						_cast_bolt(tgt, "cold", Color(0.4, 0.7, 1.0), 10, 20)
					else:
						_cast_storm_lance(tgt)
				else:
					_player_attack(tgt, "sundering_strike")
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
	_perf_peak_memory = maxi(_perf_peak_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	_perf_peak_active = maxi(_perf_peak_active, _monsters.size() + _ground.size() + _projectiles.size() + 2)
	if _cam:
		_cam.position = _cam.position.lerp(_player.position, clampf(delta * 8.0, 0.0, 1.0))
	# 애니메이션(걷기 bob·방향·팝)
	_player.animate(delta)
	_update_minimap()
	_merc_ai(delta)
	for am in _monsters:
		if am.alive:
			am.animate(delta)
	_update_projectiles(delta)
	var now := int(Time.get_ticks_msec() / 1000)
	if now != _automation_last_expire:
		_automation_last_expire = now
		var mats := _automation.expire_auctions(now)
		if mats > 0:
			_combat_log = "경매 만료 자동 분해 → 재료 +%d" % mats
	if _attack_ttl > 0.0:
		_attack_ttl -= delta
		if _attack_ttl <= 0.0:
			_attack_line.clear_points()

	var alive_cnt := 0
	for m in _monsters:
		if m.alive:
			alive_cnt += 1
	var wn := _equipped_label("weapon")
	var an := _equipped_label("armor")
	var elapsed := float(Time.get_ticks_msec() - _run_start) / 1000.0
	_hud.text = "%s Lv%d  HP %d/%d  MP %d/%d  골드 %d\n무기 %s (%d-%d)  방어 %s / DEF %d\n처치 %d  드롭 %d  가방 %d  MF %d  벨트 HP%d MP%d\n%s" % [
		_player.actor_name, _player.level, _player.life, _player.max_life, _player.mana, _player.max_mana, _gold,
		wn, _player.dmg_min, _player.dmg_max, an, _player.defense,
		_kills, _items_dropped, _inventory.size(), _player_mf, _belt_hp, _belt_mp, _combat_log]
	_hud.text += "\nStamina %d/%d · %s" % [roundi(_stamina), roundi(_stamina_max), "RUN" if _player_running else "WALK"]
	if not _corpse_state.is_empty():
		_hud.text += " · Corpse %dg · Deaths %d" % [int(_corpse_state.get("held_gold", 0)), _player_deaths]
	if _pot_hp_btn:
		_pot_hp_btn.text = "HP\n%d" % _belt_hp
	if _pot_mp_btn:
		_pot_mp_btn.text = "MP\n%d" % _belt_mp
	if _merc != null:
		var ms := ("HP %d/%d" % [_merc.life, _merc.max_life]) if _merc.alive else "쓰러짐"
		_hud.text += "\n동료 Ember Scout %s  킬 %d" % [ms, _merc_kills]
	if _stat_points > 0 or _player.skill_points > 0:
		_hud.text += "  포인트: 스탯%d 스킬%d" % [_stat_points, _player.skill_points]
	var quest_gate := "보스 처치 필요" if _exit_locked else ("보스 층" if _is_boss_level() else "탐험 중")
	_hud.text += "\nACT %d · 층 %d/%d · %s (클리어 %d)\n퀘스트: %s · WP: %s" % [_act, _level_in_act(), ACT_LEN, quest_gate, _acts_cleared, Quest.objective_text(_quest_defs, _quest_state, _act), Waypoint.current_name(_waypoint_defs, _waypoint_state)]

	if _auto_quit and elapsed >= 50.0 and not _quitting:
		_quitting = true
		var dex := Vector2(_player.gx, _player.gy).distance_to(Vector2(_exit_cell.x, _exit_cell.y))
		var dn: String = ["Normal", "NM", "Hell"][_difficulty]
		print("[GD][RESULT] class=%s diff=%s dungeon_level=%d cleared=%d kills=%d life=%d/%d res_fire=%d champs=%d uniques=%d" % [
			_class, dn, _dlevel, _levels_cleared, _kills, _player.life, _player.max_life, _player.res_fire, _champs, _uniques])
		print("[POT] quaffed=%d belt(HP%d MP%d)" % [_potions_quaffed, _belt_hp, _belt_mp])
		var mstate := ("alive %d/%d" % [_merc.life, _merc.max_life]) if (_merc != null and _merc.alive) else "down"
		print("[MERC] kills=%d state=%s" % [_merc_kills, mstate])
		print("[GOLD] gold=%d sold_total=%d gambles=%d" % [_gold, _gold_sold, _gambles])
		print("[MAP] tex=%s grid=%dx%d monster_dots=%d" % [str(_minimap != null and _minimap.tex != null), _minimap.gw if _minimap else 0, _minimap.gh if _minimap else 0, _minimap.monster_cells.size() if _minimap else 0])
		print("[ACT] act=%d level_in_act=%d/%d boss_level=%s exit_locked=%s acts_cleared=%d" % [
			_act, _level_in_act(), ACT_LEN, str(_is_boss_level()), str(_exit_locked), _acts_cleared])
		var completed_quests := 0
		for quest_entry in _quest_state.values():
			if String((quest_entry as Dictionary).get("status", "")) == "complete":
				completed_quests += 1
		print("[QUEST] completed=%d/%d current=%s" % [completed_quests, _quest_defs.size(), Quest.objective_text(_quest_defs, _quest_state, _act)])
		print("[WAYPOINT] unlocked=%d/%d current=%s" % [(_waypoint_state.get("unlocked", {}) as Dictionary).size(), _waypoint_defs.size(), Waypoint.current_name(_waypoint_defs, _waypoint_state)])
		print("[CHAR] str=%d dex=%d vit=%d energy=%d discipline=%d unspent(stat=%d skill=%d)" % [
			_player.stat_str, _player.stat_dex, _player.stat_vit, _player.stat_energy,
			_player.skill_level("weapon_discipline" if _class != "arcanist" else "ember_bolt"), _stat_points, _player.skill_points])
		print("[ANIM] player_directions=%d merc_directions=%d player_states=%d merc_states=%d" % [
			_player.facing_count(), _merc.facing_count() if _merc != null else 0,
			_player.state_count(), _merc.state_count() if _merc != null else 0])
		var asset_report := _assets.validate_runtime()
		print("[ASSET] monsters compiled=%d fallback=%d runtime=%s" % [_compiled_monsters, _generated_monsters, str(asset_report)])
		var perf_report := PerformanceBudget.evaluate(elapsed, _logic_ticks, _perf_peak_active, _perf_start_memory, _perf_peak_memory)
		print("[PERF] logic_hz=%.2f peak_active=%d memory_growth_kib=%.1f failures=%s verdict=%s" % [float(perf_report["logic_hz"]), int(perf_report["peak_active"]), float(perf_report["memory_growth"]) / 1024.0, str(perf_report["failures"]), "PASS" if bool(perf_report["ok"]) else "FAIL"])
		var ok: bool = (_kills > 0 or _spells_cast > 0) and bool(asset_report["ok"]) and bool(perf_report["ok"]) and _ui_selftest_ok and _identity_selftest_ok and _system_selftest_ok and _save_selftest_ok and _online_selftest_ok and _coverage_selftest_ok and _waypoint_selftest_ok
		print("[GD][RESULT] verdict=", ("PASS" if ok else "FAIL"))
		_release_runtime_resources()
		await get_tree().process_frame
		await get_tree().process_frame
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
	if _player.skill_level(id) <= 0:
		_combat_log = "아직 배우지 않은 스킬"
		return
	if id == "iron_chant":
		_cast_iron_chant()
		return
	var tgt := _nearest_monster()
	if id == "phase_step":
		_cast_phase_step(tgt)
		return
	if tgt == null:
		_combat_log = "no target"
		return
	if id == "ember_bolt":
		_cast_bolt(tgt, "fire", Color(1, 0.5, 0.15), 14, 26)
	elif id == "frost_shard":
		_cast_bolt(tgt, "cold", Color(0.4, 0.7, 1.0), 10, 20)
	elif id == "storm_lance":
		_cast_storm_lance(tgt)
	else:
		if Vector2(_player.gx, _player.gy).distance_to(Vector2(tgt.gx, tgt.gy)) > ATTACK_RANGE + 0.6:
			_combat_log = "out of range"
			return
		_player_attack(tgt, id)

func _target_resist(t: ActorScript, element: String) -> int:
	match element:
		"fire": return t.res_fire
		"cold": return t.res_cold
		"light": return t.res_light
		"poison": return t.res_poison
	return 0

# 투사체 스펠(화염/냉기) — 냉기는 슬로우
func _cast_bolt(target: ActorScript, element: String, color: Color, base_min: int, base_max: int) -> void:
	if target == null or not _player.alive or _player.attack_cd > 0.0:
		return
	var skill_id := "frost_shard" if element == "cold" else "ember_bolt"
	if not _player.spend_mana(Skills.mana_cost(skill_id)):
		_combat_log = "no mana"
		return
	_player.attack_cd = CombatLib.frames_to_sec(CombatLib.sorc_fcr_frames(_player_fcr))  # FCR
	_player.play_cast(Vector2(target.gx - _player.gx, target.gy - _player.gy))
	_play_sfx("spell")
	_spells_cast += 1
	var lvl := _player.skill_level(skill_id)
	var dmg := _rng.randi_range(base_min, base_max) + lvl * 4
	dmg = Skills.apply_synergy(dmg, skill_id, _player.skills)
	_spawn_projectile(_player.position, target, dmg, element, color)
	_combat_log = "%s bolt (dmg~%d)" % [element, dmg]

# 번개 스펠 — 즉시 명중(hit-scan), 넓은 데미지 범위
func _cast_storm_lance(target: ActorScript) -> void:
	if target == null or not target.alive or not _player.alive or _player.attack_cd > 0.0:
		return
	if not _player.spend_mana(Skills.mana_cost("storm_lance")):
		return
	_player.attack_cd = CombatLib.frames_to_sec(CombatLib.sorc_fcr_frames(_player_fcr))
	_player.play_cast(Vector2(target.gx - _player.gx, target.gy - _player.gy))
	_play_sfx("spell")
	_spells_cast += 1
	var raw := _rng.randi_range(6, 30) + _player.skill_level("storm_lance") * 3
	raw = Skills.apply_synergy(raw, "storm_lance", _player.skills)
	var dmg := CombatLib.apply_resistance(raw, target.res_light)
	target.take_damage(dmg)
	_spell_hits += 1
	_flash(_player.position, target.position)
	_spawn_text(target.position, "%d⚡" % dmg, Color(1, 1, 0.4))
	if not target.alive:
		_grant_xp(target.level * 40)

func _cast_phase_step(target: ActorScript) -> void:
	if _player.skill_level("phase_step") <= 0:
		return
	if not _player.spend_mana(Skills.mana_cost("phase_step")):
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
	_combat_log = "Phase Step"

func _blink_away(target: ActorScript) -> void:
	if _player.skill_level("phase_step") <= 0:
		return
	if not _player.spend_mana(Skills.mana_cost("phase_step")):
		return
	_spells_cast += 1
	var dir := (Vector2(_player.gx, _player.gy) - Vector2(target.gx, target.gy)).normalized()
	var tx := clampf(_player.gx + dir.x * 5.0, 1.0, GRID - 2)
	var ty := clampf(_player.gy + dir.y * 5.0, 1.0, GRID - 2)
	if _walkable(tx, ty):
		_player.gx = tx
		_player.gy = ty
		_player.position = _iso(tx, ty)
	_combat_log = "Phase Step (kite)"

func _spawn_projectile(from_pos: Vector2, target: ActorScript, dmg: int, element: String = "fire", color: Color = Color(1, 0.5, 0.15)) -> void:
	var n := Sprite2D.new()
	n.texture = _tex_rect(10, 10, color)
	n.position = from_pos
	n.z_index = 50
	_world.add_child(n)
	_projectiles.append({"node": n, "target": target, "dmg": dmg, "element": element})

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
			# 스펠 속성 데미지 → 대상 해당 속성 저항/약점 적용 (Part 5 §2)
			var element := String(p.get("element", "fire"))
			var tres := _target_resist(t, element)
			var dmg: int = CombatLib.apply_resistance(int(p["dmg"]), tres)
			t.take_damage(dmg)
			_spell_hits += 1
			# 냉기 → 슬로우
			if element == "cold":
				t.slow_timer = 2.0
			# 소서리스 스펠 생명 흡혈 (Part 5 §4)
			if _player.leech_pct > 0 and _player.alive:
				var h := CombatLib.leech_life(dmg, _player.leech_pct)
				_player.life = mini(_player.max_life, _player.life + h)
				_leech_total += h
				_player.queue_redraw()
			var em := {"fire": "🔥", "cold": "❄", "light": "⚡", "poison": "☠"}
			var txt := "%d%s" % [dmg, String(em.get(element, ""))]
			if tres < 0:
				txt = "%d! 약점" % dmg
			_spawn_text(t.position, txt, Color(1, 0.55, 0.15))
			if not t.alive:
				_grant_xp(t.level * 40)
			n.queue_free()
			_projectiles.erase(p)

func _player_attack(target: ActorScript, skill_id: String) -> void:
	if target == null or not target.alive or not _player.alive or _player.attack_cd > 0.0:
		return
	var m_lvl := _player.skill_level("weapon_discipline")
	var s_lvl := _player.skill_level(skill_id)
	var use_skill := s_lvl > 0 and _player.spend_mana(Skills.mana_cost(skill_id))
	var ar_bonus := Skills.discipline_ar_pct(m_lvl)
	# 힘 → 근접 %ED (D2: str가 무기 물리 데미지 증가). 10 초과분 * 1%
	var str_ed := float(maxi(0, _player.stat_str + int(_eq["str"]) - 10)) * 1.0
	var dmg_bonus := Skills.discipline_damage_pct(m_lvl) + float(_eq["ed"]) + str_ed
	var ignore_def := false
	var label := "Attack"
	if use_skill:
		label = Skills.def_name(skill_id)
		dmg_bonus += Skills.synergy_bonus_pct(skill_id, _player.skills)
		if skill_id == "sundering_strike":
			ar_bonus += Skills.sundering_ar_pct(s_lvl)
			dmg_bonus += Skills.sundering_damage_pct(s_lvl)
		elif skill_id == "void_fury":
			dmg_bonus += Skills.void_fury_damage_pct(s_lvl)
			ignore_def = true

	_player.attack_cd = PLAYER_ATTACK_CD
	_player.play_attack(Vector2(target.gx - _player.gx, target.gy - _player.gy))
	_play_sfx("attack")
	var eff_dex := _player.stat_dex + int(_eq["dex"])
	var ar := CombatLib.character_ar(eff_dex, ar_bonus) + int(_eq["ar"])
	var def_val := 0 if ignore_def else int(target.defense)
	var chance := CombatLib.chance_to_hit(ar, def_val, _player.level, target.level)
	_attacks += 1
	if CombatLib.roll_hit(_rng, ar, def_val, _player.level, target.level):
		_hits += 1
		_play_sfx("hit")
		var dmg := CombatLib.physical_damage(_rng, _player.dmg_min, _player.dmg_max, dmg_bonus)
		if Item.lose_durability(_equipped["weapon"]):
			_recompute_player()
		var crit := CombatLib.roll_deadly_strike(_rng, Skills.discipline_deadly_strike(m_lvl))
		if crit:
			dmg *= 2
		# Hell 물리 50% 바닥 (Part 2 §3)
		dmg = CombatLib.apply_resistance(dmg, CombatLib.diff_hell_physical_floor(_difficulty))
		# 크러싱 블로우(바바리안 20%): 현재 생명 비율 감소 (Part 5 §4)
		var cb := 0
		if _class == "warden" and _rng.randf() < 0.20:
			cb = CombatLib.crushing_blow(target.life, false, String(target.get_meta("kind", "melee")) == "boss")
		target.take_damage(dmg + cb)
		# 무기 속성 데미지 (Fiery/Frozen/Shocking) — 대상 속성 저항 적용
		var edmg := 0
		var fd := int(_eq.get("fdmg", 0))
		if fd > 0:
			edmg += CombatLib.apply_resistance(fd, _target_resist(target, "fire"))
		var cd := int(_eq.get("cdmg", 0))
		if cd > 0:
			edmg += CombatLib.apply_resistance(cd, _target_resist(target, "cold"))
			target.slow_timer = 1.5   # 냉기 무기 슬로우
		var ld := int(_eq.get("ldmg", 0))
		if ld > 0:
			edmg += CombatLib.apply_resistance(ld, _target_resist(target, "light"))
		if edmg > 0:
			target.take_damage(edmg)
			_spawn_text(target.position + Vector2(-14, 0), "+%d" % edmg, Color(0.6, 0.9, 1.0))
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
	m.play_attack(Vector2(_player.gx - m.gx, _player.gy - m.gy))
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		# 플레이어 블록 판정 (Part 5 §3)
		if _player.block_val > 0 and CombatLib.roll_block(_rng, _player.block_val, _player.stat_dex, _player.level):
			_spawn_text(_player.position, "BLOCK", Color(0.6, 0.8, 1.0))
			return
		var dmg := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
		_player.take_damage(dmg)
		_damage_armor()
		_spawn_text(_player.position, str(dmg), Color(1, 0.4, 0.4))
		_apply_enchant(m)
	else:
		_spawn_text(_player.position, "miss", Color(0.85, 0.85, 0.85))

func _damage_armor() -> void:
	if Item.lose_durability(_equipped["armor"]):
		_recompute_player()
		_combat_log = "방어구 파손"

# 유니크 인챈트 원소 피해(피격 시) — 플레이어 저항 적용. 냉기는 슬로우.
func _apply_enchant(m: ActorScript) -> void:
	var el := String(m.get_meta("enchant", ""))
	if el == "":
		return
	var amt := _rng.randi_range(6, 14)
	var res := 0
	match el:
		"fire": res = _player.res_fire
		"cold": res = _player.res_cold; _player.slow_timer = 1.2
		"light": res = _player.res_light
	var d := CombatLib.apply_resistance(amt, res)
	if d > 0:
		_player.take_damage(d)
		var c := Color(1, 0.5, 0.2) if el == "fire" else (Color(0.5, 0.8, 1) if el == "cold" else Color(1, 1, 0.4))
		_spawn_text(_player.position + Vector2(0, -12), "+%d %s" % [d, el], c)

func _cast_iron_chant() -> void:
	var lvl := _player.skill_level("iron_chant")
	if lvl <= 0 or not _player.spend_mana(Skills.mana_cost("iron_chant")):
		return
	_player.bo_pct = Skills.iron_chant_bonus_pct(lvl) + Skills.synergy_bonus_pct("iron_chant", _player.skills)
	_player.bo_timer = Skills.iron_chant_duration(lvl)
	_recompute_vitals(_player)
	_bo_casts += 1
	_combat_log = "Iron Chant! +%.0f%%" % _player.bo_pct

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
	for slot in EQUIPMENT_SLOTS:
		var it: Dictionary = _equipped[slot]
		if it.is_empty():
			continue
		var eff := Item.effective_affixes(it)
		for stat in eff:
			eq[stat] = int(eq.get(stat, 0)) + int(eff[stat])
	var set_items: Array = []
	for slot in EQUIPMENT_SLOTS: set_items.append(_equipped[slot])
	var set_bonus := Item.equipped_set_bonus(set_items)
	for stat in set_bonus:
		eq[stat] = int(eq.get(stat, 0)) + int(set_bonus[stat])
	_eq = eq
	var previous_stamina_max := _stamina_max
	_stamina_max = Stamina.maximum(_player.level, _player.stat_vit)
	_stamina = _stamina_max if previous_stamina_max <= 0.0 else clampf(_stamina * _stamina_max / previous_stamina_max, 0.0, _stamina_max)
	var eff_dex := _player.stat_dex + int(eq["dex"])
	var arm_def := int(_equipped["armor"]["defense"]) if not _equipped["armor"].is_empty() else 0
	if Item.is_broken(_equipped["armor"]):
		arm_def = 0
	_player.defense = CombatLib.character_defense(eff_dex, 15) + arm_def + int(eq["def"])
	if not _equipped["weapon"].is_empty() and not Item.is_broken(_equipped["weapon"]):
		_player.dmg_min = int(_equipped["weapon"]["dmin"])
		_player.dmg_max = int(_equipped["weapon"]["dmax"])
	else:
		_player.dmg_min = 1
		_player.dmg_max = 2
	if _class == "arcanist":
		_player.base_max_life = 40 + 2 * _player.stat_vit + _player.level + int(eq["life"])
		_player.base_max_mana = 35 + 2 * _player.stat_energy + 2 * _player.level + int(eq["mana"])
	else:
		_player.base_max_life = CombatLib.warden_max_life(_player.stat_vit, _player.level) + int(eq["life"])
		_player.base_max_mana = CombatLib.warden_max_mana(_player.stat_energy, _player.level) + int(eq["mana"])
	# 속성 저항 = 기본 + 장비(res_all + 개별) + 난이도 페널티 (Part 2 §3, Part 5 §2)
	var pen := CombatLib.diff_player_resist_penalty(_difficulty)
	var rall := int(eq.get("res_all", 0))
	_player.res_fire = _base_res_fire + rall + int(eq.get("res_fire", 0)) + pen
	_player.res_cold = _base_res_cold + rall + int(eq.get("res_cold", 0)) + pen
	_player.res_light = _base_res_light + rall + int(eq.get("res_light", 0)) + pen
	_player.res_poison = _base_res_poison + rall + int(eq.get("res_poison", 0)) + pen
	_recompute_vitals(_player)

func _grant_xp(amount: int) -> void:
	_player.xp += amount
	var need := _player.level * 100
	while _player.xp >= need and _player.level < 20:
		_player.xp -= need
		_player.level += 1
		_stat_points += 5                       # D2: 레벨당 스탯 5점
		_player.skill_points += 1               # D2: 레벨당 스킬 1점
		if _auto_quit:
			_auto_spend_points()                # 검증: 자동 분배
		_recompute_player()
		if _merc != null:
			_merc.level = _player.level
			_merc_scale_stats()
		_play_sfx("levelup", -3.0)
		_combat_log = "LEVEL UP → %d" % _player.level
		need = _player.level * 100

func _apply_quest_kill(target: String, rank: String) -> void:
	var completed := Quest.apply_kill(_quest_defs, _quest_state, _act, target, rank)
	for id in completed:
		var definition := Quest.definition_by_id(_quest_defs, String(id))
		var reward: Dictionary = definition.get("reward", {})
		var reward_gold := int(reward.get("gold", 0))
		var reward_skills := int(reward.get("skill_points", 0))
		_gold += reward_gold
		_player.skill_points += reward_skills
		if _auto_quit and reward_skills > 0:
			_auto_spend_points()
		_combat_log = "퀘스트 완료: %s (+%dg)" % [String(definition.get("name", id)), reward_gold]
		_spawn_text(_player.position + Vector2(0, -48), "QUEST COMPLETE", Color(1.0, 0.82, 0.3))

func _on_monster_died(m: Node) -> void:
	_kills += 1
	_play_sfx("death")
	_apply_quest_kill(String(m.get_meta("kind", "melee")), String(m.get_meta("rank", "")))
	# 액트 보스 처치 → 퀘스트 완료
	if _boss != null and m == _boss:
		_complete_act(m)
	# 등급별 강화 드롭 (챔피언/유니크 = 더 많은 롤 + MF + ilvl 보너스)
	var rank := String(m.get_meta("rank", ""))
	var rolls := 1
	var mf := _player_mf
	var mlvl := int(m.level)
	if rank == "champion":
		rolls = 2; mf += 120; mlvl += 2
	elif rank == "unique":
		rolls = 3; mf += 280; mlvl += 3
	var dropped := 0
	for i in rolls:
		var it := Item.roll_drop(_rng, mlvl, mf)
		if not it.is_empty():
			_items_dropped += 1
			dropped += 1
			_spawn_ground(it, m.gx, m.gy)
			_combat_log = "%s dropped %s" % [m.actor_name, Item.display_name(it)]
	# 유니크는 최소 1개 보장(매직)
	if rank == "unique" and dropped == 0:
		var base: Dictionary = Item.WEAPON_BASES[_rng.randi_range(0, Item.WEAPON_BASES.size() - 1)]
		var it2 := Item.generate(_rng, base, mlvl + 8, "magic")
		_items_dropped += 1
		_spawn_ground(it2, m.gx, m.gy)
		_combat_log = "%s dropped %s" % [m.actor_name, Item.display_name(it2)]
	elif dropped == 0:
		_combat_log = "%s slain" % m.actor_name
	# 포션 드롭(생명 25% / 마나 12%, 등급 보너스) — 땅에 떨어져 줍기
	var pot_bonus := 0.15 if rank != "" else 0.0
	var pr := _rng.randf()
	if pr < 0.25 + pot_bonus:
		_spawn_ground(_make_potion("health", mini(5, 1 + int(m.level) / 4)), m.gx, m.gy)
	elif pr < 0.37 + pot_bonus:
		_spawn_ground(_make_potion("mana", mini(5, 1 + int(m.level) / 4)), m.gx, m.gy)
	# 보석/재료는 수량 제한 없이 동일 id로 합쳐진다.
	if _rng.randf() < 0.12 + pot_bonus:
		var gems := ["ruby", "sapphire", "topaz", "emerald"]
		_spawn_ground(_make_material(String(gems[_rng.randi_range(0, gems.size() - 1)])), m.gx, m.gy)
	# 골드 드롭(몬스터 레벨·등급 스케일)
	if _rng.randf() < 0.7:
		var rank_mult := 1.0
		if rank == "champion": rank_mult = 2.5
		elif rank == "unique": rank_mult = 5.0
		var amt := int(_rng.randi_range(3, 8) * int(m.level) * rank_mult)
		_spawn_ground(_make_gold(amt), m.gx + _rng.randf_range(-0.3, 0.3), m.gy + _rng.randf_range(-0.3, 0.3))

func _make_gold(amount: int) -> Dictionary:
	return {"name": "%d Gold" % amount, "slot": "gold", "amount": amount, "quality": "normal", "affixes": {}, "prefix": "", "suffix": ""}

# 아이템 판매가(품질 + 접사 수 기반)
func _item_value(it: Dictionary) -> int:
	var q := String(it["quality"])
	var table := {"normal": 8, "magic": 40, "rare": 110, "set": 220, "unique": 300}
	var base: int = int(table.get(q, 10))
	var affix_cnt := 0
	for _k in it.get("affixes", {}):
		affix_cnt += 1
	return base + affix_cnt * 15 + int(it.get("ilvl", 1)) * 2

func _make_potion(ptype: String, tier: int = 1) -> Dictionary:
	var nm := "Healing Potion" if ptype == "health" else "Mana Potion"
	return {"name": nm, "slot": "potion", "ptype": ptype, "tier": tier, "quality": "normal", "affixes": {}, "prefix": "", "suffix": ""}

func _make_material(id: String, amount: int = 1) -> Dictionary:
	return {"name": id.capitalize(), "id": id, "amount": amount, "slot": "material", "quality": "normal", "affixes": {}, "prefix": "", "suffix": ""}

func _spawn_ground(it: Dictionary, gx: float, gy: float) -> void:
	var n := Node2D.new()
	var slot := String(it["slot"])
	var is_pot := slot == "potion"
	var is_gold := slot == "gold"
	var col: Color = Item.quality_color(String(it["quality"]))
	if is_pot:
		col = Color(0.85, 0.2, 0.2) if String(it["ptype"]) == "health" else Color(0.3, 0.45, 0.95)
	elif is_gold:
		col = Color(1.0, 0.85, 0.25)
	var spr := Sprite2D.new()
	var icon_kind := "shield"
	var icon_seed := 0
	match slot:
		"weapon": icon_kind = "sword"
		"potion": icon_kind = "potion"
		"gold": icon_kind = "coin"
		"material":
			var material_id := String(it.get("id", "material"))
			icon_kind = "rune" if material_id.begins_with("rune_") else "gem"
			var gem_ids := ["ruby", "sapphire", "topaz", "emerald"]
			icon_seed = maxi(0, gem_ids.find(material_id))
	var atlas_id := icon_kind
	if icon_kind == "gem":
		atlas_id = String(it.get("id", "ruby"))
	var compiled := _assets.texture(atlas_id)
	if compiled != null:
		spr.texture = compiled
	elif _assets.allows_fallback():
		_assets.record_fallback("icon/" + atlas_id)
		spr.texture = PixelGen.icon(icon_kind, icon_seed)
	spr.scale = Vector2(0.4, 0.4) if is_gold else (Vector2(0.55, 0.55) if is_pot else Vector2(0.8, 0.8))
	spr.modulate = col
	n.add_child(spr)
	var lbl := Label.new()
	lbl.text = Item.display_name(it)
	lbl.position = Vector2(-30, -30)
	lbl.add_theme_font_size_override("font_size", _accessibility.font_size(12))
	lbl.add_theme_color_override("font_color", col)
	n.add_child(lbl)
	n.position = _iso(gx, gy)
	n.set_meta("item", it)
	n.set_meta("gx", gx)
	n.set_meta("gy", gy)
	_world.add_child(n)
	_ground.append(n)

func _pickup(n: Node) -> void:
	var it: Dictionary = n.get_meta("item")
	if not _automation.accepts(it):
		return
	_play_sfx("pickup")
	_ground.erase(n)
	n.queue_free()
	# 골드 → 지갑
	if String(it["slot"]) == "gold":
		_gold += int(it["amount"])
		_spawn_text(_player.position, "+%d gold" % int(it["amount"]), Color(1, 0.85, 0.3))
		return
	# 포션 → 벨트(가득 차면 줍지 않음)
	if String(it["slot"]) == "potion":
		var pt := String(it["ptype"])
		var tier := int(it.get("tier", 1))
		if _automation.potion_upgrade(pt, tier):
			_spawn_text(_player.position, "%s 포션 등급 ↑%d" % [pt, tier], Color.LIME_GREEN)
		if _add_potion_to_belt(pt):
			var c := Color(0.85, 0.3, 0.3) if pt == "health" else Color(0.4, 0.6, 1.0)
			_spawn_text(_player.position, "+" + String(it["name"]), c)
		return
	if String(it["slot"]) == "material":
		_automation.add_material(it)
		_items_picked += int(it.get("amount", 1))
		_spawn_text(_player.position, "+%s ×%d" % [String(it["name"]), int(it.get("amount", 1))], Color.VIOLET)
		return
	_inventory.append(it)
	_items_picked += 1
	_spawn_text(_player.position, "+" + Item.display_name(it), Item.quality_color(String(it["quality"])))
	_auto_equip(it)
	_rebuild_inv()

func _auto_equip(it: Dictionary) -> void:
	var slot := _equipment_slot_for_item(it)
	var cur: Dictionary = _equipped[slot]
	if Item.can_equip(it, _player.level, _player.stat_str, _player.stat_dex) and _automation.should_equip(it, cur):
		if not cur.is_empty():
			_inventory.erase(cur)
			if not _automation.list_auction(cur, int(Time.get_ticks_msec() / 1000)):
				_inventory.append(cur)
		_equip(it, slot)
		_inventory.erase(it)

func _equip_from_inventory(it: Dictionary) -> void:
	var requirement_failures := Item.requirement_failures(it, _player.level, _player.stat_str, _player.stat_dex)
	if not requirement_failures.is_empty():
		_combat_log = "장착 요구조건 부족: %s" % ", ".join(requirement_failures)
		return
	var slot := _equipment_slot_for_item(it)
	var old: Dictionary = _equipped[slot]
	if not old.is_empty() and old != it:
		if not _automation.list_auction(old, int(Time.get_ticks_msec() / 1000)):
			_inventory.append(old)
	_inventory.erase(it)
	_equip(it, slot)

func _equipment_slot_for_item(it: Dictionary) -> String:
	var item_slot := String(it.get("slot", ""))
	if item_slot != "ring":
		return item_slot
	if (_equipped["ring_left"] as Dictionary).is_empty():
		return "ring_left"
	if (_equipped["ring_right"] as Dictionary).is_empty():
		return "ring_right"
	return "ring_left" if _automation.item_score(_equipped["ring_left"]) <= _automation.item_score(_equipped["ring_right"]) else "ring_right"

func _equip(it: Dictionary, target_slot: String = "") -> void:
	var slot := target_slot if not target_slot.is_empty() else _equipment_slot_for_item(it)
	_equipped[slot] = it
	_recompute_player()
	_combat_log = "equipped %s" % Item.display_name(it)
	_rebuild_inv()

func _equip_merc_from_inventory(it: Dictionary) -> void:
	if not Mercenary.can_equip(it, _merc.level if _merc != null else _player.level):
		_combat_log = "동료 장착 요구조건 부족: %s" % Item.requirement_text(it)
		return
	var slot := String(it["slot"])
	var old: Dictionary = _merc_equipped[slot]
	if not old.is_empty() and old != it:
		_inventory.append(old)
	_inventory.erase(it)
	_merc_equipped[slot] = it
	if _merc != null:
		_merc_scale_stats()
	_combat_log = "Ember Scout equipped %s" % Item.display_name(it)
	_rebuild_inv()

func _deposit_to_stash(it: Dictionary) -> void:
	if Stash.deposit(it, _inventory, _stash):
		_combat_log = "보관함 이동: %s" % Item.display_name(it)
	else:
		_combat_log = "보관함이 가득 찼습니다 (%d/%d)" % [_stash.size(), Stash.CAPACITY]
	_rebuild_inv()

func _withdraw_from_stash(it: Dictionary) -> void:
	if Stash.withdraw(it, _inventory, _stash):
		_combat_log = "가방 이동: %s" % Item.display_name(it)
	_rebuild_inv()

func _toggle_bag() -> void:
	_inv_panel.visible = not _inv_panel.visible
	if _inv_panel.visible:
		_rebuild_inv()

var _vendor_gold_lbl: Label
func _build_vendor() -> void:
	var vb := VBoxContainer.new()
	vb.position = Vector2(12, 10)
	vb.custom_minimum_size = Vector2(336, 280)
	_vendor_panel.add_child(vb)
	var head := Label.new()
	head.text = "상인 / Vendor"
	head.add_theme_font_size_override("font_size", _accessibility.font_size(20))
	vb.add_child(head)
	_vendor_gold_lbl = Label.new()
	_vendor_gold_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vb.add_child(_vendor_gold_lbl)
	_vendor_btn(vb, "생명 포션 구매 (%dg)" % COST_HP_POT, func(): _buy_potion("health"))
	_vendor_btn(vb, "마나 포션 구매 (%dg)" % COST_MP_POT, func(): _buy_potion("mana"))
	_vendor_btn(vb, "장착 장비 모두 수리", func(): _repair_equipped())
	_vendor_btn(vb, "웨이포인트 순환 이동", func(): _travel_waypoint(0))
	_vendor_btn(vb, "인벤토리 전부 판매", func(): _sell_all())
	_vendor_btn(vb, "도박 / 무작위 아이템", func(): _gamble())
	_vendor_btn(vb, "자동 습득 등급 변경", func(): _cycle_automation("pickup_min"))
	_vendor_btn(vb, "자동 장착 등급 변경", func(): _cycle_automation("equip_min"))
	_vendor_btn(vb, "자동 경매 등급 변경", func(): _cycle_automation("auction_min"))

func _cycle_automation(key: String) -> void:
	var levels := ["normal", "magic", "rare", "set", "unique"]
	var current := String(_automation.get(key))
	_automation.set(key, levels[(levels.find(current) + 1) % levels.size()])
	_combat_log = "%s → %s" % [key, String(_automation.get(key))]
	_rebuild_inv()

func _vendor_btn(vb: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	b.pressed.connect(cb)
	vb.add_child(b)

func _toggle_vendor() -> void:
	_vendor_panel.visible = not _vendor_panel.visible
	_refresh_vendor()

func _travel_waypoint(direction: int) -> void:
	var target := Waypoint.cycle(_waypoint_defs, _waypoint_state, _act) if direction == 0 else Waypoint.adjacent(_waypoint_defs, _waypoint_state, _act, direction)
	if target.is_empty():
		_combat_log = "이동 가능한 웨이포인트 없음"
		return
	_dlevel = (_act - 1) * ACT_LEN + int(target.get("floor", 1))
	Waypoint.unlock(_waypoint_defs, _waypoint_state, _act, _level_in_act())
	for ground_item in _ground:
		if is_instance_valid(ground_item):
			ground_item.queue_free()
	_ground.clear()
	for projectile in _projectiles:
		var projectile_node: Node = projectile.get("node", null)
		if is_instance_valid(projectile_node):
			projectile_node.queue_free()
	_projectiles.clear()
	_generate_dungeon()
	_build_minimap_tex()
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)
	if _merc != null:
		_merc.gx = _player.gx + 1
		_merc.gy = _player.gy
		_merc.position = _iso(_merc.gx, _merc.gy)
	_spawn_dungeon_monsters()
	if is_instance_valid(_cam):
		_cam.position = _player.position
	_combat_log = "웨이포인트 이동: %s" % Waypoint.current_name(_waypoint_defs, _waypoint_state)
	_refresh_vendor()

# ── 캐릭터 성장 패널 ──
func _build_char_panel() -> void:
	_char_vbox = VBoxContainer.new()
	_char_vbox.position = Vector2(12, 10)
	_char_vbox.custom_minimum_size = Vector2(360, 460)
	_char_panel.add_child(_char_vbox)
	_rebuild_char_panel()

func _class_skill_ids() -> Array:
	return ["ember_bolt", "frost_shard", "storm_lance", "phase_step"] if _class == "arcanist" else ["sundering_strike", "void_fury", "iron_chant", "weapon_discipline"]

func _skill_label(id: String) -> String:
	var names := {"ember_bolt": "잿불 화살", "frost_shard": "서리 파편", "storm_lance": "폭풍 창", "phase_step": "위상 도약",
		"sundering_strike": "파쇄 일격", "void_fury": "공허 격노", "iron_chant": "철의 성가", "weapon_discipline": "무기 수련"}
	return String(names.get(id, id))

func _rebuild_char_panel() -> void:
	if _char_vbox == null:
		return
	for c in _char_vbox.get_children():
		c.queue_free()
	var head := Label.new()
	head.add_theme_font_size_override("font_size", _accessibility.font_size(20))
	head.text = "캐릭터 Lv%d\n스탯 포인트: %d   스킬 포인트: %d" % [_player.level, _stat_points, _player.skill_points]
	_char_vbox.add_child(head)
	# 스탯 분배
	for pair in [["str", "힘 %d" % _player.stat_str], ["dex", "민첩 %d" % _player.stat_dex], ["vit", "활력 %d" % _player.stat_vit], ["energy", "에너지 %d" % _player.stat_energy]]:
		var sid: String = pair[0]
		var b := Button.new()
		b.text = "+ %s" % pair[1]
		b.custom_minimum_size = Vector2(344, 44)
		b.add_theme_font_size_override("font_size", _accessibility.font_size(18))
		b.disabled = _stat_points <= 0
		b.pressed.connect(func(): _spend_stat(sid))
		_char_vbox.add_child(b)
	var sep := Label.new()
	sep.text = "스킬"
	_char_vbox.add_child(sep)
	for sk in _class_skill_ids():
		var b2 := Button.new()
		var required_level := int(Skills.DEFS[sk].get("required_level", 1))
		b2.text = "+ %s (Lv%d / 요구%d / 시너지+%.0f%%)" % [_skill_label(sk), _player.skill_level(sk), required_level, Skills.synergy_bonus_pct(sk, _player.skills)]
		b2.custom_minimum_size = Vector2(344, 44)
		b2.add_theme_font_size_override("font_size", _accessibility.font_size(18))
		b2.disabled = _player.skill_points <= 0 or not Skills.can_invest(sk, _player.skills, _player.level)
		b2.pressed.connect(func(): _spend_skill(sk))
		_char_vbox.add_child(b2)

func _toggle_char() -> void:
	_char_panel.visible = not _char_panel.visible
	if _char_panel.visible:
		_rebuild_char_panel()

func _spend_stat(stat: String) -> void:
	if _stat_points <= 0:
		return
	_stat_points -= 1
	match stat:
		"str": _player.stat_str += 1
		"dex": _player.stat_dex += 1
		"vit": _player.stat_vit += 1
		"energy": _player.stat_energy += 1
	_recompute_player()
	_rebuild_char_panel()

func _spend_skill(id: String) -> void:
	if _player.skill_points <= 0 or not Skills.can_invest(id, _player.skills, _player.level):
		return
	_player.skill_points -= 1
	_player.skills[id] = _player.skill_level(id) + 1
	_rebuild_char_panel()

# 오토플레이 자동 분배(검증): 클래스별 우선순위
func _auto_spend_points() -> void:
	while _stat_points > 0:
		if _class == "arcanist":
			_spend_stat("energy" if _player.stat_energy < _player.stat_vit + 20 else "vit")
		else:
			_spend_stat("vit" if _player.stat_vit <= _player.stat_str else "str")
	while _player.skill_points > 0:
		var candidate := ""
		var candidate_level := Skills.MAX_LEVEL + 1
		for skill_id in _class_skill_ids():
			var current_level := _player.skill_level(skill_id)
			if Skills.can_invest(skill_id, _player.skills, _player.level) and current_level < candidate_level:
				candidate = skill_id
				candidate_level = current_level
		if candidate.is_empty():
			break
		_spend_skill(candidate)

func _refresh_vendor() -> void:
	if _vendor_gold_lbl:
		_vendor_gold_lbl.text = "골드 %d / 벨트 HP%d MP%d / 가방 %d\n수리 %dg / 도박 %dg" % [_gold, _belt_hp, _belt_mp, _inventory.size(), _repair_equipped_cost(), _gamble_cost()]

func _repair_equipped_cost() -> int:
	var total := 0
	for slot in EQUIPMENT_SLOTS: total += Item.repair_cost(_equipped[slot])
	return total

func _repair_equipped() -> void:
	var cost := _repair_equipped_cost()
	if cost <= 0:
		_combat_log = "수리할 장비 없음"
		return
	if _gold < cost:
		_combat_log = "골드 부족 (수리 %dg)" % cost
		return
	_gold -= cost
	for slot in EQUIPMENT_SLOTS: Item.repair(_equipped[slot])
	_recompute_player()
	_combat_log = "장비 수리 완료 (-%dg)" % cost
	_rebuild_inv()
	_refresh_vendor()

func _buy_potion(ptype: String) -> void:
	var cost := COST_HP_POT if ptype == "health" else COST_MP_POT
	if _gold < cost:
		_combat_log = "골드 부족"
		return
	if not _add_potion_to_belt(ptype):
		_combat_log = "벨트 가득참"
		return
	_gold -= cost
	_combat_log = "%s 포션 구매" % ("생명" if ptype == "health" else "마나")
	_refresh_vendor()

func _gamble_cost() -> int:
	return 200 + _player.level * 45

# 도박: 골드 지불 → 무작위 아이템(매직 70% / 레어 22% / 유니크 8%)
func _gamble() -> void:
	var cost := _gamble_cost()
	if _gold < cost:
		_combat_log = "골드 부족 (도박 %dg)" % cost
		return
	_gold -= cost
	_gambles += 1
	var base: Dictionary
	var base_roll := _rng.randf()
	if base_roll < 0.42:
		base = Item.WEAPON_BASES[_rng.randi_range(0, Item.WEAPON_BASES.size() - 1)]
	elif base_roll < 0.84:
		base = Item.ARMOR_BASES[_rng.randi_range(0, Item.ARMOR_BASES.size() - 1)]
	else:
		base = Item.ACCESSORY_BASES[_rng.randi_range(0, Item.ACCESSORY_BASES.size() - 1)]
	var ilvl := _player.level + 5
	var r := _rng.randf() * 100.0
	var q := "magic"
	if r < 8.0 and Item.UNIQUES.has(String(base["name"])):
		q = "unique"
	elif r < 18.0 and Item.SETS.has(String(base["name"])):
		q = "set"
	elif r < 40.0:
		q = "rare"
	var it := Item.generate(_rng, base, ilvl, q)
	_inventory.append(it)
	_combat_log = "도박(%dg): %s" % [cost, Item.display_name(it)]
	_rebuild_inv()
	_refresh_vendor()

func _sell_all() -> void:
	if _inventory.is_empty():
		return
	var total := 0
	var cnt := _inventory.size()
	for it in _inventory:
		total += _item_value(it)
	_gold += total
	_gold_sold += total
	_inventory.clear()
	_combat_log = "%d개 판매 → +%dg" % [cnt, total]
	_rebuild_inv()
	_refresh_vendor()

func _equipped_label(slot: String) -> String:
	var it: Dictionary = _equipped[slot]
	if it.is_empty():
		return "-"
	if bool(it.get("indestructible", false)):
		return "%s (불괴)" % Item.display_name(it)
	return "%s (%d/%d)%s" % [Item.display_name(it), Item.durability(it), Item.durability_max(it), " 파손" if Item.is_broken(it) else ""]

func _rebuild_inv() -> void:
	if _inv_vbox == null:
		return
	for c in _inv_vbox.get_children():
		c.queue_free()
	var wn := _equipped_label("weapon")
	var an := _equipped_label("armor")
	var rln := _equipped_label("ring_left")
	var rrn := _equipped_label("ring_right")
	var mn := _equipped_label("amulet")
	var merc_weapon := Item.display_name(_merc_equipped["weapon"]) if not (_merc_equipped["weapon"] as Dictionary).is_empty() else "-"
	var merc_armor := Item.display_name(_merc_equipped["armor"]) if not (_merc_equipped["armor"] as Dictionary).is_empty() else "-"
	var head := Label.new()
	head.text = "무기: %s\n방어구: %s\n반지 좌: %s\n반지 우: %s\n목걸이: %s\n동료 무기: %s\n동료 방어구: %s\n가방 %d / 보관함 %d/%d / 재료 %d" % [wn, an, rln, rrn, mn, merc_weapon, merc_armor, _inventory.size(), _stash.size(), Stash.CAPACITY, _automation.materials.size()]
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_vbox.add_child(head)
	for it in _inventory:
		var row := VBoxContainer.new()
		var btn := Button.new()
		btn.text = "%s\n%s / %s" % [Item.display_name(it), Item.affix_text(it), Item.requirement_text(it)]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 52
		btn.add_theme_font_size_override("font_size", _accessibility.font_size(14))
		btn.add_theme_color_override("font_color", Item.quality_color(String(it["quality"])))
		btn.disabled = not Item.can_equip(it, _player.level, _player.stat_str, _player.stat_dex)
		var captured: Dictionary = it
		btn.pressed.connect(func(): _equip_from_inventory(captured))
		row.add_child(btn)
		var actions := HBoxContainer.new()
		if String(it.get("slot", "")) in Mercenary.SLOTS:
			var merc_btn := Button.new()
			merc_btn.text = "동료"
			merc_btn.tooltip_text = "Ember Scout에게 장착"
			merc_btn.disabled = not Mercenary.can_equip(it, _merc.level if _merc != null else _player.level)
			merc_btn.pressed.connect(func(): _equip_merc_from_inventory(captured))
			merc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(merc_btn)
		var stash_btn := Button.new()
		stash_btn.text = "보관"
		stash_btn.tooltip_text = "개인 보관함으로 이동"
		stash_btn.pressed.connect(func(): _deposit_to_stash(captured))
		stash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(stash_btn)
		var protect := Button.new()
		protect.text = "보호됨" if bool(it.get("salvage_protected", false)) else "분해 허용"
		protect.tooltip_text = "경매 만료 시 자동 분해 금지 전환"
		protect.pressed.connect(func():
			captured["salvage_protected"] = not bool(captured.get("salvage_protected", false))
			_rebuild_inv()
		)
		protect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(protect)
		row.add_child(actions)
		_inv_vbox.add_child(row)
	if not _stash.is_empty():
		var stash_header := Label.new()
		stash_header.text = "개인 보관함"
		stash_header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
		_inv_vbox.add_child(stash_header)
	for stored in _stash:
		var stash_row := HBoxContainer.new()
		var stash_label := Label.new()
		stash_label.text = Item.display_name(stored)
		stash_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stash_label.add_theme_color_override("font_color", Item.quality_color(String(stored.get("quality", "normal"))))
		stash_row.add_child(stash_label)
		var withdraw := Button.new()
		withdraw.text = "꺼내기"
		var captured_stored: Dictionary = stored
		withdraw.pressed.connect(func(): _withdraw_from_stash(captured_stored))
		stash_row.add_child(withdraw)
		_inv_vbox.add_child(stash_row)

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
	lbl.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	_world.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -28), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.finished.connect(lbl.queue_free)
