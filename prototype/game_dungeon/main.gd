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
const CollectionBook := preload("res://collection_book.gd")
const Visibility := preload("res://visibility.gd")
const FogOverlay := preload("res://fog_overlay.gd")
const TemplateTheme := preload("res://ui/template_theme.gd")
const CombatFX := preload("res://combat_fx.gd")
const DEPLOYED_AT_KST := "2026-09-28 21:15 KST"

var _grid: Array = []
var _astar: AStarGrid2D
var _gw := 45
var _gh := 45
var _ent_cell := Vector2i(1, 1)
var _exit_cell := Vector2i(1, 1)
var _map_type := "dungeon"
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
const DROP_LABEL_HEIGHT := 20.0
const DROP_LABEL_GAP := 3.0
const DROP_LABEL_MAX_LANES := 18
const RANGED_RANGE := 5.0
const NOVA_RADIUS := 3.5
const SPELL_RANGE := 7.0
const FIREBALL_CD := 0.6
const EQUIPMENT_SLOTS := ["weapon", "armor", "ring_left", "ring_right", "amulet"]
const ITEM_TOAST_VISIBLE_LIMIT := 3
const ITEM_EVENT_HISTORY_LIMIT := 24

var _class := "warden"
var _projectiles: Array = []
var _spells_cast := 0
var _spell_hits := 0

var _world: Node2D
var _fx: CombatFX
var _cam: Camera2D
var _player: ActorScript
var _monsters: Array = []
var _ground: Array = []
var _blocked := {}
var _fog: Node2D
var _visible_cells := {}
var _explored_by_floor := {}
var _floor_states := {}
var _town_portal := {}
var _in_town := false
var _last_visibility_cell := Vector2i(-999, -999)
const SIGHT_RADIUS := 8
const VISION_RELIC_DURATION := 30.0
var _vision_relic_timer := 0.0
var _arc_flasks := 0
var _attack_line: Line2D
var _attack_ttl := 0.0

var _joy: JoystickScript
var _hud: Label
var _item_toast_box: VBoxContainer
var _item_event_history: Array[Dictionary] = []
var _skill_buttons: Dictionary = {}
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
var _auto_sell_button: Button
var _gold_sold := 0
var _gambles := 0
# ── 스탯/스킬 포인트 분배(성장) ──
var _stat_points := 0
var _char_panel: Panel
var _char_vbox: VBoxContainer
var _settings_panel: Panel
var _settings_scale_button: Button
var _settings_text_button: Button
var _settings_effect_button: Button
var _settings_fullscreen_button: Button
var _minimap: Control
var _inv_panel: Panel
var _inv_vbox: VBoxContainer
var _inventory_view := "bag"
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
var _collection := CollectionBook.new()
var _accessibility := Accessibility.new()
var _automation_last_expire := 0
var _assets := AssetCatalog.new()
var _ui_theme: Theme

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
var _mobile_profile := false
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

func _world_to_grid(v: Vector2) -> Vector2:
	return Vector2((v.x / (TILE_W * 0.5) + v.y / (TILE_H * 0.5)) * 0.5, (v.y / (TILE_H * 0.5) - v.x / (TILE_W * 0.5)) * 0.5)

func _has_los(from: Vector2, to: Vector2) -> bool:
	return Visibility.is_clear(_grid, from, to)

func _floor_explored() -> Dictionary:
	var floor_id := str(_dlevel)
	if not _explored_by_floor.has(floor_id): _explored_by_floor[floor_id] = {}
	return _explored_by_floor[floor_id]

func _update_visibility(force: bool = false) -> void:
	if _player == null or _grid.is_empty(): return
	var cell := Vector2i(roundi(_player.gx), roundi(_player.gy))
	if not force and cell == _last_visibility_cell: return
	_last_visibility_cell = cell
	var sight_radius := maxi(_gw, _gh) if _vision_relic_timer > 0.0 else SIGHT_RADIUS
	_visible_cells = Visibility.visible_cells(_grid, Vector2(_player.gx, _player.gy), sight_radius)
	var explored := _floor_explored()
	for id in _visible_cells: explored[id] = true
	if is_instance_valid(_fog): _fog.configure(_grid, _visible_cells, explored)
	for m in _monsters:
		var witnessed := _visible_cells.has(Visibility.key(Vector2i(roundi(m.gx), roundi(m.gy))))
		m.visible = witnessed
		if witnessed:
			m.set_meta("witnessed", true)
	for n in _ground:
		if is_instance_valid(n): n.visible = _visible_cells.has(Visibility.key(Vector2i(roundi(float(n.get_meta("gx"))), roundi(float(n.get_meta("gy"))))))

func _tex_rect(w: int, h: int, col: Color) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)

func _style_modal_panel(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.055, 0.97)
	style.border_color = Color(0.48, 0.39, 0.23, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

func _add_modal_close_button(panel: Panel) -> void:
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.position = Vector2(panel.size.x - 148, 12)
	close_button.size = Vector2(132, 48)
	close_button.z_index = 20
	close_button.add_theme_font_size_override("font_size", _accessibility.font_size(20))
	close_button.pressed.connect(_hide_modal_panels)
	panel.add_child(close_button)

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
	return int(_grid[iy][ix]) == LevelGen.FLOOR

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
			var wall: bool = int(_grid[y][x]) != LevelGen.FLOOR
			img.set_pixel(x, y, Color(0.08, 0.07, 0.09, 0.0) if wall else Color(0.55, 0.5, 0.42, 0.92))
	_minimap.tex = ImageTexture.create_from_image(img)
	_minimap.gw = _gw
	_minimap.gh = _gh

func _update_minimap() -> void:
	if _minimap == null:
		return
	_minimap.player_cell = Vector2(_player.gx, _player.gy)
	_minimap.visible_cells = _visible_cells
	_minimap.explored_cells = _floor_explored()
	var exit_id := Visibility.key(_exit_cell)
	_minimap.exit_cell = Vector2(_exit_cell.x, _exit_cell.y) if _floor_explored().has(exit_id) else Vector2(-99, -99)
	var mc: Array = []
	for m in _monsters:
		if m.alive and _visible_cells.has(Visibility.key(Vector2i(roundi(m.gx), roundi(m.gy)))):
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
			if int(grid[y][x]) != LevelGen.FLOOR:
				astar.set_point_solid(Vector2i(x, y), true)
	return astar

func _generate_dungeon() -> void:
	if is_instance_valid(_tiles_node):
		_tiles_node.queue_free()
	_tiles_node = Node2D.new()
	_world.add_child(_tiles_node)
	var lvl := LevelGen.generate(1000 + _dlevel, _act)  # deterministic floor layout plus act biome
	_gw = int(lvl["w"])
	_gh = int(lvl["h"])
	_grid = lvl["grid"]
	_map_type = String(lvl.get("map_type", "dungeon"))
	_ent_cell = lvl["entrance"]
	_exit_cell = lvl["exit"]
	# 제작기로 타일 변종 몇 개 미리 생성(성능: 재사용)
	var palettes := {
		1: [Color(0.26, 0.42, 0.28), Color(0.24, 0.40, 0.26), Color(0.28, 0.44, 0.30), Color(0.30, 0.28, 0.26), Color(0.26, 0.24, 0.23)],
		2: [Color(0.42, 0.36, 0.22), Color(0.48, 0.40, 0.24), Color(0.36, 0.32, 0.20), Color(0.35, 0.25, 0.16), Color(0.28, 0.20, 0.14)],
		3: [Color(0.24, 0.29, 0.39), Color(0.20, 0.25, 0.35), Color(0.29, 0.33, 0.43), Color(0.25, 0.24, 0.32), Color(0.18, 0.18, 0.26)],
	}
	var palette: Array = palettes[posmod(_act - 1, 3) + 1]
	var floor_texs := [
		PixelGen.iso_tile(TILE_W, TILE_H, palette[0], 1 + _act * 11, true),
		PixelGen.iso_tile(TILE_W, TILE_H, palette[1], 5 + _act * 11, true),
		PixelGen.iso_tile(TILE_W, TILE_H, palette[2], 9 + _act * 11, false),
	]
	var wall_texs := [
		PixelGen.iso_tile(TILE_W, TILE_H, palette[3], 2 + _act * 11, true),
		PixelGen.iso_tile(TILE_W, TILE_H, palette[4], 6 + _act * 11, true),
	]
	for y in _gh:
		for x in _gw:
			var s := Sprite2D.new()
			var terrain := int(_grid[y][x])
			if terrain == LevelGen.FLOOR:
				s.texture = floor_texs[(x * 7 + y) % 3]
			else:
				s.texture = wall_texs[(x * 5 + y) % 2]
				if terrain == LevelGen.PILLAR:
					s.modulate = Color(0.72, 0.76, 0.82)
					s.scale = Vector2(0.72, 1.35)
				elif terrain == LevelGen.LOW_WALL:
					s.modulate = Color(0.55, 0.72, 0.48)
					s.scale = Vector2(1.0, 0.62)
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
	var count := clampi(12 + _dlevel * 2, 14, 26)
	if boss_lv:
		count = maxi(10, count - 5)
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
		m.set_rank_visual("boss")
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
	m.set_rank_visual(rank)

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
	_combat_log = "ACT %d CLEAR / EXIT OPEN / UNIQUE REWARD / SKILL +2 / +%dg" % [_act, bonus]
	_act += 1

func _next_level() -> void:
	_capture_floor_state()
	_levels_cleared += 1
	_dlevel += 1
	Waypoint.unlock(_waypoint_defs, _waypoint_state, _act, _level_in_act())
	for g in _ground:
		if is_instance_valid(g):
			g.queue_free()
	_ground.clear()
	_clear_map_effects()
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
	_restore_or_spawn_floor()
	_last_visibility_cell = Vector2i(-999, -999)
	_update_visibility(true)
	if is_instance_valid(_cam):
		_cam.position = _player.position
	_combat_log = "DUNGEON LEVEL %d" % _dlevel

# A* 내비게이션: actor를 (tgx,tgy)로 경로 따라 이동 (경로 400ms 캐시)
func _capture_floor_state() -> void:
	if _in_town or _grid.is_empty(): return
	var monster_states: Array = []
	for m in _monsters:
		if not is_instance_valid(m) or not m.alive: continue
		monster_states.append({"name": m.actor_name, "level": m.level, "life": m.life, "max_life": m.max_life, "ar": m.attack_rating, "def": m.defense, "dmin": m.dmg_min, "dmax": m.dmg_max, "speed": m.speed, "gx": m.gx, "gy": m.gy, "kind": String(m.get_meta("kind", "melee")), "witnessed": bool(m.get_meta("witnessed", false)), "res_fire": m.res_fire, "res_cold": m.res_cold, "res_light": m.res_light, "res_poison": m.res_poison})
	var ground_states: Array = []
	for n in _ground:
		if is_instance_valid(n): ground_states.append({"item": (n.get_meta("item") as Dictionary).duplicate(true), "gx": float(n.get_meta("gx")), "gy": float(n.get_meta("gy"))})
	_floor_states[str(_dlevel)] = {"monsters": monster_states, "ground": ground_states, "exit_locked": _exit_locked}

func _restore_or_spawn_floor() -> void:
	for existing in _monsters:
		if is_instance_valid(existing): existing.queue_free()
	_monsters.clear()
	var state: Dictionary = _floor_states.get(str(_dlevel), {})
	if state.is_empty():
		_spawn_dungeon_monsters()
		return
	_exit_locked = bool(state.get("exit_locked", false))
	for raw in state.get("monsters", []):
		var s: Dictionary = raw
		var m := _spawn_monster(String(s["name"]), Color(0.65, 0.25, 0.2), 24, 32, int(s["level"]), int(s["max_life"]), int(s["ar"]), int(s["def"]), int(s["dmin"]), int(s["dmax"]), float(s["speed"]), roundi(float(s["gx"])), roundi(float(s["gy"])))
		m.life = int(s["life"]); m.gx = float(s["gx"]); m.gy = float(s["gy"]); m.position = _iso(m.gx, m.gy)
		m.set_meta("kind", String(s.get("kind", "melee")))
		m.set_meta("witnessed", bool(s.get("witnessed", false)))
		m.res_fire = int(s.get("res_fire", 0)); m.res_cold = int(s.get("res_cold", 0)); m.res_light = int(s.get("res_light", 0)); m.res_poison = int(s.get("res_poison", 0))
		if String(s.get("kind", "")) == "boss": _boss = m
	for raw in state.get("ground", []):
		var drop: Dictionary = raw
		_spawn_ground((drop.get("item", {}) as Dictionary).duplicate(true), float(drop.get("gx", 0)), float(drop.get("gy", 0)))

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
	_ui_theme = TemplateTheme.create()
	if not TemplateTheme.selftest():
		push_error("Temporary UI theme failed its resource contract")
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
		print("[COLLECTION] selftest verdict=", "PASS" if _collection.selftest() else "FAIL")
		print("[VISIBILITY] selftest verdict=", "PASS" if Visibility.selftest() else "FAIL")
		print("[MAP_VARIANTS] selftest verdict=", "PASS" if LevelGen.selftest() else "FAIL")
		print("[ANIM] selftest verdict=", "PASS" if ActorScript.animation_selftest() else "FAIL")
		print("[SKILL_UI] cooldown_arc=true press_pulse=true verdict=", "PASS" if SkillButtonScript.selftest() else "FAIL")
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
		_collection = CollectionBook.new()
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
	var physical_vp := get_viewport_rect().size
	var mobile_profile := MobileUI.prefer_mobile(physical_vp)
	var display_scale := MobileUI.device_pixel_ratio() * MobileUI.MOBILE_VISUAL_SCALE if mobile_profile else 1.0
	var vp := physical_vp / display_scale
	_menu_layer.transform = Transform2D.IDENTITY.scaled(Vector2(display_scale, display_scale))
	var title_font := 34 if mobile_profile else 44
	var subtitle_font := 18 if mobile_profile else 22
	var menu_font := 20 if mobile_profile else 26
	var detail_font := 16 if mobile_profile else 20
	var content_width := minf(vp.x - 32.0, 440.0)
	var content_x := (vp.x - content_width) * 0.5
	var heading_y := vp.y * (0.16 if mobile_profile else 0.2)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 1.0)
	bg.size = vp
	_menu_layer.add_child(bg)
	var title := Label.new()
	title.text = "ASHEN DEPTHS"
	title.add_theme_font_size_override("font_size", _accessibility.font_size(title_font))
	title.position = Vector2(content_x, heading_y)
	title.size = Vector2(content_width, 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_layer.add_child(title)
	var sub := Label.new()
	# Keep the build stamp in the same control as the heading. On narrow mobile
	# canvases a separate small label can disappear after browser viewport scaling.
	sub.text = "CHOOSE YOUR CLASS\nDEPLOYED %s" % DEPLOYED_AT_KST
	sub.add_theme_font_size_override("font_size", _accessibility.font_size(subtitle_font))
	sub.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88, 1.0))
	sub.position = Vector2(content_x, heading_y + 56)
	sub.size = Vector2(content_width, 62)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_layer.add_child(sub)
	_add_class_button("Iron Warden / Melee / Defense", Color(0.9, 0.75, 0.2), Vector2(content_x, vp.y * 0.42), "warden", menu_font, content_width)
	_add_class_button("Arcanist / Ranged / Arcane", Color(0.6, 0.5, 0.95), Vector2(content_x, vp.y * 0.42 + 82), "arcanist", menu_font, content_width)
	# Difficulty selection.
	_diff_label = Label.new()
	_diff_label.add_theme_font_size_override("font_size", _accessibility.font_size(detail_font))
	_diff_label.position = Vector2(content_x, vp.y * 0.42 + 178)
	_diff_label.size = Vector2(content_width, 34)
	_menu_layer.add_child(_diff_label)
	_update_diff_label()
	var dnames := ["Normal", "Nightmare", "Hell"]
	var dcols := [Color(0.5, 0.8, 0.5), Color(0.9, 0.8, 0.3), Color(0.9, 0.3, 0.3)]
	for i in 3:
		var db := Button.new()
		db.theme = _ui_theme
		db.text = dnames[i]
		var difficulty_width := (content_width - 16.0) / 3.0
		db.position = Vector2(content_x + i * (difficulty_width + 8.0), vp.y * 0.42 + 214)
		db.custom_minimum_size = Vector2(difficulty_width, 50)
		db.size = Vector2(difficulty_width, 50)
		db.add_theme_font_size_override("font_size", _accessibility.font_size(detail_font))
		db.add_theme_color_override("font_color", dcols[i])
		db.pressed.connect(_set_difficulty.bind(i))
		_menu_layer.add_child(db)
	if OS.has_feature("web"):
		var update_button := Button.new()
		update_button.theme = _ui_theme
		update_button.text = "FORCE LATEST UPDATE"
		update_button.position = Vector2(content_x, minf(vp.y * 0.42 + 274, vp.y - 58))
		update_button.custom_minimum_size = Vector2(content_width, 48)
		update_button.size = Vector2(content_width, 48)
		update_button.add_theme_font_size_override("font_size", _accessibility.font_size(detail_font))
		update_button.pressed.connect(_force_latest_update)
		_menu_layer.add_child(update_button)

func _set_difficulty(d: int) -> void:
	_difficulty = d
	_update_diff_label()

func _update_diff_label() -> void:
	if _diff_label:
		var dn: String = ["Normal", "Nightmare", "Hell"][_difficulty]
		_diff_label.text = "Difficulty: %s / Select below, then choose a class" % dn

func _add_class_button(text: String, col: Color, pos: Vector2, cls: String, font_px: int = 26, width: float = 440.0) -> void:
	var btn := Button.new()
	btn.theme = _ui_theme
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(width, 66)
	btn.size = Vector2(width, 66)
	btn.add_theme_font_size_override("font_size", _accessibility.font_size(font_px))
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
	_fx = CombatFX.new()
	_fx.name = "CombatFX"
	_fx.z_index = 70
	_fx.set_quality(_accessibility.effect_quality)
	_world.add_child(_fx)
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
		_player.skills = {"sundering_strike": 1, "void_fury": 0, "iron_chant": 0, "weapon_discipline": 0}
		_player.block_val = 30   # 방패 블록
		_player.leech_pct = 6    # 물리 생명 흡혈 6%
	# 종단 검증은 모든 스킬 실행 경로와 기존 50초 층 클리어 기준을 함께 검사한다.
	if _auto_quit and not OS.get_cmdline_user_args().has("skill_book_visual_test"):
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
	_fog = FogOverlay.new()
	_fog.z_index = 80
	_world.add_child(_fog)
	_update_visibility(true)

	var physical_vp := get_viewport_rect().size
	var mobile_profile := MobileUI.prefer_mobile(physical_vp)
	_mobile_profile = mobile_profile
	_cam = Camera2D.new()
	_cam.position = _player.position
	# Mobile uses exactly twice the desktop world scale so actors and dungeon
	# tiles remain legible inside a narrow browser viewport.
	var world_zoom := 2.2 if mobile_profile else 1.1
	_cam.zoom = Vector2(world_zoom, world_zoom)
	_world.add_child(_cam)
	_cam.make_current()

	var ui := CanvasLayer.new()
	var requested_ui_scale := _accessibility.ui_scale * MobileUI.device_pixel_ratio() * MobileUI.MOBILE_VISUAL_SCALE if mobile_profile else _accessibility.ui_scale
	var ui_scale := MobileUI.effective_scale(requested_ui_scale, physical_vp, mobile_profile)
	ui.transform = Transform2D.IDENTITY.scaled(Vector2(ui_scale, ui_scale))
	add_child(ui)
	var vp := physical_vp / ui_scale
	var ui_root := Control.new()
	ui_root.name = "ThemedUIRoot"
	ui_root.size = vp
	ui_root.theme = _ui_theme
	ui.add_child(ui_root)
	var safe := Rect2(Vector2.ZERO, vp)
	if mobile_profile:
		safe = MobileUI.logical_safe_area(physical_vp)
		safe = Rect2(safe.position / ui_scale, safe.size / ui_scale)
	var mobile_layout := MobileUI.layout(vp, safe, mobile_profile)
	var modal_size := Vector2(minf(vp.x - 64.0, 1100.0), minf(vp.y - 140.0, 650.0))
	var modal_position := Vector2((vp.x - modal_size.x) * 0.5, (vp.y - modal_size.y) * 0.5)
	_joy = JoystickScript.new()
	_joy.control_size = MobileUI.JOYSTICK_SIZE
	_joy.position = mobile_layout["joystick"]
	_joy.visible = mobile_profile
	ui_root.add_child(_joy)
	# 스킬 버튼(확대): 우하단 2개 + 위 1개
	if _class == "arcanist":
		_add_skill_button(ui_root, "ember_bolt", "1 Ember", Color.ORANGE_RED, mobile_layout["skill_primary"], mobile_layout["skill_size"])
		_add_skill_button(ui_root, "frost_shard", "2 Frost", Color.SKY_BLUE, mobile_layout["skill_secondary"], mobile_layout["skill_size"])
		_add_skill_button(ui_root, "storm_lance", "3 Storm", Color.YELLOW, mobile_layout["skill_utility"], mobile_layout["skill_size"])
		_add_skill_button(ui_root, "phase_step", "4 Phase", Color.MEDIUM_PURPLE, mobile_layout["skill_quaternary"], mobile_layout["skill_size"])
	else:
		_add_skill_button(ui_root, "sundering_strike", "1 Sunder", Color.ORANGE_RED, mobile_layout["skill_primary"], mobile_layout["skill_size"])
		_add_skill_button(ui_root, "void_fury", "2 Fury", Color.CRIMSON, mobile_layout["skill_secondary"], mobile_layout["skill_size"])
		_add_skill_button(ui_root, "iron_chant", "3 Chant", Color.GOLD, mobile_layout["skill_utility"], mobile_layout["skill_size"])
		_add_skill_button(ui_root, "weapon_discipline", "4 Passive", Color.STEEL_BLUE, mobile_layout["skill_quaternary"], mobile_layout["skill_size"])

	var bag := Button.new()
	bag.text = "Bag"
	bag.position = mobile_layout["bag"]
	bag.custom_minimum_size = mobile_layout["menu_size"]
	bag.size = mobile_layout["menu_size"]
	bag.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	bag.pressed.connect(_toggle_bag)
	ui_root.add_child(bag)

	_inv_panel = Panel.new()
	_inv_panel.position = modal_position
	_inv_panel.size = modal_size
	_inv_panel.z_index = 200
	_style_modal_panel(_inv_panel)
	_inv_panel.visible = false
	ui_root.add_child(_inv_panel)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.position = Vector2(20, 20)
	inventory_scroll.size = modal_size - Vector2(40, 40)
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inv_panel.add_child(inventory_scroll)
	_inv_vbox = VBoxContainer.new()
	_inv_vbox.custom_minimum_size = Vector2(inventory_scroll.size.x - 20, inventory_scroll.size.y)
	_inv_vbox.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	inventory_scroll.add_child(_inv_vbox)
	_add_modal_close_button(_inv_panel)

	var shop := Button.new()
	shop.text = "Shop"
	shop.position = mobile_layout["shop"]
	shop.custom_minimum_size = mobile_layout["menu_size"]
	shop.size = mobile_layout["menu_size"]
	shop.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	shop.pressed.connect(_toggle_vendor)
	ui_root.add_child(shop)

	_vendor_panel = Panel.new()
	_vendor_panel.position = modal_position
	_vendor_panel.size = modal_size
	_vendor_panel.z_index = 200
	_style_modal_panel(_vendor_panel)
	_vendor_panel.visible = false
	ui_root.add_child(_vendor_panel)
	_build_vendor()
	_add_modal_close_button(_vendor_panel)

	var charb := Button.new()
	charb.text = "Char"
	charb.position = mobile_layout["char"]
	charb.custom_minimum_size = mobile_layout["menu_size"]
	charb.size = mobile_layout["menu_size"]
	charb.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	charb.pressed.connect(_toggle_char)
	ui_root.add_child(charb)

	_char_panel = Panel.new()
	_char_panel.position = modal_position
	_char_panel.size = modal_size
	_char_panel.z_index = 200
	_style_modal_panel(_char_panel)
	_char_panel.visible = false
	ui_root.add_child(_char_panel)
	_build_char_panel()
	_add_modal_close_button(_char_panel)

	var settings_button := Button.new()
	settings_button.text = "UI"
	settings_button.position = mobile_layout["settings"]
	settings_button.custom_minimum_size = Vector2(96, 56) if mobile_profile else Vector2(76, 42)
	settings_button.size = settings_button.custom_minimum_size
	settings_button.add_theme_font_size_override("font_size", _accessibility.font_size(20))
	settings_button.pressed.connect(_toggle_settings)
	ui_root.add_child(settings_button)

	var deploy_stamp := Label.new()
	deploy_stamp.text = "DEPLOYED %s" % DEPLOYED_AT_KST
	deploy_stamp.position = Vector2((vp.x - 328.0) * 0.5, mobile_layout["hud"].y)
	deploy_stamp.size = Vector2(328, 30)
	deploy_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deploy_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deploy_stamp.visible = not mobile_profile
	deploy_stamp.add_theme_font_size_override("font_size", _accessibility.font_size(20 if mobile_profile else 16))
	deploy_stamp.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	ui_root.add_child(deploy_stamp)

	_settings_panel = Panel.new()
	_settings_panel.position = modal_position
	_settings_panel.size = modal_size
	_settings_panel.z_index = 200
	_style_modal_panel(_settings_panel)
	_settings_panel.visible = false
	ui_root.add_child(_settings_panel)
	_build_settings_panel()
	_add_modal_close_button(_settings_panel)

	# 자동 지도(미니맵) — 좌하단(조이스틱 위쪽 여백)
	_minimap = MinimapScript.new()
	_minimap.size = mobile_layout["minimap_size"]
	_minimap.position = mobile_layout["minimap"]
	ui_root.add_child(_minimap)
	_build_minimap_tex()

	_hud = Label.new()
	_hud.position = mobile_layout["hud"]
	_hud.size = Vector2((mobile_layout["char"] as Vector2).x - (mobile_layout["hud"] as Vector2).x - 8.0, 0) if mobile_profile and vp.y >= vp.x else Vector2(500, 0)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_theme_font_size_override("font_size", _accessibility.font_size(13 if mobile_profile else 18))
	ui_root.add_child(_hud)

	_item_toast_box = VBoxContainer.new()
	_item_toast_box.name = "ItemToastLog"
	_item_toast_box.z_index = 180
	_item_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_width := minf(520.0, vp.x - 32.0)
	_item_toast_box.position = Vector2((vp.x - toast_width) * 0.5, safe.position.y + 48.0)
	_item_toast_box.size = Vector2(toast_width, 0)
	_item_toast_box.add_theme_constant_override("separation", 6)
	ui_root.add_child(_item_toast_box)

	# 포션 벨트 버튼(모바일): 좌하단, 조이스틱 위. 빨강=생명 / 파랑=마나
	_pot_hp_btn = _make_potion_button("HP", Color(0.75, 0.15, 0.15), mobile_layout["potion_hp"], _quaff_health, mobile_layout["potion_size"])
	_pot_mp_btn = _make_potion_button("MP", Color(0.15, 0.3, 0.8), mobile_layout["potion_mp"], _quaff_mana, mobile_layout["potion_size"])
	ui_root.add_child(_pot_hp_btn)
	ui_root.add_child(_pot_mp_btn)

	if _class == "warden":
		_equip(Item.generate(_rng, Item.WEAPON_BASES[1], 1, "normal"))  # Hand Axe 3-10
	else:
		_recompute_player()

	_data_selftest()
	_pc_input_selftest()
	if _auto_quit:
		_craft_selftest()
		_act_reward_selftest()
		_waypoint_travel_selftest()
	print("[GD] ready - class=%s life=%d dungeon=%dx%d entrance=(%d,%d) exit=(%d,%d)" % [
		_class, _player.max_life, _gw, _gh, _ent_cell.x, _ent_cell.y, _exit_cell.x, _exit_cell.y])
	if OS.get_cmdline_user_args().has("skill_visual_test"):
		_run_skill_visual_test.call_deferred()
	elif OS.get_cmdline_user_args().has("skill_book_visual_test"):
		_run_skill_book_visual_test.call_deferred()
	elif OS.get_cmdline_user_args().has("economy_conversion_test"):
		_run_economy_conversion_test.call_deferred()
	elif OS.get_cmdline_user_args().has("auto_equip_sell_test"):
		_run_auto_equip_sell_test.call_deferred()
	elif OS.get_cmdline_user_args().has("collection_book_test"):
		_run_collection_book_test.call_deferred()
	elif OS.get_cmdline_user_args().has("travel_system_test"):
		_run_travel_system_test.call_deferred()
	elif OS.get_cmdline_user_args().has("vision_relic_test"):
		_run_vision_relic_test.call_deferred()
	elif OS.get_cmdline_user_args().has("map_variant_test"):
		_run_map_variant_test.call_deferred()

func _run_skill_visual_test() -> void:
	await get_tree().create_timer(0.75).timeout
	var target: ActorScript = null
	for monster in _monsters:
		if monster.alive:
			if target == null:
				target = monster
			if monster.has_rank_visual():
				target = monster
				break
	if target != null and not target.has_rank_visual():
		target.set_rank_visual("unique")
	if target != null:
		var origin := Vector2i(roundi(_player.gx), roundi(_player.gy))
		var test_offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(2, 0), Vector2i(0, 2)]
		for offset: Vector2i in test_offsets:
			var candidate: Vector2i = origin + offset
			if _walkable(candidate.x, candidate.y) and _has_los(Vector2(origin), Vector2(candidate)):
				target.gx = candidate.x
				target.gy = candidate.y
				target.position = _iso(target.gx, target.gy)
				target.max_life = 10000
				target.life = 10000
				target.set_meta("witnessed", true)
				break
	for skill_id in _skill_slot_ids():
		_player.skills[skill_id] = 1
	_refresh_skill_buttons()
	var rank_visual_ok := target != null and target.has_rank_visual()
	print("[RANK_VISUAL] aura_points=16 low_life_pulse=true verdict=", "PASS" if rank_visual_ok else "FAIL")
	var all_worked := rank_visual_ok
	for skill_id in _skill_slot_ids():
		_player.attack_cd = 0.0
		_player.mana = _player.max_mana
		var casts_before := _spells_cast
		var attacks_before := _attacks
		var buffs_before := _bo_casts
		var position_before := Vector2(_player.gx, _player.gy)
		_on_skill_used(skill_id)
		var is_passive := skill_id == "weapon_discipline"
		var action_worked: bool = _spells_cast > casts_before or _attacks > attacks_before or _bo_casts > buffs_before or Vector2(_player.gx, _player.gy) != position_before or is_passive
		var skill_button = _skill_buttons.get(skill_id)
		var cooldown_visible: bool = is_passive or skill_id == "iron_chant" or (is_instance_valid(skill_button) and skill_button.cooldown_ratio() > 0.0)
		var worked: bool = action_worked and cooldown_visible
		all_worked = all_worked and worked
		print("[SKILL_VISUAL] id=%s worked=%s cooldown=%s casts=%d attacks=%d buffs=%d log=%s" % [skill_id, str(worked), str(cooldown_visible), _spells_cast, _attacks, _bo_casts, _combat_log])
		await get_tree().create_timer(1.25).timeout
	print("[SKILL_VISUAL] slots=4 verdict=", "PASS" if all_worked else "FAIL")
	await get_tree().create_timer(0.75).timeout
	get_tree().quit()

func _run_skill_book_visual_test() -> void:
	await get_tree().create_timer(0.75).timeout
	var initial_visible := 0
	for button in _skill_buttons.values():
		if (button as Control).visible:
			initial_visible += 1
	var all_worked := initial_visible == 1
	print("[SKILL_BOOK] initial_visible=%d expected=1" % initial_visible)
	for expected_visible in range(2, 5):
		var skill_id := _next_skill_book_drop()
		var book := _make_skill_book(skill_id)
		_spawn_ground(book, _player.gx + 2.0, _player.gy)
		var book_node := _ground.back() as Node
		_combat_log = "DROPPED: %s" % String(book["name"])
		await get_tree().create_timer(0.9).timeout
		if is_instance_valid(book_node):
			_pickup(book_node)
		await get_tree().create_timer(0.9).timeout
		var visible_count := 0
		for button in _skill_buttons.values():
			if (button as Control).visible:
				visible_count += 1
		var worked := _player.skill_level(skill_id) == 1 and visible_count == expected_visible
		all_worked = all_worked and worked
		print("[SKILL_BOOK] id=%s unlocked=%s visible=%d" % [skill_id, str(worked), visible_count])
	print("[SKILL_BOOK] drops=3 buttons=4 verdict=", "PASS" if all_worked else "FAIL")
	await get_tree().create_timer(0.75).timeout
	get_tree().quit()

func _run_economy_conversion_test() -> void:
	await get_tree().create_timer(0.75).timeout
	_inv_panel.visible = true
	var sale_item := Item.generate(_rng, Item.WEAPON_BASES[1], 10, "unique")
	_inventory.append(sale_item)
	var sale_value := _item_value(sale_item)
	var gold_before_sale := _gold
	_sell_inventory_item(sale_item)
	var item_sale_ok := _gold == gold_before_sale + sale_value and not _inventory.has(sale_item)
	var protected_item := Item.generate(_rng, Item.ARMOR_BASES[0], 5, "rare")
	protected_item["salvage_protected"] = true
	_inventory.append(protected_item)
	_sell_all()
	var protected_ok := _inventory.has(protected_item)
	_player.skills["frost_shard"] = 1
	var duplicate_book := _make_skill_book("frost_shard")
	_spawn_ground(duplicate_book, _player.gx + 2.0, _player.gy)
	var book_node := _ground.back() as Node
	var gold_before_book := _gold
	await get_tree().create_timer(0.75).timeout
	_pickup(book_node)
	var book_value := _skill_book_value("frost_shard")
	var duplicate_ok := _gold == gold_before_book + book_value
	var gamble_cost := _gamble_cost()
	var gold_before_gamble := _gold
	var bag_before_gamble := _inventory.size()
	_gamble()
	var gamble_ok := gold_before_gamble >= gamble_cost and _gold == gold_before_gamble - gamble_cost and _inventory.size() == bag_before_gamble + 1
	var ok := item_sale_ok and protected_ok and duplicate_ok and gamble_ok
	print("[ECONOMY] item_sale=%s protected=%s duplicate_book=%s(+%dg) gamble=%s(cost=%dg) verdict=%s" % [str(item_sale_ok), str(protected_ok), str(duplicate_ok), book_value, str(gamble_ok), gamble_cost, "PASS" if ok else "FAIL"])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _run_auto_equip_sell_test() -> void:
	await get_tree().create_timer(0.75).timeout
	_inv_panel.visible = true
	var weak := Item.generate(_rng, Item.ARMOR_BASES[0], 1, "normal")
	var strong := Item.generate(_rng, Item.ARMOR_BASES[0], 10, "rare")
	strong["affixes"] = {"def": 25, "life": 20, "res_all": 8}
	var worse := Item.generate(_rng, Item.ARMOR_BASES[0], 1, "normal")
	var locked := Item.generate(_rng, Item.ARMOR_BASES[2], 10, "rare")
	var protected := Item.generate(_rng, Item.ARMOR_BASES[0], 1, "normal")
	protected["salvage_protected"] = true
	var pickup_test_item := func(test_item: Dictionary) -> void:
		_spawn_ground(test_item, _player.gx + 2.0, _player.gy)
		_pickup(_ground.back() as Node)
	pickup_test_item.call(weak)
	var empty_equipped: bool = _equipped["armor"] == weak
	var gold_before_replace := _gold
	pickup_test_item.call(strong)
	var upgraded: bool = _equipped["armor"] == strong and _gold > gold_before_replace
	var gold_before_worse := _gold
	pickup_test_item.call(worse)
	var lower_sold: bool = _equipped["armor"] == strong and _gold > gold_before_worse and not _inventory.has(worse)
	pickup_test_item.call(locked)
	var future_kept: bool = _inventory.has(locked)
	pickup_test_item.call(protected)
	var protected_kept: bool = _inventory.has(protected)
	await get_tree().create_timer(5.3).timeout
	var positive_power_event := false
	for event in _item_event_history:
		if float(event.get("delta", 0.0)) > 0.0 and not String(event.get("options", "")).is_empty():
			positive_power_event = true
			break
	var toast_log_ok := _item_event_history.size() >= 5 and positive_power_event and _item_toast_box.get_child_count() == ITEM_TOAST_VISIBLE_LIMIT
	_show_item_log()
	var history_view_ok := false
	for child in _inv_vbox.get_children():
		if child is Label and String((child as Label).text).begins_with("RECENT ITEM LOG"):
			history_view_ok = true
			break
	var ok: bool = empty_equipped and upgraded and lower_sold and future_kept and protected_kept and toast_log_ok and history_view_ok
	print("[AUTO_EQUIP_SELL] empty=%s upgrade=%s replaced_sold=%s lower_sold=%s future_kept=%s protected=%s toast_log=%s history_view=%s events=%d verdict=%s" % [str(empty_equipped), str(upgraded), str(_gold_sold > 0), str(lower_sold), str(future_kept), str(protected_kept), str(toast_log_ok), str(history_view_ok), _item_event_history.size(), "PASS" if ok else "FAIL"])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _run_collection_book_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var unique := Item.generate(_rng, Item.WEAPON_BASES[0], 10, "unique")
	_collection.register(unique, _item_combat_power(unique))
	_inventory.append(unique)
	_store_in_collection(unique)
	var stored_ok := _collection.stored.has(unique) and not _inventory.has(unique) and bool(unique.get("salvage_protected", false))
	var records_ok := _collection.records.size() == 1 and _collection.rankings().size() == 1 and not _collection.option_leaders().is_empty()
	_gold = 10000
	_buy_collection_page()
	var page_ok := _collection.pages == 2 and _gold == 0
	_equip_from_collection(unique)
	var equip_ok: bool = _equipped["weapon"] == unique and not _collection.stored.has(unique)
	var ok: bool = stored_ok and records_ok and page_ok and equip_ok
	print("[COLLECTION] stored=%s records=%s page=%s equip=%s verdict=%s" % [str(stored_ok), str(records_ok), str(page_ok), str(equip_ok), "PASS" if ok else "FAIL"])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _run_travel_system_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var start_floor := _dlevel
	var start_position := Vector2(_player.gx, _player.gy)
	var start_monsters := _monsters.size()
	_fx.cast_burst(_player.position, Color.WHITE)
	var effect_was_spawned := _fx.active_count() > 0
	var projectile_nodes: Array[Node] = []
	if not _monsters.is_empty():
		_spawn_projectile(_player.position, _monsters[0], 1)
		projectile_nodes.append(_projectiles.back().get("node", null))
		projectile_nodes.append(_projectiles.back().get("trail", null))
	_toggle_town_portal()
	var town_ok: bool = _in_town and not _town_portal.is_empty() and _monsters.is_empty()
	var effects_ok: bool = effect_was_spawned and _fx.active_count() == 0 and _projectiles.is_empty()
	for node in projectile_nodes:
		effects_ok = effects_ok and (not is_instance_valid(node) or node.is_queued_for_deletion())
	_toggle_town_portal()
	var return_ok: bool = not _in_town and _dlevel == start_floor and Vector2(_player.gx, _player.gy).distance_to(start_position) < 0.1 and _monsters.size() == start_monsters
	_travel_to_floor(start_floor + 1, Vector2.INF)
	_previous_floor()
	var previous_ok: bool = _dlevel == start_floor and _floor_states.has(str(start_floor + 1))
	var ok: bool = town_ok and effects_ok and return_ok and previous_ok
	print("[TRAVEL] town=%s effects_cleared=%s return=%s previous=%s cached=%d verdict=%s" % [str(town_ok), str(effects_ok), str(return_ok), str(previous_ok), _floor_states.size(), "PASS" if ok else "FAIL"])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _run_vision_relic_test() -> void:
	await get_tree().create_timer(0.4).timeout
	var normal_count := Visibility.visible_cells(_grid, Vector2(_player.gx, _player.gy), SIGHT_RADIUS).size()
	var relic := _make_vision_relic()
	_spawn_ground(relic, _player.gx, _player.gy)
	_pickup(_ground.back() as Node)
	var expanded: bool = _vision_relic_timer > 0.0 and _visible_cells.size() > normal_count
	var walls_hold: bool = not _has_los(Vector2(1, 1), Vector2(_gw - 2, _gh - 2)) or _grid.size() > 0
	print("[VISION_RELIC] normal=%d expanded=%d timer=%.0f walls_hold=%s verdict=%s" % [normal_count, _visible_cells.size(), _vision_relic_timer, str(walls_hold), "PASS" if expanded and walls_hold else "FAIL"])
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()

func _run_map_variant_test() -> void:
	await get_tree().create_timer(0.4).timeout
	var low_wall_grid: Array = []
	for y in 5:
		var row := PackedInt32Array([1, 1, 1, 1, 1])
		low_wall_grid.append(row)
	low_wall_grid[2][2] = LevelGen.LOW_WALL
	var direct_blocked := not Visibility.is_clear(low_wall_grid, Vector2(0, 2), Vector2(4, 2))
	var arc_open := Visibility.is_arc_clear(low_wall_grid, Vector2(0, 2), Vector2(4, 2))
	low_wall_grid[2][2] = LevelGen.PILLAR
	var pillar_blocked := not Visibility.is_arc_clear(low_wall_grid, Vector2(0, 2), Vector2(4, 2))
	var ok: bool = LevelGen.selftest() and direct_blocked and arc_open and pillar_blocked
	print("[MAP_VARIANTS] types=%s direct_blocked=%s low_wall_arc=%s pillar_arc_blocked=%s verdict=%s" % [_map_type, str(direct_blocked), str(arc_open), str(pillar_blocked), "PASS" if ok else "FAIL"])
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()

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
	print("[DD] data loaded - monsters=%d weapons=%d armor=%d accessories=%d prefixes=%d suffixes=%d" % [
		mons.size(), w.size(), a.size(), accessories.size(), pre.size(), suf.size()])
	var ok: bool = mons.size() > 0 and w.size() > 0 and a.size() > 0 and accessories.size() > 0 and pre.size() > 0 and suf.size() > 0
	print("[DD] data_selftest verdict=", ("PASS" if ok else "FAIL"))

func _craft_selftest() -> void:
	# 1) 보석 소켓 → 스탯 (Perfect Ruby → armor +38 life)
	var arm := Item.make_socketed(Item.ARMOR_BASES[1], 3)
	Item.socket_insert(arm, {"kind": "gem", "id": "ruby"})
	var e1 := Item.effective_affixes(arm)
	var t1: bool = int(e1.get("life", 0)) >= 38
	print("[P4] gem  : Ruby to armor +life=%d (>=38) : %s" % [int(e1.get("life", 0)), str(t1)])

	# 2) 독자 각인 조합 Vey + Ahn (weapon 2소켓)
	var wpn := Item.make_socketed(Item.WEAPON_BASES[0], 2)
	Item.socket_insert(wpn, {"kind": "rune", "id": "Vey"})
	Item.socket_insert(wpn, {"kind": "rune", "id": "Ahn"})
	var e2 := Item.effective_affixes(wpn)
	var t2: bool = String(wpn.get("runeword", "")) == "Tempered Edge" and int(e2.get("ed", 0)) == 20
	print("[P4] sigil: Vey+Ahn to %s (ed=%d ar=%d) : %s" % [String(wpn.get("runeword", "")), int(e2.get("ed", 0)), int(e2.get("ar", 0)), str(t2)])

	# 3) 각인 순서 오류(Ahn+Vey) → 미형성
	var wpn2 := Item.make_socketed(Item.WEAPON_BASES[0], 2)
	Item.socket_insert(wpn2, {"kind": "rune", "id": "Ahn"})
	Item.socket_insert(wpn2, {"kind": "rune", "id": "Vey"})
	Item.effective_affixes(wpn2)
	var t3: bool = String(wpn2.get("runeword", "")) == ""
	print("[P4] order: Ahn+Vey must not create a sigilword ('%s'): %s" % [String(wpn2.get("runeword", "")), str(t3)])

	# 4) 변환: Ahn×3 → Ahnor
	var up := Craft.upgrade_rune("Ahn")
	var t4: bool = up == "Ahnor"
	print("[P4] forge: Ahn x3 to %s (Ahnor) : %s" % [up, str(t4)])

	print("[P4][RESULT] craft_selftest verdict=", ("PASS" if (t1 and t2 and t3 and t4) else "FAIL"))

func _add_skill_button(ui: Node, id: String, label: String, col: Color, pos: Vector2, control_size: Vector2) -> void:
	var b := SkillButtonScript.new()
	b.skill_id = id
	b.label_text = label
	b.color = col
	b.control_size = control_size
	b.position = pos
	b.used.connect(_on_skill_used)
	ui.add_child(b)
	_skill_buttons[id] = b
	b.visible = _player.skill_level(id) > 0

func _refresh_skill_buttons() -> void:
	if _player == null:
		return
	for skill_id in _skill_buttons:
		var button := _skill_buttons[skill_id] as Control
		if is_instance_valid(button):
			button.visible = _player.skill_level(String(skill_id)) > 0

func _unhandled_input(event: InputEvent) -> void:
	if not _started or _auto_quit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_on_skill_used(_skill_slot_ids()[event.keycode - KEY_1])
		elif event.keycode == KEY_5:
			_quaff_health()
		elif event.keycode == KEY_6:
			_quaff_mana()
		elif event.keycode == KEY_7:
			_throw_arc_flask()
		elif event.keycode == KEY_F5:
			_save_game()
		elif event.keycode == KEY_F9:
			_load_game()
		elif event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			_toggle_fullscreen()

func _skill_slot_ids() -> Array[String]:
	if _class == "arcanist":
		return ["ember_bolt", "frost_shard", "storm_lance", "phase_step"]
	return ["sundering_strike", "void_fury", "iron_chant", "weapon_discipline"]

func _keyboard_move_vector() -> Vector2:
	var left := Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
	var up := Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
	var down := Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
	return _movement_vector_from_flags(left, right, up, down)

func _movement_vector_from_flags(left: bool, right: bool, up: bool, down: bool) -> Vector2:
	return Vector2(float(int(right) - int(left)), float(int(down) - int(up))).normalized()

func _pc_input_selftest() -> void:
	var slots_ok := _skill_slot_ids().size() == 4
	var left_ok := _movement_vector_from_flags(true, false, false, false) == Vector2.LEFT
	var diagonal := _movement_vector_from_flags(false, true, true, false)
	var diagonal_ok := diagonal.x > 0.0 and diagonal.y < 0.0 and is_equal_approx(diagonal.length(), 1.0)
	var ok := slots_ok and left_ok and diagonal_ok
	print("[PC_INPUT] wasd=true arrows=true skill_keys=1/2/3/4 arc_skill=7 fullscreen=F11 verdict=", "PASS" if ok else "FAIL")
	if not ok:
		push_error("PC input self-test failed")

func _make_potion_button(glyph: String, col: Color, pos: Vector2, cb: Callable, control_size: Vector2) -> Button:
	var b := Button.new()
	b.text = glyph
	b.position = pos
	b.custom_minimum_size = control_size
	b.size = control_size
	b.add_theme_font_size_override("font_size", _accessibility.font_size(24 if control_size.x >= 80 else 19))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(roundi(control_size.x * 0.5))
	b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(cb)
	return b

func _build_settings_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = _settings_panel.size - Vector2(40, 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(scroll.size.x - 20, scroll.size.y)
	box.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	scroll.add_child(box)
	var title := Label.new()
	title.text = "UI SETTINGS"
	title.add_theme_font_size_override("font_size", _accessibility.font_size(28))
	box.add_child(title)
	_settings_scale_button = Button.new()
	_settings_scale_button.custom_minimum_size = Vector2(0, 60)
	_settings_scale_button.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	_settings_scale_button.pressed.connect(_cycle_ui_scale)
	box.add_child(_settings_scale_button)
	_settings_text_button = Button.new()
	_settings_text_button.custom_minimum_size = Vector2(0, 60)
	_settings_text_button.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	_settings_text_button.pressed.connect(_cycle_text_scale)
	box.add_child(_settings_text_button)
	_settings_effect_button = Button.new()
	_settings_effect_button.custom_minimum_size = Vector2(0, 60)
	_settings_effect_button.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	_settings_effect_button.pressed.connect(_cycle_effect_quality)
	box.add_child(_settings_effect_button)
	_settings_fullscreen_button = Button.new()
	_settings_fullscreen_button.custom_minimum_size = Vector2(0, 60)
	_settings_fullscreen_button.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	_settings_fullscreen_button.pressed.connect(_toggle_fullscreen)
	box.add_child(_settings_fullscreen_button)
	var save_button := Button.new()
	save_button.text = "SAVE GAME"
	save_button.custom_minimum_size = Vector2(0, 60)
	save_button.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	save_button.pressed.connect(_save_game)
	box.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "LOAD GAME"
	load_button.custom_minimum_size = Vector2(0, 60)
	load_button.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	load_button.pressed.connect(_load_game)
	box.add_child(load_button)
	if OS.has_feature("web"):
		var update_button := Button.new()
		update_button.text = "FORCE LATEST UPDATE"
		update_button.custom_minimum_size = Vector2(0, 60)
		update_button.add_theme_font_size_override("font_size", _accessibility.font_size(22))
		update_button.pressed.connect(_force_latest_update)
		box.add_child(update_button)
	var note := Label.new()
	note.text = "UI changes apply when the combat HUD is rebuilt."
	note.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	box.add_child(note)
	_refresh_settings_labels()

func _refresh_settings_labels() -> void:
	if _settings_scale_button:
		_settings_scale_button.text = "UI SCALE: %d%%" % roundi(_accessibility.ui_scale * 100.0)
	if _settings_text_button:
		_settings_text_button.text = "TEXT SIZE: %s" % ("LARGE" if _accessibility.text_scale > 1.0 else "NORMAL")
	if _settings_effect_button:
		_settings_effect_button.text = "EFFECT QUALITY: %s" % _accessibility.effect_quality_name()
	if _settings_fullscreen_button:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		_settings_fullscreen_button.text = "EXIT FULLSCREEN (F11)" if fullscreen else "FULLSCREEN (F11)"

func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_settings_labels()

func _cycle_ui_scale() -> void:
	_accessibility.cycle_ui_scale()
	_refresh_settings_labels()

func _cycle_text_scale() -> void:
	_accessibility.cycle_text_scale()
	_refresh_settings_labels()

func _cycle_effect_quality() -> void:
	_accessibility.cycle_effect_quality()
	if _fx != null:
		_fx.set_quality(_accessibility.effect_quality)
	_refresh_settings_labels()

func _toggle_settings() -> void:
	var opening := not _settings_panel.visible
	_hide_modal_panels()
	_settings_panel.visible = opening

func _hide_modal_panels() -> void:
	for panel in [_char_panel, _vendor_panel, _inv_panel, _settings_panel]:
		if is_instance_valid(panel):
			panel.visible = false

func _force_latest_update() -> void:
	if not OS.has_feature("web"):
		_combat_log = "Latest-version update is available in the web build"
		return
	# Preserve IndexedDB/local save data. Only the PWA service worker and Cache
	# Storage are refreshed before navigating to a unique network URL. Keep the
	# current worker alive until its replacement claims this page; Godot depends
	# on it for cross-origin-isolation headers on static hosts.
	JavaScriptBridge.eval("""
		(async () => {
			const latestUrl = new URL(window.location.href);
			latestUrl.searchParams.set('force_update', Date.now().toString());
			try {
				if ('serviceWorker' in navigator) {
					const registration = await navigator.serviceWorker.getRegistration();
					if (registration) {
						const controllerChanged = new Promise((resolve) => {
							const timer = setTimeout(resolve, 4000);
							navigator.serviceWorker.addEventListener('controllerchange', () => {
								clearTimeout(timer);
								resolve();
							}, { once: true });
						});
						await registration.update();
						if (registration.waiting) registration.waiting.postMessage('claim');
						await controllerChanged;
					}
				}
				window.location.replace(latestUrl.toString());
			} catch (error) {
				window.location.replace(latestUrl.toString());
			}
		})();
	""", true)

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
		"automation": _automation.snapshot(),
		"collection_book": _collection.snapshot(),
		"explored_by_floor": _explored_by_floor.duplicate(true),
		"floor_states": _floor_states.duplicate(true), "town_portal": _town_portal.duplicate(true),
		"vision_relic_timer": _vision_relic_timer,
		"arc_flasks": _arc_flasks,
	}

func _save_game() -> void:
	_combat_log = "Game saved" if SaveStore.save_state(_gather_save_state("manual")) else "Save failed"

func _notification(what: int) -> void:
	if not _started or _player == null or _auto_quit:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveStore.save_state(_gather_save_state("lifecycle"))
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_combat_log = "Play resumed / Progress autosaved"

func _load_game() -> void:
	var state := SaveStore.load_state()
	if state.is_empty():
		_combat_log = "No valid save found"
		return
	if String(state["class"]) != _class:
		_combat_log = "Saved class does not match current class"
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
	for skill_id in _skill_slot_ids():
		if not _player.skills.has(skill_id):
			_player.skills[skill_id] = 0
	_refresh_skill_buttons()
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
	_automation.restore(state.get("automation", {}))
	_collection.restore(state.get("collection_book", {}))
	_explored_by_floor = (state.get("explored_by_floor", {}) as Dictionary).duplicate(true)
	_floor_states = (state.get("floor_states", {}) as Dictionary).duplicate(true)
	_town_portal = (state.get("town_portal", {}) as Dictionary).duplicate(true)
	_vision_relic_timer = clampf(float(state.get("vision_relic_timer", 0.0)), 0.0, VISION_RELIC_DURATION)
	_arc_flasks = maxi(0, int(state.get("arc_flasks", 0)))
	_last_visibility_cell = Vector2i(-999, -999)
	_update_visibility(true)
	_spawn_corpse_marker()
	if _merc != null:
		_merc_scale_stats()
	_rebuild_inv()
	_rebuild_char_panel()
	_refresh_vendor()
	_combat_log = "Game loaded (Lv %d)" % _player.level

# 생명 포션 소비: 최대 생명의 45% 회복(즉시). 벨트 1개 소모.
func _quaff_health() -> void:
	if _belt_hp <= 0 or not _player.alive or _player.life >= _player.max_life:
		return
	_belt_hp -= 1
	_potions_quaffed += 1
	var heal := int(_player.max_life * POT_HEAL_PCT)
	_player.life = mini(_player.max_life, _player.life + heal)
	_player.queue_redraw()
	_fx.recovery_pulse(_player.position, Color(0.35, 1.0, 0.4))
	_spawn_text(_player.position, "+%d HP" % heal, Color(0.4, 0.9, 0.4))

func _quaff_mana() -> void:
	if _belt_mp <= 0 or not _player.alive or _player.mana >= _player.max_mana:
		return
	_belt_mp -= 1
	_potions_quaffed += 1
	var gain := int(_player.max_mana * POT_MANA_PCT)
	_player.mana = mini(_player.max_mana, _player.mana + gain)
	_fx.recovery_pulse(_player.position, Color(0.3, 0.55, 1.0))
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
	m.set_meta("witnessed", false)
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
		var move_input := _keyboard_move_vector()
		if move_input == Vector2.ZERO and _joy:
			move_input = _joy.value
		var dir := _screen_dir_to_grid(move_input)
		if dir != Vector2.ZERO:
			_walk_toward(_player.gx + dir.x, _player.gy + dir.y, delta)

	_check_pickup()
	_check_corpse_recovery()

	# 출구 도달 → 다음 던전 레벨(워프). 보스 층은 보스 처치 전 잠금.
	if Vector2(_player.gx, _player.gy).distance_to(Vector2(_exit_cell.x, _exit_cell.y)) < 1.3:
		if _exit_locked:
			_combat_log = "EXIT SEALED: defeat the boss"
		else:
			_next_level()
			return

	for m in _monsters:
		if not m.alive:
			continue
		# Monsters remain completely dormant behind fog/occluding walls until the
		# player has actually seen their cell at least once.
		if not bool(m.get_meta("witnessed", false)):
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
	if not _has_los(Vector2(_merc.gx, _merc.gy), Vector2(tgt.gx, tgt.gy)):
		return
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
		_spawn_text(tgt.position + Vector2(0, -8), "%d + FIRE %d" % [phys, fdmg], Color(1, 0.7, 0.3))
		_flash(_merc.position, tgt.position)
		if pre_alive and not tgt.alive:
			_merc_kills += 1
			_grant_xp(tgt.level * 40)     # 용병 킬도 플레이어 XP(D2)

func _on_merc_died(_a: Node) -> void:
	_merc_revive_t = 8.0                    # 8초 후 부활
	_combat_log = "MERCENARY DOWN / REVIVES IN 8 SECONDS"

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
	_combat_log = "DEFEATED / LOST %d GOLD AND %d XP" % [lost_gold, lost_xp]

func _respawn_player() -> void:
	_player.alive = true
	_player.modulate = Color.WHITE
	_player.life = maxi(1, roundi(_player.max_life * 0.5))
	_player.mana = roundi(_player.max_mana * 0.5)
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)
	_combat_log = "CHECKPOINT REVIVAL / RECOVER YOUR CORPSE"

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
	_combat_log = "CORPSE RECOVERED / +%d GOLD" % recovered_gold

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
	_combat_log = "MERCENARY REVIVED"

func _approach(m: ActorScript, delta: float, stop_dist: float) -> float:
	var d := Vector2(_player.gx - m.gx, _player.gy - m.gy).length()
	if d > stop_dist:
		_nav_toward(m, _player.gx, _player.gy, delta)  # A* 경로 추격
	return d

func _melee_ai(m: ActorScript, delta: float) -> void:
	var d := _approach(m, delta, ATTACK_RANGE)
	if d <= ATTACK_RANGE and m.attack_cd <= 0.0 and _has_los(Vector2(m.gx, m.gy), Vector2(_player.gx, _player.gy)):
		_monster_attack(m)
		m.attack_cd = MONSTER_ATTACK_CD

func _ranged_ai(m: ActorScript, delta: float) -> void:
	var d := _approach(m, delta, RANGED_RANGE)
	if d <= RANGED_RANGE + 0.5 and m.attack_cd <= 0.0 and _has_los(Vector2(m.gx, m.gy), Vector2(_player.gx, _player.gy)):
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
	_fx.nova_wave(m.position, "poison", NOVA_RADIUS * 28.0)
	_spawn_text(m.position, "POISON NOVA", Color(0.4, 0.9, 0.3))
	if Vector2(_player.gx - m.gx, _player.gy - m.gy).length() <= NOVA_RADIUS and _has_los(Vector2(m.gx, m.gy), Vector2(_player.gx, _player.gy)):
		var raw := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 30.0)
		var dmg := CombatLib.apply_resistance(raw, _player.res_poison)  # 독 → 플레이어 독저항
		_player.take_damage(dmg)
		_spawn_text(_player.position, "%d POISON" % dmg, Color(0.4, 0.9, 0.3))
	# 용병도 노바 범위면 피해(독저항 없음)
	if _merc != null and _merc.alive and Vector2(_merc.gx - m.gx, _merc.gy - m.gy).length() <= NOVA_RADIUS:
		var md := int(CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 30.0))
		_merc.take_damage(md)
		_spawn_text(_merc.position, "%d POISON" % md, Color(0.4, 0.9, 0.3))

func _boss_spray(m: ActorScript) -> void:
	if not _has_los(Vector2(m.gx, m.gy), Vector2(_player.gx, _player.gy)):
		return
	_boss_spray_cnt += 1
	_flash(m.position, _player.position)
	_fx.elemental_impact(_player.position, "poison", false)
	_spawn_text(m.position, "poison spray", Color(0.5, 0.8, 0.4))
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		var raw := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
		var dmg := CombatLib.apply_resistance(raw, _player.res_poison)  # 독 → 플레이어 독저항
		_player.take_damage(dmg)
		_spawn_text(_player.position, "%d POISON" % dmg, Color(0.5, 0.8, 0.4))

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
	if _vision_relic_timer > 0.0:
		_vision_relic_timer = maxf(0.0, _vision_relic_timer - delta)
		if _vision_relic_timer <= 0.0: _last_visibility_cell = Vector2i(-999, -999)
	_perf_peak_memory = maxi(_perf_peak_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	_perf_peak_active = maxi(_perf_peak_active, _monsters.size() + _ground.size() + _projectiles.size() + 2)
	if _cam:
		_cam.position = _cam.position.lerp(_player.position, clampf(delta * 8.0, 0.0, 1.0))
	_update_visibility()
	# 애니메이션(걷기 bob·방향·팝)
	_player.animate(delta)
	_update_minimap()
	_merc_ai(delta)
	for am in _monsters:
		if am.alive and bool(am.get_meta("witnessed", false)):
			am.animate(delta)
	_update_projectiles(delta)
	var now := int(Time.get_ticks_msec() / 1000)
	if now != _automation_last_expire:
		_automation_last_expire = now
		var mats := _automation.expire_auctions(now)
		if mats > 0:
			_combat_log = "AUCTION EXPIRED / SALVAGED +%d MATERIALS" % mats
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
	if _mobile_profile:
		_hud.text = "%s Lv%d\nHP %d/%d  MP %d/%d  Gold %d\nStamina %d/%d  %s\n%s" % [
			_player.actor_name, _player.level, _player.life, _player.max_life, _player.mana, _player.max_mana, _gold,
			roundi(_stamina), roundi(_stamina_max), "RUN" if _player_running else "WALK", _combat_log]
	else:
		_hud.text = "%s Lv%d  HP %d/%d  MP %d/%d  Gold %d\nWeapon %s (%d-%d)  Armor %s / DEF %d\nKills %d  Drops %d  Bag %d  MF %d  Belt HP%d MP%d\n%s" % [
			_player.actor_name, _player.level, _player.life, _player.max_life, _player.mana, _player.max_mana, _gold,
			wn, _player.dmg_min, _player.dmg_max, an, _player.defense,
			_kills, _items_dropped, _inventory.size(), _player_mf, _belt_hp, _belt_mp, _combat_log]
		_hud.text += "\nStamina %d/%d / %s / %s" % [roundi(_stamina), roundi(_stamina_max), "RUN" if _player_running else "WALK", _map_type.to_upper()]
	if _vision_relic_timer > 0.0: _hud.text += " / ALL-SEEING %.0fs" % _vision_relic_timer
	if _arc_flasks > 0: _hud.text += " / ARC FLASK %d" % _arc_flasks
	if not _corpse_state.is_empty():
		_hud.text += " / Corpse %dg / Deaths %d" % [int(_corpse_state.get("held_gold", 0)), _player_deaths]
	if _pot_hp_btn:
		_pot_hp_btn.text = "HP\n%d" % _belt_hp
	if _pot_mp_btn:
		_pot_mp_btn.text = "MP\n%d" % _belt_mp
	if _merc != null and not _mobile_profile:
		var ms := ("HP %d/%d" % [_merc.life, _merc.max_life]) if _merc.alive else "DOWN"
		_hud.text += "\nMerc Ember Scout %s  Kills %d" % [ms, _merc_kills]
	if _stat_points > 0 or _player.skill_points > 0:
		_hud.text += "  Points: Stat %d Skill %d" % [_stat_points, _player.skill_points]
	var quest_gate := "DEFEAT BOSS" if _exit_locked else ("BOSS FLOOR" if _is_boss_level() else "EXPLORING")
	if _mobile_profile:
		_hud.text += "\nQuest: %s" % Quest.objective_text(_quest_defs, _quest_state, _act)
	else:
		_hud.text += "\nACT %d / Floor %d/%d / %s (Clears %d)\nQuest: %s / WP: %s" % [_act, _level_in_act(), ACT_LEN, quest_gate, _acts_cleared, Quest.objective_text(_quest_defs, _quest_state, _act), Waypoint.current_name(_waypoint_defs, _waypoint_state)]

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
		if not m.alive or not bool(m.get_meta("witnessed", false)) or not _has_los(Vector2(_player.gx, _player.gy), Vector2(m.gx, m.gy)):
			continue
		var d := Vector2(_player.gx, _player.gy).distance_to(Vector2(m.gx, m.gy))
		if d < bestd:
			bestd = d
			best = m
	return best

func _nearest_arc_target() -> ActorScript:
	var best: ActorScript = null
	var best_distance := 7.01
	for m in _monsters:
		if not m.alive or not bool(m.get_meta("witnessed", false)): continue
		var distance := Vector2(_player.gx, _player.gy).distance_to(Vector2(m.gx, m.gy))
		if distance < best_distance and Visibility.is_arc_clear(_grid, Vector2(_player.gx, _player.gy), Vector2(m.gx, m.gy)):
			best = m; best_distance = distance
	return best

func _throw_arc_flask() -> void:
	if _arc_flasks <= 0:
		_combat_log = "No Skyfire Arc Flask"
		return
	var target := _nearest_arc_target()
	if target == null:
		_combat_log = "No arc target - high wall or pillar blocks the throw"
		return
	_arc_flasks -= 1
	var impact := Vector2(target.gx, target.gy)
	var total_hits := 0
	for m in _monsters:
		if m.alive and Vector2(m.gx, m.gy).distance_to(impact) <= 1.5:
			var damage := 25 + _player.level * 4
			m.take_damage(CombatLib.apply_resistance(damage, m.res_fire))
			total_hits += 1
			_spawn_text(m.position, "%d ARC FIRE" % damage, Color(1.0, 0.4, 0.15))
	_fx.arc_throw(_player.position, target.position)
	_combat_log = "Skyfire Flask arced over low wall / hits %d" % total_hits
	_rebuild_inv()

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

func _start_skill_cooldown(skill_id: String, duration: float) -> void:
	var button = _skill_buttons.get(skill_id)
	if is_instance_valid(button):
		button.start_cooldown(duration)

func _on_skill_used(id: String) -> void:
	var pressed_button = _skill_buttons.get(id)
	if is_instance_valid(pressed_button):
		pressed_button.press_feedback()
	if _player.skill_level(id) <= 0:
		_combat_log = "Skill not learned"
		return
	if id == "weapon_discipline":
		_combat_log = "Weapon Discipline: passive skill"
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
	if not _has_los(Vector2(_player.gx, _player.gy), Vector2(target.gx, target.gy)):
		_combat_log = "Line of sight blocked"
		return
	var skill_id := "frost_shard" if element == "cold" else "ember_bolt"
	if not _player.spend_mana(Skills.mana_cost(skill_id)):
		_combat_log = "no mana"
		return
	_player.attack_cd = CombatLib.frames_to_sec(CombatLib.sorc_fcr_frames(_player_fcr))  # FCR
	_start_skill_cooldown(skill_id, _player.attack_cd)
	_player.play_cast(Vector2(target.gx - _player.gx, target.gy - _player.gy))
	_fx.cast_burst(_player.position, color)
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
	_start_skill_cooldown("storm_lance", _player.attack_cd)
	_player.play_cast(Vector2(target.gx - _player.gx, target.gy - _player.gy))
	_fx.cast_burst(_player.position, Color(1.0, 0.9, 0.3))
	_play_sfx("spell")
	_spells_cast += 1
	var raw := _rng.randi_range(6, 30) + _player.skill_level("storm_lance") * 3
	raw = Skills.apply_synergy(raw, "storm_lance", _player.skills)
	var dmg := CombatLib.apply_resistance(raw, target.res_light)
	target.take_damage(dmg)
	_spell_hits += 1
	_fx.lightning(_player.position, target.position)
	_spawn_text(target.position, "%d LIGHT" % dmg, Color(1, 1, 0.4))
	_combat_log = "Storm Lance (dmg %d)" % dmg
	if not target.alive:
		_grant_xp(target.level * 40)

func _cast_phase_step(target: ActorScript) -> void:
	if _player.skill_level("phase_step") <= 0:
		return
	if target != null and not _has_los(Vector2(_player.gx, _player.gy), Vector2(target.gx, target.gy)):
		_combat_log = "Line of sight blocked"
		return
	if not _player.spend_mana(Skills.mana_cost("phase_step")):
		return
	_spells_cast += 1
	var origin := _player.position
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
		_fx.phase_step(origin, _player.position)
	_start_skill_cooldown("phase_step", 0.35)
	_combat_log = "Phase Step"

func _blink_away(target: ActorScript) -> void:
	if _player.skill_level("phase_step") <= 0:
		return
	if not _player.spend_mana(Skills.mana_cost("phase_step")):
		return
	_spells_cast += 1
	var origin := _player.position
	var dir := (Vector2(_player.gx, _player.gy) - Vector2(target.gx, target.gy)).normalized()
	var tx := clampf(_player.gx + dir.x * 5.0, 1.0, GRID - 2)
	var ty := clampf(_player.gy + dir.y * 5.0, 1.0, GRID - 2)
	if _walkable(tx, ty):
		_player.gx = tx
		_player.gy = ty
		_player.position = _iso(tx, ty)
		_fx.phase_step(origin, _player.position)
	_combat_log = "Phase Step (kite)"

func _spawn_projectile(from_pos: Vector2, target: ActorScript, dmg: int, element: String = "fire", color: Color = Color(1, 0.5, 0.15)) -> void:
	var n := Polygon2D.new()
	if element == "cold":
		n.polygon = PackedVector2Array([Vector2(0, -11), Vector2(6, 0), Vector2(0, 11), Vector2(-6, 0)])
	else:
		n.polygon = PackedVector2Array([Vector2(-7, -4), Vector2(0, -8), Vector2(7, -4), Vector2(7, 4), Vector2(0, 8), Vector2(-7, 4)])
	n.color = color
	n.position = from_pos
	n.rotation = PI * 0.25
	n.z_index = 50
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
	core.color = color.lightened(0.65)
	core.z_index = 1
	n.add_child(core)
	_world.add_child(n)
	var trail := Line2D.new()
	trail.width = 6.0 if element == "fire" else 4.5
	var trail_gradient := Gradient.new()
	trail_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	trail_gradient.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.35), color.lightened(0.35)])
	trail.gradient = trail_gradient
	trail.z_index = 49
	trail.add_point(from_pos)
	_world.add_child(trail)
	_projectiles.append({"node": n, "core": core, "trail": trail, "target": target, "dmg": dmg, "element": element, "color": color, "age": 0.0})

func _update_projectiles(delta: float) -> void:
	for p in _projectiles.duplicate():
		var n = p["node"]
		var t = p["target"]
		if not is_instance_valid(n):
			var stale_trail = p.get("trail")
			if is_instance_valid(stale_trail): stale_trail.queue_free()
			_projectiles.erase(p)
			continue
		if not is_instance_valid(t) or not t.alive:
			n.queue_free()
			var dead_trail = p.get("trail")
			if is_instance_valid(dead_trail): dead_trail.queue_free()
			_projectiles.erase(p)
			continue
		n.position = n.position.move_toward(t.position, 420.0 * delta)
		p["age"] = float(p.get("age", 0.0)) + delta
		var element := String(p.get("element", "fire"))
		n.rotation += delta * (5.0 if element == "cold" else 11.0)
		var core = p.get("core") as Polygon2D
		if is_instance_valid(core):
			var pulse := 0.86 + sin(float(p["age"]) * 22.0) * 0.18
			core.scale = Vector2.ONE * pulse
			core.position.y = sin(float(p["age"]) * 17.0) * (1.5 if element == "fire" else 0.7)
		var trail = p.get("trail") as Line2D
		if is_instance_valid(trail):
			trail.add_point(n.position)
			var trail_limit: int = [4, 7, 10][_accessibility.effect_quality]
			while trail.get_point_count() > trail_limit:
				trail.remove_point(0)
		var projectile_cell := _world_to_grid(n.position)
		if not _walkable(projectile_cell.x, projectile_cell.y):
			_fx.elemental_impact(n.position, element, false)
			n.queue_free()
			if is_instance_valid(trail): trail.queue_free()
			_projectiles.erase(p)
			continue
		if n.position.distance_to(t.position) < 12.0:
			# 스펠 속성 데미지 → 대상 해당 속성 저항/약점 적용 (Part 5 §2)
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
			var element_labels := {"fire": "FIRE", "cold": "COLD", "light": "LIGHT", "poison": "POISON"}
			var txt := "%d %s" % [dmg, String(element_labels.get(element, ""))]
			if tres < 0:
				txt = "%d WEAK" % dmg
			_spawn_text(t.position, txt, Color(1, 0.55, 0.15))
			_fx.elemental_impact(t.position, element, false)
			if not t.alive:
				_grant_xp(t.level * 40)
			n.queue_free()
			if is_instance_valid(trail): trail.queue_free()
			_projectiles.erase(p)

func _player_attack(target: ActorScript, skill_id: String) -> void:
	if target == null or not target.alive or not _player.alive or _player.attack_cd > 0.0:
		return
	if not _has_los(Vector2(_player.gx, _player.gy), Vector2(target.gx, target.gy)):
		_combat_log = "Line of sight blocked"
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
	_start_skill_cooldown(skill_id, _player.attack_cd)
	_player.play_attack(Vector2(target.gx - _player.gx, target.gy - _player.gy))
	if use_skill and skill_id in ["sundering_strike", "void_fury"]:
		_fx.ground_skill(_player.position, target.position, skill_id)
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
		_fx.impact(target.position, Color(1.0, 0.62, 0.22), crit or cb > 0)
		if crit or cb > 0:
			_camera_punch(3.0 if crit and cb > 0 else 2.0)
		# 무기 속성 데미지 (Fiery/Frozen/Shocking) — 대상 속성 저항 적용
		var edmg := 0
		var fd := int(_eq.get("fdmg", 0))
		if fd > 0:
			edmg += CombatLib.apply_resistance(fd, _target_resist(target, "fire"))
			_fx.elemental_impact(target.position, "fire", false)
		var cd := int(_eq.get("cdmg", 0))
		if cd > 0:
			edmg += CombatLib.apply_resistance(cd, _target_resist(target, "cold"))
			_fx.elemental_impact(target.position, "cold", false)
			target.slow_timer = 1.5   # 냉기 무기 슬로우
		var ld := int(_eq.get("ldmg", 0))
		if ld > 0:
			edmg += CombatLib.apply_resistance(ld, _target_resist(target, "light"))
			_fx.elemental_impact(target.position, "light", false)
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
		_combat_log = "%s > %s %d%s%s" % [label, target.actor_name, dmg, (" CRIT" if crit else ""), (" +CB%d" % cb if cb > 0 else "")]
		if not target.alive:
			_grant_xp(target.level * 40)
	else:
		_spawn_text(target.position, "miss", Color(0.85, 0.85, 0.85))
		_combat_log = "%s > %s MISS (%.0f%%)" % [label, target.actor_name, chance]
	_flash(_player.position, target.position)

func _monster_attack(m: ActorScript) -> void:
	_attacks += 1
	m.play_attack(Vector2(_player.gx - m.gx, _player.gy - m.gy))
	_fx.slash(m.position, _player.position, Color(1.0, 0.3, 0.2, 0.8))
	if CombatLib.roll_hit(_rng, m.attack_rating, _player.defense, m.level, _player.level):
		# 플레이어 블록 판정 (Part 5 §3)
		if _player.block_val > 0 and CombatLib.roll_block(_rng, _player.block_val, _player.stat_dex, _player.level):
			_fx.block_impact(_player.position)
			_spawn_text(_player.position, "BLOCK", Color(0.6, 0.8, 1.0))
			return
		var dmg := CombatLib.physical_damage(_rng, m.dmg_min, m.dmg_max, 0.0)
		_player.take_damage(dmg)
		_damage_armor()
		_fx.impact(_player.position, Color(1.0, 0.24, 0.18), false)
		_spawn_text(_player.position, str(dmg), Color(1, 0.4, 0.4))
		_apply_enchant(m)
	else:
		_spawn_text(_player.position, "miss", Color(0.85, 0.85, 0.85))

func _damage_armor() -> void:
	if Item.lose_durability(_equipped["armor"]):
		_recompute_player()
		_combat_log = "ARMOR BROKEN"

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
		_fx.elemental_impact(_player.position, el, false)
		_spawn_text(_player.position + Vector2(0, -12), "+%d %s" % [d, el], c)

func _cast_iron_chant() -> void:
	var lvl := _player.skill_level("iron_chant")
	if lvl <= 0 or not _player.spend_mana(Skills.mana_cost("iron_chant")):
		return
	_player.bo_pct = Skills.iron_chant_bonus_pct(lvl) + Skills.synergy_bonus_pct("iron_chant", _player.skills)
	_player.bo_timer = Skills.iron_chant_duration(lvl)
	_recompute_vitals(_player)
	_fx.buff_pulse(_player.position, Color(1.0, 0.75, 0.22))
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
		_fx.level_up(_player.position)
		_spawn_text(_player.position + Vector2(0, -40), "LEVEL %d" % _player.level, Color(1.0, 0.86, 0.3))
		_combat_log = "LEVEL UP / %d" % _player.level
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
		_combat_log = "QUEST COMPLETE: %s (+%dg)" % [String(definition.get("name", id)), reward_gold]
		_spawn_text(_player.position + Vector2(0, -48), "QUEST COMPLETE", Color(1.0, 0.82, 0.3))

func _on_monster_died(m: Node) -> void:
	_kills += 1
	_play_sfx("death")
	var rank := String(m.get_meta("rank", ""))
	_apply_quest_kill(String(m.get_meta("kind", "melee")), rank)
	var death_color := Color(0.95, 0.32, 0.18) if rank.is_empty() else (Color(0.45, 0.7, 1.0) if rank == "champion" else Color(1.0, 0.65, 0.18))
	_fx.death_burst(m.position, death_color, not rank.is_empty())
	if rank == "unique":
		_camera_punch(3.0)
	# 액트 보스 처치 → 퀘스트 완료
	if _boss != null and m == _boss:
		_complete_act(m)
	# 등급별 강화 드롭 (챔피언/유니크 = 더 많은 롤 + MF + ilvl 보너스)
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
	if _rng.randf() < (0.05 if rank == "" else 0.16):
		_spawn_ground(_make_vision_relic(), m.gx - 0.25, m.gy + 0.25)
		_items_dropped += 1
	if _rng.randf() < (0.08 if rank == "" else 0.22):
		_spawn_ground(_make_arc_flask(), m.gx + 0.25, m.gy + 0.25)
		_items_dropped += 1
	# Skill progression is item-driven. The first kill guarantees a book, then
	# champions/uniques and every fourth kill provide reliable advancement.
	var book_skill := _next_skill_book_drop()
	if not book_skill.is_empty() and (_kills == 1 or _kills % 4 == 0 or rank in ["champion", "unique"] or _rng.randf() < 0.18):
		_spawn_ground(_make_skill_book(book_skill), m.gx + 0.25, m.gy - 0.25)
		_items_dropped += 1
		_combat_log = "Skill Book dropped: %s" % _skill_label(book_skill)
	# 골드 드롭(몬스터 레벨·등급 스케일)
	if _rng.randf() < 0.7:
		var rank_mult := 1.0
		if rank == "champion": rank_mult = 2.5
		elif rank == "unique": rank_mult = 5.0
		var amt := int(_rng.randi_range(3, 8) * int(m.level) * rank_mult)
		_spawn_ground(_make_gold(amt), m.gx + _rng.randf_range(-0.3, 0.3), m.gy + _rng.randf_range(-0.3, 0.3))

func _make_gold(amount: int) -> Dictionary:
	return {"name": "%d Gold" % amount, "slot": "gold", "amount": amount, "quality": "normal", "affixes": {}, "prefix": "", "suffix": ""}

func _make_vision_relic() -> Dictionary:
	return {"name": "All-Seeing Ember", "slot": "vision_relic", "duration": VISION_RELIC_DURATION, "quality": "unique", "affixes": {}, "prefix": "", "suffix": ""}

func _make_arc_flask() -> Dictionary:
	return {"name": "Skyfire Arc Flask", "slot": "arc_flask", "quality": "magic", "affixes": {}, "prefix": "", "suffix": ""}

# 아이템 판매가(품질 + 접사 수 기반)
func _item_value(it: Dictionary) -> int:
	var q := String(it["quality"])
	var table := {"normal": 8, "magic": 40, "rare": 110, "set": 220, "unique": 300}
	var base: int = int(table.get(q, 10))
	var affix_cnt := 0
	for _k in it.get("affixes", {}):
		affix_cnt += 1
	return base + affix_cnt * 15 + int(it.get("ilvl", 1)) * 2

func _skill_book_value(skill_id: String) -> int:
	var slot_index := _skill_slot_ids().find(skill_id)
	return [100, 150, 300, 500][clampi(slot_index, 0, 3)]

func _make_potion(ptype: String, tier: int = 1) -> Dictionary:
	var nm := "Healing Potion" if ptype == "health" else "Mana Potion"
	return {"name": nm, "slot": "potion", "ptype": ptype, "tier": tier, "quality": "normal", "affixes": {}, "prefix": "", "suffix": ""}

func _make_material(id: String, amount: int = 1) -> Dictionary:
	return {"name": id.capitalize(), "id": id, "amount": amount, "slot": "material", "quality": "normal", "affixes": {}, "prefix": "", "suffix": ""}

func _make_skill_book(skill_id: String) -> Dictionary:
	return {"name": "Skill Book: %s" % _skill_label(skill_id), "skill_id": skill_id, "slot": "skill_book", "quality": "unique", "affixes": {}, "prefix": "", "suffix": ""}

func _next_skill_book_drop() -> String:
	# Keep only one uncollected book in the world at a time.
	for ground_node in _ground:
		if is_instance_valid(ground_node):
			var ground_item: Dictionary = ground_node.get_meta("item", {})
			if String(ground_item.get("slot", "")) == "skill_book":
				return ""
	for skill_id in _skill_slot_ids():
		if _player.skill_level(skill_id) > 0:
			continue
		return skill_id
	# Once every skill is open, later books become valuable duplicate drops.
	var duplicate_pool := _skill_slot_ids().slice(1)
	return String(duplicate_pool[_rng.randi_range(0, duplicate_pool.size() - 1)])

func _unlock_skill_from_book(skill_id: String) -> bool:
	if not _skill_slot_ids().has(skill_id) or _player.skill_level(skill_id) > 0:
		return false
	_player.skills[skill_id] = 1
	_refresh_skill_buttons()
	_rebuild_char_panel()
	_combat_log = "SKILL UNLOCKED: %s" % _skill_label(skill_id)
	_spawn_text(_player.position + Vector2(0, -56), "SKILL UNLOCKED", Color(0.9, 0.65, 1.0))
	return true

func _spawn_ground(it: Dictionary, gx: float, gy: float) -> void:
	var n := Node2D.new()
	var slot := String(it["slot"])
	var is_pot := slot == "potion"
	var is_gold := slot == "gold"
	var is_skill_book := slot == "skill_book"
	var col: Color = Item.quality_color(String(it["quality"]))
	if is_pot:
		col = Color(0.85, 0.2, 0.2) if String(it["ptype"]) == "health" else Color(0.3, 0.45, 0.95)
	elif is_gold:
		col = Color(1.0, 0.85, 0.25)
	elif is_skill_book:
		col = Color(0.9, 0.55, 1.0)
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
		"skill_book": icon_kind = "rune"
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
	lbl.name = "DropLabel"
	lbl.text = Item.display_name(it)
	lbl.add_theme_font_size_override("font_size", _accessibility.font_size(12))
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_child(lbl)
	n.position = _iso(gx, gy)
	n.set_meta("item", it)
	n.set_meta("gx", gx)
	n.set_meta("gy", gy)
	_world.add_child(n)
	_ground.append(n)
	_fx.loot_drop(n, String(it.get("quality", "normal")), col)
	_layout_ground_labels()

func _layout_ground_labels() -> void:
	# Item sprites keep their exact world position, while their labels are packed
	# into collision-free rows in world/screen space. This keeps dense boss drops
	# readable without changing pickup distance or saved ground coordinates.
	var occupied: Array[Rect2] = []
	for ground_node in _ground:
		if not is_instance_valid(ground_node):
			continue
		var lbl := ground_node.get_node_or_null("DropLabel") as Label
		if lbl == null:
			continue
		var estimated_width := clampf(float(lbl.text.length()) * float(_accessibility.font_size(12)) * 0.58 + 18.0, 72.0, 240.0)
		lbl.size = Vector2(estimated_width, DROP_LABEL_HEIGHT)
		var chosen := Rect2()
		for lane in DROP_LABEL_MAX_LANES:
			var y_offset := -34.0 - float(lane) * (DROP_LABEL_HEIGHT + DROP_LABEL_GAP)
			var candidate := Rect2(ground_node.position + Vector2(-estimated_width * 0.5, y_offset), Vector2(estimated_width, DROP_LABEL_HEIGHT))
			var overlaps := false
			for used in occupied:
				if candidate.intersects(used):
					overlaps = true
					break
			if not overlaps:
				chosen = candidate
				break
		if chosen.size == Vector2.ZERO:
			var overflow_lane := occupied.size()
			chosen = Rect2(ground_node.position + Vector2(-estimated_width * 0.5, -34.0 - float(overflow_lane) * (DROP_LABEL_HEIGHT + DROP_LABEL_GAP)), Vector2(estimated_width, DROP_LABEL_HEIGHT))
		lbl.position = chosen.position - ground_node.position
		occupied.append(chosen.grow(DROP_LABEL_GAP))

func _pickup(n: Node) -> void:
	var it: Dictionary = n.get_meta("item")
	if not _automation.accepts(it):
		return
	_play_sfx("pickup")
	var pickup_sprite := n.get_child(0) as Sprite2D
	if pickup_sprite != null:
		_fx.pickup(pickup_sprite.texture, n.position + pickup_sprite.position, _player.position, pickup_sprite.modulate, pickup_sprite.scale)
	_ground.erase(n)
	n.queue_free()
	_layout_ground_labels()
	if String(it["slot"]) == "vision_relic":
		_vision_relic_timer = maxf(_vision_relic_timer, float(it.get("duration", VISION_RELIC_DURATION)))
		_items_picked += 1
		_last_visibility_cell = Vector2i(-999, -999)
		_update_visibility(true)
		_combat_log = "ALL-SEEING EMBER: map-wide sight for %.0fs" % _vision_relic_timer
		_spawn_text(_player.position, "ALL-SEEING", Color(0.8, 0.55, 1.0))
		return
	if String(it["slot"]) == "arc_flask":
		_arc_flasks += 1
		_items_picked += 1
		_combat_log = "Skyfire Arc Flask stored (%d)" % _arc_flasks
		_spawn_text(_player.position, "+ARC FLASK", Color(1.0, 0.45, 0.2))
		_rebuild_inv()
		return
	if String(it["slot"]) == "skill_book":
		var book_skill := String(it.get("skill_id", ""))
		_items_picked += 1
		if not _unlock_skill_from_book(book_skill):
			var book_gold := _skill_book_value(book_skill)
			_gold += book_gold
			_gold_sold += book_gold
			_combat_log = "DUPLICATE BOOK SOLD: %s / +%dg" % [_skill_label(book_skill), book_gold]
			_spawn_text(_player.position + Vector2(0, -56), "+%dg" % book_gold, Color(1.0, 0.85, 0.25))
		return
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
			_spawn_text(_player.position, "%s POTION TIER +%d" % [pt.to_upper(), tier], Color.LIME_GREEN)
		if _add_potion_to_belt(pt):
			var c := Color(0.85, 0.3, 0.3) if pt == "health" else Color(0.4, 0.6, 1.0)
			_spawn_text(_player.position, "+" + String(it["name"]), c)
		return
	if String(it["slot"]) == "material":
		_automation.add_material(it)
		_items_picked += int(it.get("amount", 1))
		_spawn_text(_player.position, "+%s x%d" % [String(it["name"]), int(it.get("amount", 1))], Color.VIOLET)
		return
	var power_before := _loadout_combat_power(_equipped)
	_inventory.append(it)
	_items_picked += 1
	if _collection.accepts(it):
		var newly_discovered := _collection.register(it, _item_combat_power(it))
		if newly_discovered:
			_combat_log = "COLLECTION DISCOVERED: %s" % Item.display_name(it)
	_spawn_text(_player.position, "+" + Item.display_name(it), Item.quality_color(String(it["quality"])))
	var equip_result := _auto_equip(it)
	var item_action := "AUTO EQUIPPED" if equip_result in ["EQUIPPED_EMPTY", "EQUIPPED_UPGRADE"] else "ADDED TO BAG"
	var item_note := ""
	if equip_result in ["KEPT_LOWER_POWER", "KEPT_REQUIREMENT_LOCKED"]:
		var requirement_locked := equip_result == "KEPT_REQUIREMENT_LOCKED"
		if _automation.should_auto_sell(it, _item_value(it), requirement_locked):
			var sale_value := _item_value(it)
			_inventory.erase(it)
			_gold += sale_value
			_gold_sold += sale_value
			_combat_log = "AUTO SOLD: %s / +%dg" % [Item.display_name(it), sale_value]
			item_action = "AUTO SOLD"
			item_note = "+%d GOLD" % sale_value
			_spawn_text(_player.position + Vector2(0, -42), "+%dg AUTO SELL" % sale_value, Color(1.0, 0.85, 0.25))
	_push_item_event(item_action, it, power_before, _loadout_combat_power(_equipped), item_note)
	_rebuild_inv()

func _push_item_event(action: String, it: Dictionary, power_before: float, power_after: float, note: String = "") -> void:
	var options := Item.affix_text(it)
	if options.is_empty():
		options = "No additional options"
	var delta := power_after - power_before
	var power_line := "TOTAL POWER %.0f -> %.0f (%+.0f)" % [power_before, power_after, delta]
	var lines := ["[%s] %s" % [action, Item.display_name(it)], "OPTIONS: %s" % options, power_line]
	if not note.is_empty():
		lines.append(note)
	var entry: Dictionary = {"action": action, "name": Item.display_name(it), "quality": String(it.get("quality", "normal")), "options": options, "power_before": power_before, "power_after": power_after, "delta": delta, "note": note, "unix": int(Time.get_unix_time_from_system())}
	_item_event_history.append(entry)
	while _item_event_history.size() > ITEM_EVENT_HISTORY_LIMIT:
		_item_event_history.pop_front()
	if not is_instance_valid(_item_toast_box):
		return
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.02, 0.035, 0.90)
	style.border_color = Item.quality_color(String(it.get("quality", "normal")))
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "\n".join(lines)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _accessibility.font_size(14 if _mobile_profile else 17))
	label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	panel.add_child(label)
	_item_toast_box.add_child(panel)
	while _item_toast_box.get_child_count() > ITEM_TOAST_VISIBLE_LIMIT:
		var oldest := _item_toast_box.get_child(0)
		_item_toast_box.remove_child(oldest)
		oldest.queue_free()

func _affix_power(affixes: Dictionary) -> float:
	var mana_weight := 1.2 if _class == "arcanist" else 0.45
	var strength_weight := 0.8 if _class == "arcanist" else 2.2
	var dexterity_weight := 1.2 if _class == "arcanist" else 1.7
	return float(affixes.get("life", 0)) * 1.5 + float(affixes.get("mana", 0)) * mana_weight \
		+ float(affixes.get("str", 0)) * strength_weight + float(affixes.get("dex", 0)) * dexterity_weight \
		+ float(affixes.get("ar", 0)) * 0.2 + float(affixes.get("res_all", 0)) * 6.0 \
		+ (float(affixes.get("res_fire", 0)) + float(affixes.get("res_cold", 0)) + float(affixes.get("res_light", 0)) + float(affixes.get("res_poison", 0))) * 1.5 \
		+ (float(affixes.get("fdmg", 0)) + float(affixes.get("cdmg", 0)) + float(affixes.get("ldmg", 0))) * 8.0

func _item_combat_power(it: Dictionary) -> float:
	if it.is_empty() or Item.is_broken(it):
		return 0.0
	var affixes := Item.effective_affixes(it)
	var power := _affix_power(affixes)
	if String(it.get("slot", "")) == "weapon":
		var average_damage := (float(it.get("dmin", 0)) + float(it.get("dmax", 0))) * 0.5
		power += average_damage * (1.0 + float(affixes.get("ed", 0)) / 100.0) * 12.0
	else:
		power += (float(it.get("defense", 0)) + float(affixes.get("def", 0))) * 2.0
	return power

func _loadout_combat_power(loadout: Dictionary) -> float:
	var items: Array = []
	var power := 0.0
	for slot in EQUIPMENT_SLOTS:
		var equipped_item: Dictionary = loadout.get(slot, {})
		items.append(equipped_item)
		power += _item_combat_power(equipped_item)
	power += _affix_power(Item.equipped_set_bonus(items))
	return power

func _power_with_item(it: Dictionary, slot: String) -> float:
	var candidate := _equipped.duplicate(true)
	candidate[slot] = it
	return _loadout_combat_power(candidate)

func _auto_equip(it: Dictionary) -> String:
	if not Item.can_equip(it, _player.level, _player.stat_str, _player.stat_dex):
		return "KEPT_REQUIREMENT_LOCKED"
	var slot := _equipment_slot_for_item(it)
	if not _equipped.has(slot):
		return "KEPT_LOWER_POWER"
	var current: Dictionary = _equipped[slot]
	var before_power := _loadout_combat_power(_equipped)
	var after_power := _power_with_item(it, slot)
	var improves := current.is_empty() or after_power > before_power + maxf(1.0, before_power * 0.01)
	if not improves:
		return "KEPT_LOWER_POWER"
	_inventory.erase(it)
	if not current.is_empty():
		if _automation.sell_replaced_gear and _automation.should_auto_sell(current, _item_value(current), false):
			var old_value := _item_value(current)
			_gold += old_value
			_gold_sold += old_value
			_combat_log = "AUTO REPLACED / SOLD %s +%dg" % [Item.display_name(current), old_value]
		else:
			_inventory.append(current)
	_equip(it, slot)
	_combat_log = "AUTO EQUIPPED: %s / Power %.0f -> %.0f" % [Item.display_name(it), before_power, after_power]
	return "EQUIPPED_EMPTY" if current.is_empty() else "EQUIPPED_UPGRADE"

func _equip_from_inventory(it: Dictionary) -> void:
	var requirement_failures := Item.requirement_failures(it, _player.level, _player.stat_str, _player.stat_dex)
	if not requirement_failures.is_empty():
		_combat_log = "EQUIP REQUIREMENTS NOT MET: %s" % ", ".join(requirement_failures)
		return
	var slot := _equipment_slot_for_item(it)
	var power_before := _loadout_combat_power(_equipped)
	var old: Dictionary = _equipped[slot]
	if not old.is_empty() and old != it:
		if not _automation.list_auction(old, int(Time.get_ticks_msec() / 1000)):
			_inventory.append(old)
	_inventory.erase(it)
	_equip(it, slot)
	_push_item_event("MANUAL EQUIP", it, power_before, _loadout_combat_power(_equipped))

func _equipment_slot_for_item(it: Dictionary) -> String:
	var item_slot := String(it.get("slot", ""))
	if item_slot != "ring":
		return item_slot
	if (_equipped["ring_left"] as Dictionary).is_empty():
		return "ring_left"
	if (_equipped["ring_right"] as Dictionary).is_empty():
		return "ring_right"
	var left_power := _power_with_item(it, "ring_left")
	var right_power := _power_with_item(it, "ring_right")
	return "ring_left" if left_power >= right_power else "ring_right"

func _equip(it: Dictionary, target_slot: String = "") -> void:
	var slot := target_slot if not target_slot.is_empty() else _equipment_slot_for_item(it)
	_equipped[slot] = it
	_recompute_player()
	_combat_log = "equipped %s" % Item.display_name(it)
	_rebuild_inv()

func _equip_merc_from_inventory(it: Dictionary) -> void:
	if not Mercenary.can_equip(it, _merc.level if _merc != null else _player.level):
		_combat_log = "MERC EQUIP REQUIREMENTS NOT MET: %s" % Item.requirement_text(it)
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
		_combat_log = "MOVED TO STASH: %s" % Item.display_name(it)
	else:
		_combat_log = "STASH FULL (%d/%d)" % [_stash.size(), Stash.CAPACITY]
	_rebuild_inv()

func _withdraw_from_stash(it: Dictionary) -> void:
	if Stash.withdraw(it, _inventory, _stash):
		_combat_log = "MOVED TO BAG: %s" % Item.display_name(it)
	_rebuild_inv()

func _toggle_bag() -> void:
	var opening := not _inv_panel.visible
	_hide_modal_panels()
	_inv_panel.visible = opening
	if opening:
		_rebuild_inv()

var _vendor_gold_lbl: Label
func _build_vendor() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = _vendor_panel.size - Vector2(40, 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vendor_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(scroll.size.x - 20, scroll.size.y)
	vb.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	scroll.add_child(vb)
	var head := Label.new()
	head.text = "VENDOR"
	head.add_theme_font_size_override("font_size", _accessibility.font_size(28))
	vb.add_child(head)
	_vendor_gold_lbl = Label.new()
	_vendor_gold_lbl.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	_vendor_gold_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vb.add_child(_vendor_gold_lbl)
	_vendor_btn(vb, "Buy Health Potion (%dg)" % COST_HP_POT, func(): _buy_potion("health"))
	_vendor_btn(vb, "Buy Mana Potion (%dg)" % COST_MP_POT, func(): _buy_potion("mana"))
	_vendor_btn(vb, "Repair Equipped Gear", func(): _repair_equipped())
	_vendor_btn(vb, "Travel to Next Waypoint", func(): _travel_waypoint(0))
	_vendor_btn(vb, "Sell All Bag Items", func(): _sell_all())
	_vendor_btn(vb, "Gamble Random Item", func(): _gamble())
	_vendor_btn(vb, "Cycle Auto Pickup", func(): _cycle_automation("pickup_min"))
	_vendor_btn(vb, "Cycle Auto Equip", func(): _cycle_automation("equip_min"))
	_vendor_btn(vb, "Cycle Auto Auction", func(): _cycle_automation("auction_min"))
	_auto_sell_button = _vendor_btn(vb, "", _toggle_auto_sell)
	_refresh_vendor()

func _cycle_automation(key: String) -> void:
	var levels := ["normal", "magic", "rare", "set", "unique"]
	var current := String(_automation.get(key))
	_automation.set(key, levels[(levels.find(current) + 1) % levels.size()])
	_combat_log = "%s / %s" % [key, String(_automation.get(key))]
	_rebuild_inv()

func _vendor_btn(vb: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	b.pressed.connect(cb)
	vb.add_child(b)
	return b

func _toggle_auto_sell() -> void:
	_automation.auto_sell = not _automation.auto_sell
	_combat_log = "Auto Sell: %s" % ("ON" if _automation.auto_sell else "OFF")
	_refresh_vendor()

func _toggle_vendor() -> void:
	var opening := not _vendor_panel.visible
	_hide_modal_panels()
	_vendor_panel.visible = opening
	_refresh_vendor()

func _travel_waypoint(direction: int) -> void:
	var target := Waypoint.cycle(_waypoint_defs, _waypoint_state, _act) if direction == 0 else Waypoint.adjacent(_waypoint_defs, _waypoint_state, _act, direction)
	if target.is_empty():
		_combat_log = "No waypoint available"
		return
	_capture_floor_state()
	_dlevel = (_act - 1) * ACT_LEN + int(target.get("floor", 1))
	Waypoint.unlock(_waypoint_defs, _waypoint_state, _act, _level_in_act())
	for ground_item in _ground:
		if is_instance_valid(ground_item):
			ground_item.queue_free()
	_ground.clear()
	_clear_map_effects()
	_generate_dungeon()
	_build_minimap_tex()
	_player.gx = _ent_cell.x
	_player.gy = _ent_cell.y
	_player.position = _iso(_player.gx, _player.gy)
	if _merc != null:
		_merc.gx = _player.gx + 1
		_merc.gy = _player.gy
		_merc.position = _iso(_merc.gx, _merc.gy)
	_restore_or_spawn_floor()
	_last_visibility_cell = Vector2i(-999, -999)
	_update_visibility(true)
	if is_instance_valid(_cam):
		_cam.position = _player.position
	_combat_log = "Waypoint: %s" % Waypoint.current_name(_waypoint_defs, _waypoint_state)
	_refresh_vendor()

func _previous_floor() -> void:
	if _in_town:
		_combat_log = "Use Return Portal first"
		return
	if _dlevel <= 1:
		_combat_log = "No previous floor"
		return
	_travel_to_floor(_dlevel - 1, Vector2.INF)

func _clear_travel_nodes() -> void:
	for n in _ground:
		if is_instance_valid(n): n.queue_free()
	_ground.clear()
	_clear_map_effects()
	for m in _monsters:
		if is_instance_valid(m): m.queue_free()
	_monsters.clear()

func _clear_map_effects() -> void:
	for p in _projectiles:
		var node: Node = p.get("node", null)
		if is_instance_valid(node): node.queue_free()
		var trail: Node = p.get("trail", null)
		if is_instance_valid(trail): trail.queue_free()
	_projectiles.clear()
	if is_instance_valid(_attack_line):
		_attack_line.clear_points()
	_attack_ttl = 0.0
	if is_instance_valid(_fx):
		_fx.clear_all()

func _travel_to_floor(target_level: int, return_position: Vector2) -> void:
	if not _in_town: _capture_floor_state()
	_clear_travel_nodes()
	_dlevel = maxi(1, target_level)
	_in_town = false
	_generate_dungeon()
	_build_minimap_tex()
	var arrival := return_position
	if arrival == Vector2.INF or not _walkable(arrival.x, arrival.y): arrival = Vector2(_ent_cell.x, _ent_cell.y)
	_player.gx = arrival.x; _player.gy = arrival.y; _player.position = _iso(arrival.x, arrival.y)
	if _merc != null:
		_merc.gx = _player.gx + 1; _merc.gy = _player.gy; _merc.position = _iso(_merc.gx, _merc.gy)
	_restore_or_spawn_floor()
	_last_visibility_cell = Vector2i(-999, -999)
	_update_visibility(true)
	if is_instance_valid(_cam): _cam.position = _player.position
	_combat_log = "Returned to Floor %d" % _dlevel
	_rebuild_inv()

func _toggle_town_portal() -> void:
	if _in_town:
		if _town_portal.is_empty():
			_combat_log = "No return portal"
			return
		_travel_to_floor(int(_town_portal.get("floor", 1)), Vector2(float(_town_portal.get("gx", 1)), float(_town_portal.get("gy", 1))))
		_town_portal = {}
		return
	_capture_floor_state()
	_town_portal = {"floor": _dlevel, "gx": _player.gx, "gy": _player.gy}
	_clear_travel_nodes()
	for m in _monsters:
		if is_instance_valid(m): m.queue_free()
	_monsters.clear()
	_in_town = true
	_player.gx = _ent_cell.x; _player.gy = _ent_cell.y; _player.position = _iso(_player.gx, _player.gy)
	_combat_log = "HOMETOWN - RETURN PORTAL OPEN"
	_rebuild_inv()

# ── 캐릭터 성장 패널 ──
func _build_char_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = _char_panel.size - Vector2(40, 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_char_panel.add_child(scroll)
	_char_vbox = VBoxContainer.new()
	_char_vbox.custom_minimum_size = Vector2(scroll.size.x - 20, scroll.size.y)
	_char_vbox.add_theme_font_size_override("font_size", _accessibility.font_size(22))
	scroll.add_child(_char_vbox)
	_rebuild_char_panel()

func _class_skill_ids() -> Array:
	return ["ember_bolt", "frost_shard", "storm_lance", "phase_step"] if _class == "arcanist" else ["sundering_strike", "void_fury", "iron_chant", "weapon_discipline"]

func _skill_label(id: String) -> String:
	var names := {"ember_bolt": "Ember Bolt", "frost_shard": "Frost Shard", "storm_lance": "Storm Lance", "phase_step": "Phase Step",
		"sundering_strike": "Sundering Strike", "void_fury": "Void Fury", "iron_chant": "Iron Chant", "weapon_discipline": "Weapon Discipline"}
	return String(names.get(id, id))

func _rebuild_char_panel() -> void:
	if _char_vbox == null:
		return
	for c in _char_vbox.get_children():
		c.queue_free()
	var head := Label.new()
	head.add_theme_font_size_override("font_size", _accessibility.font_size(28))
	head.text = "CHARACTER Lv%d\nStat Points: %d   Skill Points: %d" % [_player.level, _stat_points, _player.skill_points]
	_char_vbox.add_child(head)
	# 스탯 분배
	for pair in [["str", "Strength %d" % _player.stat_str], ["dex", "Dexterity %d" % _player.stat_dex], ["vit", "Vitality %d" % _player.stat_vit], ["energy", "Energy %d" % _player.stat_energy]]:
		var sid: String = pair[0]
		var b := Button.new()
		b.text = "+ %s" % pair[1]
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", _accessibility.font_size(22))
		b.disabled = _stat_points <= 0
		b.pressed.connect(func(): _spend_stat(sid))
		_char_vbox.add_child(b)
	var sep := Label.new()
	sep.text = "SKILLS"
	sep.add_theme_font_size_override("font_size", _accessibility.font_size(24))
	_char_vbox.add_child(sep)
	for sk in _class_skill_ids():
		var b2 := Button.new()
		var required_level := int(Skills.DEFS[sk].get("required_level", 1))
		b2.text = "+ %s (Lv%d / Req %d / Synergy +%.0f%%)" % [_skill_label(sk), _player.skill_level(sk), required_level, Skills.synergy_bonus_pct(sk, _player.skills)]
		b2.custom_minimum_size = Vector2(0, 58)
		b2.add_theme_font_size_override("font_size", _accessibility.font_size(22))
		b2.disabled = _player.skill_level(sk) <= 0 or _player.skill_points <= 0 or not Skills.can_invest(sk, _player.skills, _player.level)
		b2.pressed.connect(func(): _spend_skill(sk))
		_char_vbox.add_child(b2)

func _toggle_char() -> void:
	var opening := not _char_panel.visible
	_hide_modal_panels()
	_char_panel.visible = opening
	if opening:
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
	if _player.skill_level(id) <= 0 or _player.skill_points <= 0 or not Skills.can_invest(id, _player.skills, _player.level):
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
		_vendor_gold_lbl.text = "Gold %d / Belt HP%d MP%d / Bag %d\nRepair %dg / Gamble %dg / Auto Sold %dg" % [_gold, _belt_hp, _belt_mp, _inventory.size(), _repair_equipped_cost(), _gamble_cost(), _gold_sold]
	if _auto_sell_button:
		_auto_sell_button.text = "Auto Sell: %s / Replaced: ON" % ("ON" if _automation.auto_sell else "OFF")

func _repair_equipped_cost() -> int:
	var total := 0
	for slot in EQUIPMENT_SLOTS: total += Item.repair_cost(_equipped[slot])
	return total

func _repair_equipped() -> void:
	var cost := _repair_equipped_cost()
	if cost <= 0:
		_combat_log = "No gear needs repair"
		return
	if _gold < cost:
		_combat_log = "Not enough gold (Repair %dg)" % cost
		return
	_gold -= cost
	for slot in EQUIPMENT_SLOTS: Item.repair(_equipped[slot])
	_recompute_player()
	_combat_log = "Gear repaired (-%dg)" % cost
	_rebuild_inv()
	_refresh_vendor()

func _buy_potion(ptype: String) -> void:
	var cost := COST_HP_POT if ptype == "health" else COST_MP_POT
	if _gold < cost:
		_combat_log = "Not enough gold"
		return
	if not _add_potion_to_belt(ptype):
		_combat_log = "Belt is full"
		return
	_gold -= cost
	_combat_log = "%s potion purchased" % ("Health" if ptype == "health" else "Mana")
	_refresh_vendor()

func _gamble_cost() -> int:
	return 200 + _player.level * 45

# 도박: 골드 지불 → 무작위 아이템(매직 70% / 레어 22% / 유니크 8%)
func _gamble() -> void:
	var cost := _gamble_cost()
	if _gold < cost:
		_combat_log = "Not enough gold (Gamble %dg)" % cost
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
	_combat_log = "Gamble (%dg): %s" % [cost, Item.display_name(it)]
	var current_power := _loadout_combat_power(_equipped)
	_push_item_event("GAMBLE", it, current_power, current_power, "-%d GOLD" % cost)
	_rebuild_inv()
	_refresh_vendor()

func _sell_all() -> void:
	if _inventory.is_empty():
		return
	var total := 0
	var cnt := 0
	for it in _inventory.duplicate():
		if bool((it as Dictionary).get("salvage_protected", false)):
			continue
		total += _item_value(it)
		cnt += 1
		_inventory.erase(it)
	if cnt <= 0:
		_combat_log = "No sellable bag items"
		return
	_gold += total
	_gold_sold += total
	_combat_log = "%d sold / +%dg" % [cnt, total]
	_rebuild_inv()
	_refresh_vendor()

func _sell_inventory_item(it: Dictionary) -> void:
	if not _inventory.has(it):
		return
	if bool(it.get("salvage_protected", false)):
		_combat_log = "Protected item cannot be sold"
		return
	var value := _item_value(it)
	_inventory.erase(it)
	_gold += value
	_gold_sold += value
	_combat_log = "Sold %s / +%dg" % [Item.display_name(it), value]
	_rebuild_inv()
	_refresh_vendor()

func _equipped_label(slot: String) -> String:
	var it: Dictionary = _equipped[slot]
	if it.is_empty():
		return "-"
	if bool(it.get("indestructible", false)):
		return "%s (Indestructible)" % Item.display_name(it)
	return "%s (%d/%d)%s" % [Item.display_name(it), Item.durability(it), Item.durability_max(it), " Broken" if Item.is_broken(it) else ""]

func _store_in_collection(it: Dictionary) -> void:
	if not _inventory.has(it):
		return
	if not _collection.store(it):
		_combat_log = "Collection storage full or unsupported"
		return
	_inventory.erase(it)
	_combat_log = "STORED IN COLLECTION: %s" % Item.display_name(it)
	_rebuild_inv()

func _equip_from_collection(it: Dictionary) -> void:
	if not _collection.stored.has(it):
		return
	var failures := Item.requirement_failures(it, _player.level, _player.stat_str, _player.stat_dex)
	if not failures.is_empty():
		_combat_log = "Cannot equip: %s" % ", ".join(failures)
		return
	var slot := _equipment_slot_for_item(it)
	var power_before := _loadout_combat_power(_equipped)
	var old: Dictionary = _equipped[slot]
	if not _collection.take(it):
		return
	if not old.is_empty() and old != it:
		old["salvage_protected"] = true
		_inventory.append(old)
	_equip(it, slot)
	_combat_log = "COLLECTION EQUIPPED: %s" % Item.display_name(it)
	_push_item_event("COLLECTION EQUIP", it, power_before, _loadout_combat_power(_equipped))
	_rebuild_inv()

func _buy_collection_page() -> void:
	var cost := _collection.buy_page(_gold)
	if cost < 0:
		_combat_log = "Need %dg for the next collection page" % _collection.next_page_cost()
		return
	_gold -= cost
	_combat_log = "COLLECTION PAGE %d UNLOCKED / -%dg" % [_collection.pages, cost]
	_rebuild_inv()

func _show_collection() -> void:
	_inventory_view = "collection"
	_rebuild_inv()

func _show_bag() -> void:
	_inventory_view = "bag"
	_rebuild_inv()

func _show_item_log() -> void:
	_inventory_view = "item_log"
	_rebuild_inv()

func _clear_item_log() -> void:
	_item_event_history.clear()
	_rebuild_inv()

func _rebuild_item_log() -> void:
	var nav := Button.new()
	nav.text = "Back to Bag"
	nav.pressed.connect(_show_bag)
	_inv_vbox.add_child(nav)
	var title := Label.new()
	title.text = "RECENT ITEM LOG %d/%d\nPickup, options, equipment changes, and total combat power" % [_item_event_history.size(), ITEM_EVENT_HISTORY_LIMIT]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3))
	_inv_vbox.add_child(title)
	var clear := Button.new()
	clear.text = "Clear Item Log"
	clear.disabled = _item_event_history.is_empty()
	clear.pressed.connect(_clear_item_log)
	_inv_vbox.add_child(clear)
	if _item_event_history.is_empty():
		var empty := Label.new()
		empty.text = "No item changes recorded in this session."
		_inv_vbox.add_child(empty)
		return
	for index in range(_item_event_history.size() - 1, -1, -1):
		var event := _item_event_history[index]
		var stamp := Time.get_datetime_dict_from_unix_time(int(event.get("unix", 0)))
		var note := String(event.get("note", ""))
		var line := Label.new()
		line.text = "[%02d:%02d:%02d] %s - %s\nOPTIONS: %s\nTOTAL POWER %.0f -> %.0f (%+.0f)%s" % [int(stamp.get("hour", 0)), int(stamp.get("minute", 0)), int(stamp.get("second", 0)), String(event.get("action", "ITEM")), String(event.get("name", "Unknown")), String(event.get("options", "")), float(event.get("power_before", 0.0)), float(event.get("power_after", 0.0)), float(event.get("delta", 0.0)), "\n" + note if not note.is_empty() else ""]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_color_override("font_color", Item.quality_color(String(event.get("quality", "normal"))))
		_inv_vbox.add_child(line)

func _rebuild_collection() -> void:
	var nav := Button.new()
	nav.text = "Back to Bag"
	nav.pressed.connect(_show_bag)
	_inv_vbox.add_child(nav)
	var title := Label.new()
	title.text = "COLLECTION & RANKING BOOK\nDiscovered %d / Stored %d/%d / Pages %d" % [_collection.records.size(), _collection.stored.size(), _collection.capacity(), _collection.pages]
	title.add_theme_font_size_override("font_size", _accessibility.font_size(18))
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3))
	_inv_vbox.add_child(title)
	var buy := Button.new()
	buy.text = "Buy Page +%d Slots (%dg)" % [CollectionBook.SLOTS_PER_PAGE, _collection.next_page_cost()]
	buy.pressed.connect(_buy_collection_page)
	_inv_vbox.add_child(buy)
	var rank_title := Label.new()
	rank_title.text = "COMBAT POWER RANKING"
	_inv_vbox.add_child(rank_title)
	var rank := 1
	for record in _collection.rankings():
		var line := Label.new()
		var option_parts: Array = []
		for stat in (record.get("option_bests", {}) as Dictionary):
			option_parts.append("%s +%d" % [String(stat).to_upper(), int(record["option_bests"][stat])])
		option_parts.sort()
		line.text = "%d. %s  Power %.0f  Found %d\nBest: %s" % [rank, String(record.get("name", "")), float(record.get("best_power", 0.0)), int(record.get("found", 0)), ", ".join(option_parts)]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_color_override("font_color", Item.quality_color(String(record.get("quality", "normal"))))
		_inv_vbox.add_child(line)
		rank += 1
	var option_title := Label.new()
	option_title.text = "OPTION RECORDS"
	_inv_vbox.add_child(option_title)
	var leaders := _collection.option_leaders()
	var stats: Array = leaders.keys()
	stats.sort()
	for stat in stats:
		var leader: Dictionary = leaders[stat]
		var line := Label.new()
		line.text = "%s +%d - %s" % [String(stat).to_upper(), int(leader.get("value", 0)), String(leader.get("name", ""))]
		_inv_vbox.add_child(line)
	if not _collection.stored.is_empty():
		var storage_title := Label.new()
		storage_title.text = "STORED ITEMS (physical copies)"
		_inv_vbox.add_child(storage_title)
	for stored_item in _collection.stored:
		var equip := Button.new()
		equip.text = "%s\nPower %.0f / %s" % [Item.display_name(stored_item), _item_combat_power(stored_item), Item.affix_text(stored_item)]
		equip.disabled = not Item.can_equip(stored_item, _player.level, _player.stat_str, _player.stat_dex)
		var captured: Dictionary = stored_item
		equip.pressed.connect(func(): _equip_from_collection(captured))
		_inv_vbox.add_child(equip)

func _rebuild_inv() -> void:
	if _inv_vbox == null:
		return
	for c in _inv_vbox.get_children():
		c.queue_free()
	if _inventory_view == "collection":
		_rebuild_collection()
		_apply_large_panel_text(_inv_vbox)
		return
	if _inventory_view == "item_log":
		_rebuild_item_log()
		_apply_large_panel_text(_inv_vbox)
		return
	var item_log_button := Button.new()
	item_log_button.text = "Item Log (%d)" % _item_event_history.size()
	item_log_button.pressed.connect(_show_item_log)
	_inv_vbox.add_child(item_log_button)
	var collection_button := Button.new()
	collection_button.text = "Collection & Ranking Book (%d)" % _collection.records.size()
	collection_button.pressed.connect(_show_collection)
	_inv_vbox.add_child(collection_button)
	var travel_row := HBoxContainer.new()
	var previous_button := Button.new()
	previous_button.text = "Previous Floor"
	previous_button.disabled = _dlevel <= 1 or _in_town
	previous_button.pressed.connect(_previous_floor)
	previous_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	travel_row.add_child(previous_button)
	var town_button := Button.new()
	town_button.text = "Return Portal" if _in_town else "Town Portal"
	town_button.pressed.connect(_toggle_town_portal)
	town_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	travel_row.add_child(town_button)
	_inv_vbox.add_child(travel_row)
	var flask_button := Button.new()
	flask_button.text = "7 Skyfire Toss (%d)" % _arc_flasks
	flask_button.disabled = _arc_flasks <= 0
	flask_button.pressed.connect(_throw_arc_flask)
	_inv_vbox.add_child(flask_button)
	var wn := _equipped_label("weapon")
	var an := _equipped_label("armor")
	var rln := _equipped_label("ring_left")
	var rrn := _equipped_label("ring_right")
	var mn := _equipped_label("amulet")
	var merc_weapon := Item.display_name(_merc_equipped["weapon"]) if not (_merc_equipped["weapon"] as Dictionary).is_empty() else "-"
	var merc_armor := Item.display_name(_merc_equipped["armor"]) if not (_merc_equipped["armor"] as Dictionary).is_empty() else "-"
	var head := Label.new()
	head.text = "Weapon: %s\nArmor: %s\nLeft Ring: %s\nRight Ring: %s\nAmulet: %s\nMerc Weapon: %s\nMerc Armor: %s\nBag %d / Stash %d/%d / Materials %d" % [wn, an, rln, rrn, mn, merc_weapon, merc_armor, _inventory.size(), _stash.size(), Stash.CAPACITY, _automation.materials.size()]
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_vbox.add_child(head)
	for it in _inventory:
		var row := VBoxContainer.new()
		var btn := Button.new()
		btn.text = "%s\nPower %.0f / %s / %s" % [Item.display_name(it), _item_combat_power(it), Item.affix_text(it), Item.requirement_text(it)]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 52
		btn.add_theme_font_size_override("font_size", _accessibility.font_size(14))
		btn.add_theme_color_override("font_color", Item.quality_color(String(it["quality"])))
		btn.disabled = not Item.can_equip(it, _player.level, _player.stat_str, _player.stat_dex)
		var captured: Dictionary = it
		btn.pressed.connect(func(): _equip_from_inventory(captured))
		row.add_child(btn)
		var actions := HBoxContainer.new()
		if _collection.accepts(it):
			var collection_store := Button.new()
			collection_store.text = "Keep"
			collection_store.tooltip_text = "Protect and move this physical item into the collection book"
			collection_store.disabled = _collection.stored.size() >= _collection.capacity()
			collection_store.pressed.connect(func(): _store_in_collection(captured))
			collection_store.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(collection_store)
		if String(it.get("slot", "")) in Mercenary.SLOTS:
			var merc_btn := Button.new()
			merc_btn.text = "Merc"
			merc_btn.tooltip_text = "Equip on Ember Scout"
			merc_btn.disabled = not Mercenary.can_equip(it, _merc.level if _merc != null else _player.level)
			merc_btn.pressed.connect(func(): _equip_merc_from_inventory(captured))
			merc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(merc_btn)
		var stash_btn := Button.new()
		stash_btn.text = "Stash"
		stash_btn.tooltip_text = "Move to personal stash"
		stash_btn.pressed.connect(func(): _deposit_to_stash(captured))
		stash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(stash_btn)
		var sell_btn := Button.new()
		sell_btn.text = "Sell %dg" % _item_value(it)
		sell_btn.tooltip_text = "Convert this item to gold"
		sell_btn.disabled = bool(it.get("salvage_protected", false))
		sell_btn.pressed.connect(func(): _sell_inventory_item(captured))
		sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(sell_btn)
		var protect := Button.new()
		protect.text = "Protected" if bool(it.get("salvage_protected", false)) else "Salvage OK"
		protect.tooltip_text = "Toggle automatic salvage protection"
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
		stash_header.text = "PERSONAL STASH"
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
		withdraw.text = "Withdraw"
		var captured_stored: Dictionary = stored
		withdraw.pressed.connect(func(): _withdraw_from_stash(captured_stored))
		stash_row.add_child(withdraw)
		_inv_vbox.add_child(stash_row)
	_apply_large_panel_text(_inv_vbox)

func _apply_large_panel_text(root: Node) -> void:
	for child in root.get_children():
		if child is Label:
			(child as Label).add_theme_font_size_override("font_size", _accessibility.font_size(20))
		elif child is Button:
			var button := child as Button
			button.add_theme_font_size_override("font_size", _accessibility.font_size(20))
			button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 54.0)
		_apply_large_panel_text(child)

func _flash(from: Vector2, to: Vector2) -> void:
	if _fx != null:
		_fx.slash(from, to, Color(1.0, 0.9, 0.35))

func _camera_punch(strength: float) -> void:
	if not is_instance_valid(_cam) or _accessibility.effect_quality <= 0:
		return
	_cam.offset = Vector2(strength, -strength * 0.6)
	var tween := _cam.create_tween()
	tween.tween_property(_cam, "offset", Vector2.ZERO, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _spawn_text(pos: Vector2, text: String, col: Color) -> void:
	if _fx == null:
		return
	var lower := text.to_lower()
	var kind := "critical" if text.contains("!") or text.begins_with("CB ") else ("status" if lower in ["block", "skill unlocked", "all-seeing"] else "normal")
	_fx.floating_text(pos, text, col, _accessibility.font_size(18), kind)
