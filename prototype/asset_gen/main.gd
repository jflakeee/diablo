extends Node2D
# 절차적 자산 생성기 갤러리 + 검증 (제작기 PoC)
# 실행: godot --path . --rendering-driver opengl3  (갤러리 표시)
# 검증: -- autoquit  (생성 + PNG 저장 + 결과 출력 후 종료)

const PixelGen := preload("res://pixel_gen.gd")
var _auto_quit := false

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
	samples.append([PixelGen.character(Color(0.7, 0.2, 0.15), 10), "Barbarian", 2.6])
	samples.append([PixelGen.character(Color(0.3, 0.3, 0.75), 11), "Sorceress", 2.6])
	samples.append([PixelGen.monster(Color(0.3, 0.55, 0.3), 20), "Fallen", 2.6])
	samples.append([PixelGen.monster(Color(0.6, 0.2, 0.5), 21), "Boss", 2.6])
	samples.append([PixelGen.icon("sword", 0), "sword", 2.6])
	samples.append([PixelGen.icon("potion", 0), "potion", 2.6])
	samples.append([PixelGen.icon("shield", 0), "shield", 2.6])
	samples.append([PixelGen.icon("coin", 0), "coin", 2.6])

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

	DirAccess.make_dir_recursive_absolute("user://assetgen")
	var saved := 0
	for i in samples.size():
		var tex: Texture2D = samples[i][0]
		var img := tex.get_image()
		if img.save_png("user://assetgen/%02d_%s.png" % [i, String(samples[i][1])]) == OK:
			saved += 1
	print("[AG] generated %d assets, saved %d PNG → user://assetgen" % [samples.size(), saved])
	print("[AG][RESULT] verdict=", ("PASS" if saved == samples.size() else "FAIL"))

func _process(_delta: float) -> void:
	if _auto_quit:
		get_tree().quit()
