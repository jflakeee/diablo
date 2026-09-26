extends RefCounted

const PATH := "user://accessibility.cfg"
const UI_SCALES := [0.8, 1.0, 1.2, 1.4]
const TEXT_SCALES := [1.0, 1.25]

var ui_scale := 1.0
var text_scale := 1.0

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	ui_scale = float(config.get_value("ui", "scale", 1.0))
	text_scale = float(config.get_value("ui", "text_scale", 1.0))
	if not UI_SCALES.has(ui_scale): ui_scale = 1.0
	if not TEXT_SCALES.has(text_scale): text_scale = 1.0

func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("ui", "scale", ui_scale)
	config.set_value("ui", "text_scale", text_scale)
	return config.save(PATH) == OK

func cycle_ui_scale() -> void:
	ui_scale = UI_SCALES[(UI_SCALES.find(ui_scale) + 1) % UI_SCALES.size()]
	save_settings()

func cycle_text_scale() -> void:
	text_scale = TEXT_SCALES[(TEXT_SCALES.find(text_scale) + 1) % TEXT_SCALES.size()]
	save_settings()

func font_size(base: int) -> int:
	# Browser text smaller than 16 logical pixels becomes difficult to read once
	# the game canvas is fitted into a narrow mobile viewport.
	return maxi(16, roundi(float(base) * text_scale))

static func selftest() -> bool:
	var access := new()
	return UI_SCALES == [0.8, 1.0, 1.2, 1.4] and TEXT_SCALES == [1.0, 1.25] and access.font_size(10) == 16
