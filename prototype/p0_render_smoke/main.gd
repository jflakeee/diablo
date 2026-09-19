extends Node2D
# P0 렌더 스모크/벤치마크 — HD 4000 + OpenGL3에서 아이소 + y-sort 60fps 검증
# 자동 실행 후 평균/최소 FPS를 stdout에 출력하고 종료한다(비대화식 측정).

const TILE_W := 64
const TILE_H := 32
const GRID := 24            # 24x24 = 576 아이소 바닥 타일
const ACTORS := 250         # y-sort 되는 이동 스프라이트
const WARMUP_SECONDS := 1.0 # 워밍업(측정 제외)
const BENCH_SECONDS := 6.0  # 측정 구간
const HARD_CAP_SECONDS := 20.0  # 안전장치: 무슨 일이 있어도 이 시간 지나면 종료

var _tile_tex: Texture2D
var _actor_tex: Texture2D
var _actors: Array = []
var _fps_label: Label
var _origin: Vector2
var _elapsed := 0.0
var _warmed := false
var _last_report_sec := 0
var _fps_min := 1.0e9
var _fps_sum := 0.0
var _fps_samples := 0
var _start_msec := 0

func _make_diamond(w: int, h: int, col: Color) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx := absf(x - w / 2.0) / (w / 2.0)
			var dy := absf(y - h / 2.0) / (h / 2.0)
			if dx + dy <= 1.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _make_rect(w: int, h: int, col: Color) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)

func _iso(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * TILE_W * 0.5, (gx + gy) * TILE_H * 0.5)

func _ready() -> void:
	# 원시 처리량 측정을 위해 vsync/fps 상한 해제
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	y_sort_enabled = true  # 자식 전체를 매 프레임 y-정렬 (핵심 스트레스)

	_tile_tex = _make_diamond(TILE_W, TILE_H, Color(0.24, 0.5, 0.3))
	_actor_tex = _make_rect(18, 28, Color(0.85, 0.25, 0.2))
	_origin = Vector2(get_viewport_rect().size.x * 0.5, 100.0)

	for gx in GRID:
		for gy in GRID:
			var s := Sprite2D.new()
			s.texture = _tile_tex
			s.position = _origin + _iso(gx, gy)
			add_child(s)

	for i in ACTORS:
		var a := Sprite2D.new()
		a.texture = _actor_tex
		var gx := randf() * GRID
		var gy := randf() * GRID
		a.position = _origin + _iso(gx, gy)
		add_child(a)
		_actors.append({
			"node": a, "gx": gx, "gy": gy,
			"vx": randf_range(-4.0, 4.0), "vy": randf_range(-4.0, 4.0),
		})

	var cl := CanvasLayer.new()
	add_child(cl)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 10)
	_fps_label.add_theme_font_size_override("font_size", 22)
	cl.add_child(_fps_label)

	_start_msec = Time.get_ticks_msec()
	print("[P0] Godot ", Engine.get_version_info()["string"],
		" | adapter=", RenderingServer.get_video_adapter_name(),
		" | tiles=", GRID * GRID, " actors=", ACTORS)

func _finish() -> void:
	var avg := _fps_sum / float(max(_fps_samples, 1))
	print("[P0][RESULT] adapter=", RenderingServer.get_video_adapter_name())
	print("[P0][RESULT] avg_fps=%.1f  min_fps=%.1f  samples=%d" % [avg, _fps_min, _fps_samples])
	print("[P0][RESULT] verdict=", ("PASS(>=60)" if avg >= 60.0 else "BELOW_60"))
	get_tree().quit()

func _process(delta: float) -> void:
	for i in range(_actors.size()):
		var d: Dictionary = _actors[i]
		d["gx"] += d["vx"] * delta
		d["gy"] += d["vy"] * delta
		if d["gx"] < 0.0 or d["gx"] > GRID:
			d["vx"] = -d["vx"]
			d["gx"] = clampf(d["gx"], 0.0, GRID)
		if d["gy"] < 0.0 or d["gy"] > GRID:
			d["vy"] = -d["vy"]
			d["gy"] = clampf(d["gy"], 0.0, GRID)
		(d["node"] as Sprite2D).position = _origin + _iso(d["gx"], d["gy"])

	var fps := Engine.get_frames_per_second()
	_fps_label.text = "FPS: %d\nactors: %d  tiles: %d" % [fps, ACTORS, GRID * GRID]

	_elapsed += delta

	# 벽시계 안전장치: 예상치 못한 상황에서도 반드시 종료
	if (Time.get_ticks_msec() - _start_msec) / 1000.0 > HARD_CAP_SECONDS:
		print("[P0] hard cap reached — finishing")
		_finish()
		return

	if _elapsed < WARMUP_SECONDS:
		return
	if not _warmed:
		_warmed = true
		print("[P0] warmup done — measuring ", BENCH_SECONDS, "s ...")

	if fps > 0:
		_fps_sum += fps
		_fps_min = minf(_fps_min, fps)
		_fps_samples += 1

	# 매초 진행상황 출력 (버퍼링 대비 중간 데이터 확보)
	var sec := int(_elapsed)
	if sec != _last_report_sec:
		_last_report_sec = sec
		print("[P0] t=%ds  fps=%d" % [sec, fps])

	if _elapsed >= WARMUP_SECONDS + BENCH_SECONDS:
		_finish()
