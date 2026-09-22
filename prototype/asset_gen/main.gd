extends Node2D
# 절차적 자산 생성기 갤러리 + 검증 (제작기 PoC)
# 실행: godot --path . --rendering-driver opengl3  (갤러리 표시)
# 검증: -- autoquit  (생성 + PNG 저장 + 결과 출력 후 종료)

const PixelGen := preload("res://pixel_gen.gd")
const Quality := preload("res://quality.gd")
const OUTPUT := "user://assetgen"
const ATLAS_CELL := 64
const ATLAS_COLS := 4
var _auto_quit := false

func _build_atlas(samples: Array) -> bool:
	var rows := ceili(float(samples.size()) / float(ATLAS_COLS))
	var atlas := Image.create_empty(ATLAS_COLS * ATLAS_CELL, rows * ATLAS_CELL, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var entries := {}
	for i in samples.size():
		var source: Image = (samples[i][0] as Texture2D).get_image()
		var col := i % ATLAS_COLS
		var row := i / ATLAS_COLS
		var px := col * ATLAS_CELL + (ATLAS_CELL - source.get_width()) / 2
		var py := row * ATLAS_CELL + (ATLAS_CELL - source.get_height()) / 2
		atlas.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(px, py))
		var id := String(samples[i][1]).to_lower().replace(" ", "_")
		entries[id] = {"region": [px, py, source.get_width(), source.get_height()], "cell": [col, row]}
	var atlas_path := OUTPUT + "/atlas.png"
	if atlas.save_png(atlas_path) != OK:
		return false
	var manifest := {
		"generator_version": PixelGen.VERSION,
		"atlas": "atlas.png",
		"atlas_size": [atlas.get_width(), atlas.get_height()],
		"cell_size": ATLAS_CELL,
		"atlas_md5": FileAccess.get_md5(atlas_path),
		"entries": entries,
	}
	var file := FileAccess.open(OUTPUT + "/manifest.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(manifest, "  "))
	return entries.size() == samples.size() and String(manifest["atlas_md5"]) != ""

func _build_sprite_frames() -> bool:
	var frames := SpriteFrames.new()
	frames.clear_all()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var defs := [
		["barbarian", Color(0.7, 0.2, 0.15), 10],
		["sorceress", Color(0.3, 0.3, 0.75), 11],
		["rogue", Color(0.5, 0.15, 0.2), 7],
	]
	var dirs := ["s", "e", "n", "w"]
	for def in defs:
		for direction in 4:
			var anim := "%s_walk_%s" % [String(def[0]), dirs[direction]]
			frames.add_animation(anim)
			frames.set_animation_speed(anim, 8.0)
			frames.set_animation_loop(anim, true)
			for fi in [1, 0, 2, 0]:
				frames.add_frame(anim, PixelGen.hero(String(def[0]), def[1], int(def[2]), direction, fi))
	return ResourceSaver.save(frames, OUTPUT + "/heroes.tres") == OK and frames.get_animation_names().size() == 12

func _source_sync_ok() -> bool:
	var here := ProjectSettings.globalize_path("res://pixel_gen.gd")
	var canonical := here.get_base_dir().get_base_dir().path_join("game_dungeon/pixel_gen.gd")
	return FileAccess.file_exists(canonical) and FileAccess.get_md5(here) == FileAccess.get_md5(canonical)

func _ready() -> void:
	_auto_quit = OS.get_cmdline_user_args().has("autoquit")
	RenderingServer.set_default_clear_color(Color(0.1, 0.09, 0.12))
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	cam.position = Vector2(340, 260)

	var samples: Array = []
	samples.append([PixelGen.iso_tile(64, 32, Color(0.28, 0.5, 0.3), 1, false), "grass", 2.2])
	samples.append([PixelGen.iso_tile(64, 32, Color(0.4, 0.38, 0.36), 2, true), "stone", 2.2])
	samples.append([PixelGen.iso_tile(64, 32, Color(0.45, 0.33, 0.2), 3, true), "dirt", 2.2])
	samples.append([PixelGen.iso_tile(64, 32, Color(0.5, 0.12, 0.5), 4, true), "hell", 2.2])
	samples.append([PixelGen.hero("barbarian", Color(0.7, 0.2, 0.15), 10), "Barbarian", 2.6])
	samples.append([PixelGen.hero("sorceress", Color(0.3, 0.3, 0.75), 11), "Sorceress", 2.6])
	samples.append([PixelGen.monster_named("Fallen", Color(0.75, 0.35, 0.25), 20), "Fallen", 2.6])
	samples.append([PixelGen.monster_named("Andariel", Color(0.7, 0.15, 0.5), 21), "Andariel", 2.6])
	samples.append([PixelGen.icon("sword", 0), "sword", 2.6])
	samples.append([PixelGen.icon("potion", 0), "potion", 2.6])
	samples.append([PixelGen.icon("shield", 0), "shield", 2.6])
	samples.append([PixelGen.icon("coin", 0), "coin", 2.6])
	samples.append([PixelGen.icon("gem", 0), "ruby", 2.6])
	samples.append([PixelGen.icon("gem", 1), "sapphire", 2.6])
	samples.append([PixelGen.icon("rune", 2), "rune", 2.6])
	samples.append([PixelGen.hero("rogue", Color(0.5, 0.15, 0.2), 7), "Rogue", 2.6])
	samples.append([PixelGen.monster_named("Skeleton", Color(0.85, 0.85, 0.8), 4), "Skeleton", 2.6])
	samples.append([PixelGen.monster_named("Blood Hawk", Color(0.8, 0.25, 0.25), 5), "Blood Hawk", 2.6])

	var cols := 4
	var cell := 165
	for i in samples.size():
		var row := i / cols
		var colx := i % cols
		var s: Array = samples[i]
		var spr := Sprite2D.new()
		spr.texture = s[0]
		spr.scale = Vector2(float(s[2]), float(s[2]))
		spr.position = Vector2(90 + colx * cell, 80 + row * cell)
		add_child(spr)
		var lbl := Label.new()
		lbl.text = String(s[1])
		lbl.position = spr.position + Vector2(-44, 46)
		add_child(lbl)

	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var saved := 0
	for i in samples.size():
		var tex: Texture2D = samples[i][0]
		var img := tex.get_image()
		if img.save_png(OUTPUT + "/%02d_%s.png" % [i, String(samples[i][1])]) == OK:
			saved += 1
	print("[AG] generated %d assets, saved %d PNG → user://assetgen" % [samples.size(), saved])
	var cache_before := PixelGen.cache_size()
	var cached_a := PixelGen.icon("gem", 0)
	var cached_b := PixelGen.icon("gem", 0)
	var cache_ok := cached_a == cached_b and PixelGen.cache_size() == cache_before
	var atlas_ok := _build_atlas(samples)
	var frames_ok := _build_sprite_frames()
	var sync_ok := _source_sync_ok()
	var quality: Dictionary = Quality.suite(PixelGen, samples)
	print("[AG] cache entries=%d reuse=%s" % [cache_before, str(cache_ok)])
	print("[AG] atlas=%s spriteframes=%s source_sync=%s" % [str(atlas_ok), str(frames_ok), str(sync_ok)])
	print("[AG] quality checked=%d silhouette_diff=%d walk_diff=%d seed_diff=%d failures=%s" % [int(quality["checked"]), int(quality["silhouette_diff"]), int(quality["walk_diff"]), int(quality["seed_diff"]), str(quality["failures"])])
	print("[AG][RESULT] verdict=", ("PASS" if saved == samples.size() and cache_ok and atlas_ok and frames_ok and sync_ok and bool(quality["ok"]) else "FAIL"))

func _process(_delta: float) -> void:
	if _auto_quit:
		get_tree().quit()
