extends Node2D
# 랜덤 던전 생성 시각화 + 검증 (P1 심화)
# 생성 → 아이소 렌더 → AStarGrid2D 입구→출구 경로 → 연결성 자체검증.
# 실행: godot --path . --rendering-driver opengl3 [-- seed=123]  (R키: 재생성)
# 검증: -- autoquit

const LevelGen := preload("res://level_gen.gd")
const TILE_W := 24
const TILE_H := 12

var _world: Node2D
var _cam: Camera2D
var _hud: Label
var _auto_quit := false
var _seed := 20260920
var _elapsed := 0.0

func _iso(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * TILE_W * 0.5, (gx + gy) * TILE_H * 0.5)

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
	var uargs := OS.get_cmdline_user_args()
	_auto_quit = uargs.has("autoquit")
	for a in uargs:
		if String(a).begins_with("seed="):
			_seed = int(String(a).substr(5))
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 18)
	cl.add_child(_hud)

	_selftest()
	_build_and_render(_seed)

func _selftest() -> void:
	var all_ok := true
	for s in [111, 222, 333]:
		var lvl := LevelGen.generate(s)
		var res := _verify(lvl)
		print("[LG] seed=%d rooms=%d doors=%d floor=%d reachable=%d path_len=%d connected=%s" % [
			s, int(lvl["rooms"]), int(lvl["doors"]), int(res["floor"]), int(res["reachable"]), int(res["path"]), str(res["connected"])])
		if not bool(res["connected"]) or int(res["path"]) <= 0:
			all_ok = false
	print("[LG][RESULT] gen_selftest verdict=", ("PASS" if all_ok else "FAIL"))

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

func _verify(lvl: Dictionary) -> Dictionary:
	var w := int(lvl["w"])
	var h := int(lvl["h"])
	var grid: Array = lvl["grid"]
	var ent: Vector2i = lvl["entrance"]
	var ex: Vector2i = lvl["exit"]
	var floor_cnt := 0
	for y in h:
		for x in w:
			if int(grid[y][x]) == 1:
				floor_cnt += 1
	# 입구에서 flood fill → 도달 가능한 바닥 수
	var seen := {}
	var q: Array = [ent]
	seen[ent] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h and not seen.has(n) and int(grid[n.y][n.x]) == 1:
				seen[n] = true
				q.append(n)
	var astar := _build_astar(w, h, grid)
	var path := astar.get_id_path(ent, ex)
	return {"floor": floor_cnt, "reachable": seen.size(), "path": path.size(), "connected": seen.size() == floor_cnt}

func _marker(cell: Vector2i, col: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _tex_diamond(TILE_W, TILE_H, col)
	s.position = _iso(cell.x, cell.y)
	s.z_index = 5
	s.scale = Vector2(1.3, 1.3)
	_world.add_child(s)

func _build_and_render(seed_val: int) -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	_world = Node2D.new()
	add_child(_world)

	var lvl := LevelGen.generate(seed_val)
	var w := int(lvl["w"])
	var h := int(lvl["h"])
	var grid: Array = lvl["grid"]
	var floor_tex := _tex_diamond(TILE_W, TILE_H, Color(0.22, 0.42, 0.28))
	var wall_tex := _tex_diamond(TILE_W, TILE_H, Color(0.30, 0.28, 0.26))
	for y in h:
		for x in w:
			var s := Sprite2D.new()
			s.texture = floor_tex if int(grid[y][x]) == 1 else wall_tex
			s.position = _iso(x, y)
			_world.add_child(s)

	var ent: Vector2i = lvl["entrance"]
	var ex: Vector2i = lvl["exit"]
	_marker(ent, Color(0.3, 0.9, 0.4))
	_marker(ex, Color(0.9, 0.3, 0.3))

	var astar := _build_astar(w, h, grid)
	var path := astar.get_id_path(ent, ex)
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(1, 1, 0.3, 0.85)
	line.z_index = 10
	for p in path:
		line.add_point(_iso(p.x, p.y))
	_world.add_child(line)

	if not is_instance_valid(_cam):
		_cam = Camera2D.new()
		add_child(_cam)
		_cam.make_current()
	_cam.position = _iso(w * 0.5, h * 0.5)
	_cam.zoom = Vector2(0.8, 0.8)

	var res := _verify(lvl)
	_hud.text = "Random Dungeon  seed=%d\nrooms=%d doors=%d floor=%d\npath(entrance→exit)=%d  connected=%s\n(R: 재생성)" % [
		seed_val, int(lvl["rooms"]), int(lvl["doors"]), int(res["floor"]), int(res["path"]), str(res["connected"])]
	print("[LG] rendered seed=%d path=%d connected=%s" % [seed_val, int(res["path"]), str(res["connected"])])

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_R:
		_seed += 1
		_build_and_render(_seed)

func _process(delta: float) -> void:
	_elapsed += delta
	if _auto_quit and _elapsed > 4.0:
		print("[LG][RESULT] render OK (seed=%d)" % _seed)
		get_tree().quit()
