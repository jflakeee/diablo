extends Node2D
# Phase 1 — 단일 맵 + 몬스터 + 기본 전투 (딥리서치 공식 연동)
# 논리(이동/AI/전투) = _physics_process 25Hz / 렌더·HUD = _process
# 실행: godot --path . --rendering-driver opengl3   (검증: 뒤에 "-- autoquit")

const JoystickScript := preload("res://virtual_joystick.gd")
const SkillButtonScript := preload("res://skill_button.gd")
const ActorScript := preload("res://actor.gd")
const CombatLib := preload("res://combat.gd")

const TILE_W := 64
const TILE_H := 32
const GRID := 20
const ATTACK_RANGE := 1.5
const PLAYER_ATTACK_CD := 0.5
const MONSTER_ATTACK_CD := 1.2

var _world: Node2D
var _cam: Camera2D
var _player: ActorScript
var _monsters: Array = []
var _blocked := {}          # Vector2i -> true
var _attack_line: Line2D
var _attack_ttl := 0.0

var _joy: JoystickScript
var _hud: Label
var _rng := RandomNumberGenerator.new()
var _combat_log := "-"

var _logic_ticks := 0
var _attacks := 0
var _hits := 0
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

	# 블록 타일(기둥) 몇 개
	for b in [Vector2i(7, 7), Vector2i(7, 8), Vector2i(12, 6), Vector2i(13, 13), Vector2i(6, 13)]:
		_blocked[b] = true

	# 아이소 바닥
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

	# 플레이어 (바바리안, L1)
	_player = _make_actor("Barbarian", Color(0.9, 0.75, 0.2), 22, 34)
	_player.is_player = true
	_player.level = 1
	_player.stat_str = 30
	_player.stat_dex = 20
	_player.stat_vit = 25
	_player.stat_energy = 10
	_player.max_life = CombatLib.barbarian_max_life(_player.stat_vit, _player.level)  # 55+100+2=157
	_player.life = _player.max_life
	_player.attack_rating = 150   # TODO: dex/level 기반 정식 산출은 P2 스펙
	_player.defense = 25
	_player.dmg_min = 3
	_player.dmg_max = 8
	_player.speed = 6.0
	_player.gx = 10.0
	_player.gy = 10.0
	_player.position = _iso(_player.gx, _player.gy)

	# 몬스터: Fallen 3 (약) + Zombie 2 (강, 명중 미스 유발) — 수치는 프로토타입 근사
	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.8, 3, 3)
	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.8, 16, 4)
	_spawn_monster("Fallen", Color(0.2, 0.35, 0.85), 20, 28, 2, 15, 55, 8, 1, 3, 3.8, 4, 15)
	_spawn_monster("Zombie", Color(0.45, 0.55, 0.25), 24, 32, 4, 40, 80, 40, 2, 5, 2.4, 15, 15)
	_spawn_monster("Zombie", Color(0.45, 0.55, 0.25), 24, 32, 4, 40, 80, 40, 2, 5, 2.4, 17, 10)

	_attack_line = Line2D.new()
	_attack_line.width = 3.0
	_attack_line.default_color = Color(1, 1, 0.4, 0.9)
	_world.add_child(_attack_line)

	_cam = Camera2D.new()
	_cam.position = _player.position
	_cam.zoom = Vector2(1.1, 1.1)
	_world.add_child(_cam)
	_cam.make_current()

	# UI
	var ui := CanvasLayer.new()
	add_child(ui)
	var vp := get_viewport_rect().size
	_joy = JoystickScript.new()
	_joy.position = Vector2(40, vp.y - 260)
	ui.add_child(_joy)

	var b := SkillButtonScript.new()
	b.skill_name = "Attack"
	b.color = Color.ORANGE_RED
	b.position = Vector2(vp.x - 130, vp.y - 130)
	b.tapped.connect(_on_attack_pressed)
	b.charge_released.connect(func(_n, _c): _on_attack_pressed(_n))
	ui.add_child(b)

	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 18)
	ui.add_child(_hud)

	print("[P1] ready — physics=", Engine.physics_ticks_per_second, "Hz  player_life=", _player.max_life)

func _spawn_monster(nm: String, col: Color, w: int, h: int, lvl: int, hp: int, ar: int, df: int, dmin: int, dmax: int, spd: float, gx: int, gy: int) -> void:
	var m := _make_actor(nm, col, w, h)
	m.level = lvl
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

	# 플레이어 이동(조이스틱 + 충돌)
	var dir := _screen_dir_to_grid(_joy.value if _joy else Vector2.ZERO)
	if dir != Vector2.ZERO:
		var nx := _player.gx + dir.x * _player.speed * delta
		var ny := _player.gy + dir.y * _player.speed * delta
		if _walkable(nx, _player.gy):
			_player.gx = nx
		if _walkable(_player.gx, ny):
			_player.gy = ny
		_player.position = _iso(_player.gx, _player.gy)
	_player.attack_cd = maxf(0.0, _player.attack_cd - delta)

	# 몬스터 AI: 추격 → 사거리 내 공격
	for m in _monsters:
		if not m.alive:
			continue
		m.attack_cd = maxf(0.0, m.attack_cd - delta)
		var to := Vector2(_player.gx - m.gx, _player.gy - m.gy)
		var dist := to.length()
		if dist > ATTACK_RANGE:
			var step: Vector2 = to.normalized() * m.speed * delta
			if _walkable(m.gx + step.x, m.gy):
				m.gx += step.x
			if _walkable(m.gx, m.gy + step.y):
				m.gy += step.y
			m.position = _iso(m.gx, m.gy)
		elif m.attack_cd <= 0.0:
			_resolve_attack(m, _player)
			m.attack_cd = MONSTER_ATTACK_CD

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
	var elapsed := float(Time.get_ticks_msec() - _run_start) / 1000.0
	_hud.text = "%s  Lv%d   Life %d/%d\nmonsters alive: %d\nattacks: %d  hits: %d\nlog: %s\n(조이스틱 이동 · Attack 버튼 탭)" % [
		_player.actor_name, _player.level, _player.life, _player.max_life,
		alive_cnt, _attacks, _hits, _combat_log]

	if _auto_quit and elapsed >= 8.0:
		print("[P1][RESULT] ticks=%d attacks=%d hits=%d player_life=%d/%d monsters_alive=%d" % [
			_logic_ticks, _attacks, _hits, _player.life, _player.max_life, alive_cnt])
		print("[P1][RESULT] verdict=", ("PASS" if _attacks > 0 else "NO_COMBAT"))
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

func _on_attack_pressed(_skill_name: String) -> void:
	if not _player.alive or _player.attack_cd > 0.0:
		return
	var target := _nearest_monster()
	if target == null:
		_combat_log = "no target"
		return
	if Vector2(_player.gx, _player.gy).distance_to(Vector2(target.gx, target.gy)) > ATTACK_RANGE + 0.6:
		_combat_log = "out of range"
		return
	_player.attack_cd = PLAYER_ATTACK_CD
	_resolve_attack(_player, target)
	_attack_line.clear_points()
	_attack_line.add_point(_player.position)
	_attack_line.add_point(target.position)
	_attack_ttl = 0.18

func _resolve_attack(attacker: ActorScript, defender: ActorScript) -> void:
	if not defender.alive:
		return
	_attacks += 1
	var chance := CombatLib.chance_to_hit(attacker.attack_rating, defender.defense, attacker.level, defender.level)
	var hit := CombatLib.roll_hit(_rng, attacker.attack_rating, defender.defense, attacker.level, defender.level)
	if hit:
		_hits += 1
		var dmg := CombatLib.physical_damage(_rng, attacker.dmg_min, attacker.dmg_max, 0.0)
		defender.take_damage(dmg)
		_spawn_text(defender.position, str(dmg), Color(1, 0.9, 0.3))
		_combat_log = "%s→%s HIT %d (hit%%=%.0f)" % [attacker.actor_name, defender.actor_name, dmg, chance]
	else:
		_spawn_text(defender.position, "miss", Color(0.85, 0.85, 0.85))
		_combat_log = "%s→%s MISS (hit%%=%.0f)" % [attacker.actor_name, defender.actor_name, chance]

func _spawn_text(pos: Vector2, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-8, -44)
	lbl.z_index = 100
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 18)
	_world.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -28), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.finished.connect(lbl.queue_free)

func _on_monster_died(m: Node) -> void:
	_combat_log = "%s died" % m.actor_name

func _on_player_note() -> void:
	pass
