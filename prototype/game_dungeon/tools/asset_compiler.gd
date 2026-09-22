extends Node2D
# 절차적 자산 생성기 갤러리 + 검증 (제작기 PoC)
# 실행: godot --path prototype/game_dungeon res://tools/asset_compiler.tscn
# 검증: 위 명령 뒤에 -- autoquit publish 추가

const PixelGen := preload("res://art/pixel_gen.gd")
const Quality := preload("res://tools/asset_quality.gd")
const Packer := preload("res://tools/atlas_packer.gd")
const OUTPUT := "user://assetgen"
const ATLAS_CELL := 64
const ATLAS_COLS := 4
const RECIPE_PATH := "res://art/art_recipes.json"
var _auto_quit := false

func _publish_to_game() -> bool:
	var target := ProjectSettings.globalize_path("res://generated")
	if DirAccess.make_dir_recursive_absolute(target) != OK:
		return false
	for filename in ["atlas.png", "manifest.json", "animation_atlas.png", "animation_manifest.json"]:
		var source := ProjectSettings.globalize_path(OUTPUT + "/" + filename)
		if DirAccess.copy_absolute(source, target.path_join(filename)) != OK:
			return false
	# 새 아틀라스 게시가 성공한 뒤에만 구형 내장 텍스처 리소스를 제거한다.
	for legacy in ["heroes.tres", "monsters.tres"]:
		var legacy_path := target.path_join(legacy)
		if FileAccess.file_exists(legacy_path):
			DirAccess.remove_absolute(legacy_path)
	return true

func _load_samples() -> Array:
	var file := FileAccess.open(RECIPE_PATH, FileAccess.READ)
	if file == null:
		push_error("Asset recipe missing: " + RECIPE_PATH)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("assets"):
		push_error("Invalid asset recipe JSON")
		return []
	var samples: Array = []
	var ids := {}
	for raw in parsed["assets"]:
		var recipe: Dictionary = raw
		var id := String(recipe.get("id", ""))
		var asset_type := String(recipe.get("type", ""))
		if id.is_empty() or ids.has(id.to_lower()):
			push_error("Empty or duplicate asset id: " + id)
			return []
		ids[id.to_lower()] = true
		var seed := int(recipe.get("seed", 0))
		var texture: Texture2D
		match asset_type:
			"tile":
				var color := Color.from_string(String(recipe.get("color", "#808080")), Color.GRAY)
				texture = PixelGen.iso_tile(64, 32, color, seed, bool(recipe.get("speckle", false)))
			"hero":
				var color := Color.from_string(String(recipe.get("color", "#808080")), Color.GRAY)
				texture = PixelGen.hero(String(recipe.get("kind", "rogue")), color, seed)
			"monster":
				var color := Color.from_string(String(recipe.get("color", "#808080")), Color.GRAY)
				texture = PixelGen.monster_named(String(recipe.get("kind", id)), color, seed)
			"icon":
				texture = PixelGen.icon(String(recipe.get("kind", "material")), seed)
			_:
				push_error("Unknown asset recipe type: " + asset_type)
				return []
		samples.append([texture, id, float(recipe.get("scale", 2.0)), recipe])
	return samples

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
		"recipe_md5": FileAccess.get_md5(RECIPE_PATH),
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

func _build_animation_atlas(samples: Array) -> bool:
	var jobs: Array = []
	var actors := {}
	var defs := [
		["barbarian", Color(0.7, 0.2, 0.15), 10],
		["sorceress", Color(0.3, 0.3, 0.75), 11],
		["rogue", Color(0.5, 0.15, 0.2), 7],
	]
	var dirs := ["s", "e", "n", "w"]
	for def in defs:
		var actor_id := String(def[0])
		actors[actor_id] = {"animations": {}}
		for direction in 4:
			var anim: String = "walk_" + String(dirs[direction])
			var keys: Array = []
			for fi in 3:
				var key := "hero/%s/%s/%d" % [actor_id, anim, fi]
				jobs.append({"key": key, "texture": PixelGen.hero(actor_id, def[1], int(def[2]), direction, fi)})
				keys.append(key)
			actors[actor_id]["animations"][anim] = {"fps": 8.0, "loop": true, "frame_keys": [keys[1], keys[0], keys[2], keys[0]]}
	for sample in samples:
		var recipe: Dictionary = sample[3]
		if String(recipe.get("type", "")) != "monster":
			continue
		var id := String(recipe["id"]).to_lower().replace(" ", "_")
		var kind := String(recipe.get("kind", recipe["id"]))
		var color := Color.from_string(String(recipe.get("color", "#808080")), Color.GRAY)
		var seed := int(recipe.get("seed", 0))
		var keys: Array = []
		for fi in 3:
			var key := "monster/%s/walk/%d" % [id, fi]
			jobs.append({"key": key, "texture": PixelGen.monster_named(kind, color, seed, fi)})
			keys.append(key)
		actors[id] = {"animations": {"walk": {"fps": 8.0, "loop": true, "frame_keys": [keys[1], keys[0], keys[2], keys[0]]}}}
	var packed: Dictionary = Packer.pack(jobs, OUTPUT + "/animation_atlas.png")
	if not bool(packed.get("ok", false)):
		push_error(String(packed.get("error", "animation pack failed")))
		return false
	for actor_id in actors:
		for anim_id in actors[actor_id]["animations"]:
			var anim: Dictionary = actors[actor_id]["animations"][anim_id]
			var frames: Array = []
			for key in anim["frame_keys"]:
				frames.append({"region": packed["regions"][key], "duration": 1.0})
			anim.erase("frame_keys")
			anim["frames"] = frames
	var manifest := {"format_version": 2, "generator_version": PixelGen.VERSION,
		"atlas": "animation_atlas.png", "atlas_size": packed["size"], "atlas_md5": packed["md5"], "actors": actors}
	var file := FileAccess.open(OUTPUT + "/animation_manifest.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(manifest, "  "))
	return jobs.size() > 0 and String(packed["md5"]) != ""

func _ready() -> void:
	_auto_quit = OS.get_cmdline_user_args().has("autoquit")
	RenderingServer.set_default_clear_color(Color(0.1, 0.09, 0.12))
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	cam.position = Vector2(340, 260)

	var samples := _load_samples()
	if samples.is_empty():
		print("[AG][RESULT] verdict=FAIL (recipes)")
		return

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
	var animations_ok := _build_animation_atlas(samples)
	var quality: Dictionary = Quality.suite(PixelGen, samples)
	var publish_ok := true
	if OS.get_cmdline_user_args().has("publish"):
		publish_ok = _publish_to_game()
	print("[AG] cache entries=%d reuse=%s" % [cache_before, str(cache_ok)])
	print("[AG] atlas=%s animation_atlas=%s canonical_source=true" % [str(atlas_ok), str(animations_ok)])
	print("[AG] quality checked=%d silhouette_diff=%d walk_diff=%d seed_diff=%d failures=%s" % [int(quality["checked"]), int(quality["silhouette_diff"]), int(quality["walk_diff"]), int(quality["seed_diff"]), str(quality["failures"])])
	if OS.get_cmdline_user_args().has("publish"):
		print("[AG] publish_to_game=", publish_ok)
	print("[AG][RESULT] verdict=", ("PASS" if saved == samples.size() and cache_ok and atlas_ok and animations_ok and bool(quality["ok"]) and publish_ok else "FAIL"))

func _process(_delta: float) -> void:
	if _auto_quit:
		get_tree().quit()
