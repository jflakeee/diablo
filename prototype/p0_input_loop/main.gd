extends Node2D
# P0 입력 + 고정 틱 게임루프 프로토타입

const JoystickScript := preload("res://virtual_joystick.gd")
const SkillButtonScript := preload("res://skill_button.gd")

# - 논리(이동/전투)는 _physics_process = 25Hz (원작 프레임 모델, Part 2 §1)
# - 렌더/HUD/카메라는 _process = 디스플레이 레이트
# - 가상 조이스틱 이동 + 스킬버튼(탭/홀드) + 아이소 좌표변환
# 실행: godot --path . --rendering-driver opengl3
# 검증: 위 명령에 "-- autoquit" 붙이면 6초 후 결과 출력 뒤 종료

const TILE_W := 64
const TILE_H := 32
const GRID := 16
const PLAYER_SPEED := 6.0  # grid units / sec

var _world: Node2D
var _cam: Camera2D
var _player: Sprite2D
var _enemies: Array[Sprite2D] = []
var _attack_line: Line2D
var _attack_ttl := 0.0

var _pgx := 8.0
var _pgy := 8.0

var _joy: JoystickScript
var _hud: Label
var _last_skill := "-"

var _logic_ticks := 0
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

func _ready() -> void:
	_auto_quit = OS.get_cmdline_user_args().has("autoquit")
	_run_start = Time.get_ticks_msec()

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	var tile := _tex_diamond(TILE_W, TILE_H, Color(0.22, 0.45, 0.28))
	for gx in GRID:
		for gy in GRID:
			var s := Sprite2D.new()
			s.texture = tile
			s.position = _iso(gx, gy)
			s.y_sort_enabled = false
			_world.add_child(s)

	var etex := _tex_rect(20, 30, Color(0.2, 0.35, 0.85))
	for p in [Vector2(3, 3), Vector2(12, 4), Vector2(5, 11), Vector2(13, 12), Vector2(9, 2), Vector2(2, 9)]:
		var e := Sprite2D.new()
		e.texture = etex
		e.position = _iso(p.x, p.y)
		e.set_meta("gx", p.x)
		e.set_meta("gy", p.y)
		_world.add_child(e)
		_enemies.append(e)

	_player = Sprite2D.new()
	_player.texture = _tex_rect(22, 34, Color(0.9, 0.75, 0.2))
	_player.position = _iso(_pgx, _pgy)
	_world.add_child(_player)

	_attack_line = Line2D.new()
	_attack_line.width = 3.0
	_attack_line.default_color = Color(1, 1, 0.4, 0.9)
	_world.add_child(_attack_line)

	_cam = Camera2D.new()
	_cam.position = _player.position
	_world.add_child(_cam)
	_cam.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)

	var vp := get_viewport_rect().size
	_joy = JoystickScript.new()
	_joy.position = Vector2(40, vp.y - 260)
	ui.add_child(_joy)

	var names := ["Bash", "Leap", "WW"]
	var cols := [Color.ORANGE_RED, Color.MEDIUM_PURPLE, Color.CYAN]
	for i in names.size():
		var b := SkillButtonScript.new()
		b.skill_name = names[i]
		b.color = cols[i]
		b.position = Vector2(vp.x - 130.0 - i * 110.0, vp.y - 130.0)
		b.tapped.connect(_on_skill_tap)
		b.charge_released.connect(_on_skill_charge)
		ui.add_child(b)

	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 20)
	ui.add_child(_hud)

	print("[P0B] ready — physics_ticks_per_second=", Engine.physics_ticks_per_second,
		" adapter=", RenderingServer.get_video_adapter_name())

func _physics_process(delta: float) -> void:
	# === 25Hz 논리 틱: 이동/전투 판정은 여기서 ===
	_logic_ticks += 1
	var dir := _screen_dir_to_grid(_joy.value if _joy else Vector2.ZERO)
	_pgx = clampf(_pgx + dir.x * PLAYER_SPEED * delta, 0.0, GRID - 1)
	_pgy = clampf(_pgy + dir.y * PLAYER_SPEED * delta, 0.0, GRID - 1)
	_player.position = _iso(_pgx, _pgy)

func _process(delta: float) -> void:
	# === 렌더 레이트: 카메라 추적/HUD/이펙트 페이드 ===
	if _cam:
		_cam.position = _cam.position.lerp(_player.position, clampf(delta * 8.0, 0.0, 1.0))
	if _attack_ttl > 0.0:
		_attack_ttl -= delta
		if _attack_ttl <= 0.0:
			_attack_line.clear_points()

	var elapsed := float(Time.get_ticks_msec() - _run_start) / 1000.0
	var rate := _logic_ticks / maxf(elapsed, 0.001)
	_hud.text = "render FPS: %d\nlogic tick: %d  (rate %.1f/s, target 25)\njoystick: (%.2f, %.2f)\nlast skill: %s\npos grid: (%.1f, %.1f)" % [
		Engine.get_frames_per_second(), _logic_ticks, rate,
		_joy.value.x, _joy.value.y, _last_skill, _pgx, _pgy]

	if _auto_quit and elapsed >= 6.0:
		var ok := absf(rate - 25.0) < 2.0
		print("[P0B][RESULT] logic_rate=%.2f/s (target 25)  ticks=%d  render_fps=%d" % [rate, _logic_ticks, Engine.get_frames_per_second()])
		print("[P0B][RESULT] verdict=", ("PASS" if ok else "CHECK_TICKRATE"))
		get_tree().quit()

func _nearest_enemy() -> Sprite2D:
	var best: Sprite2D = null
	var bestd := 1.0e9
	for e in _enemies:
		var d := Vector2(_pgx, _pgy).distance_to(Vector2(float(e.get_meta("gx")), float(e.get_meta("gy"))))
		if d < bestd:
			bestd = d
			best = e
	return best

func _flash_attack(target: Sprite2D) -> void:
	if target == null:
		return
	_attack_line.clear_points()
	_attack_line.add_point(_player.position)
	_attack_line.add_point(target.position)
	_attack_ttl = 0.18

func _on_skill_tap(skill_name: String) -> void:
	_last_skill = "%s (tap→autotarget)" % skill_name
	_flash_attack(_nearest_enemy())

func _on_skill_charge(skill_name: String, charge: float) -> void:
	_last_skill = "%s (charge %d%%)" % [skill_name, int(charge * 100.0)]
	_flash_attack(_nearest_enemy())
