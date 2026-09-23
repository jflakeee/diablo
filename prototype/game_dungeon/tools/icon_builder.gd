extends SceneTree

const SOURCE := "res://assets/app_icon_source.png"
const OUTPUTS := {144: "res://assets/app_icon_144.png", 180: "res://assets/app_icon_180.png", 512: "res://assets/app_icon_512.png"}

func _init() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null or source.is_empty():
		push_error("icon source missing: " + SOURCE)
		quit(1)
		return
	for size in OUTPUTS:
		var image := source.duplicate()
		image.resize(int(size), int(size), Image.INTERPOLATE_LANCZOS)
		var error: Error = image.save_png(String(OUTPUTS[size]))
		if error != OK:
			push_error("icon save failed: " + String(OUTPUTS[size]))
			quit(1)
			return
	print("[ICON] source=%dx%d outputs=144/180/512 verdict=PASS" % [source.get_width(), source.get_height()])
	quit()
