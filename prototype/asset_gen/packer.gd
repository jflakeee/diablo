extends RefCounted
# Deterministic fixed-cell atlas packer. Jobs are sorted by key before packing.

static func pack(jobs: Array, output_path: String, cell_size: int = 64, columns: int = 8) -> Dictionary:
	var ordered := jobs.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary): return String(a["key"]) < String(b["key"]))
	var rows := ceili(float(ordered.size()) / float(columns))
	var atlas := Image.create_empty(columns * cell_size, rows * cell_size, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var regions := {}
	for i in ordered.size():
		var job: Dictionary = ordered[i]
		var source: Image = (job["texture"] as Texture2D).get_image()
		if source.get_width() > cell_size - 2 or source.get_height() > cell_size - 2:
			return {"ok": false, "error": "frame exceeds cell: " + String(job["key"])}
		var col := i % columns
		var row := i / columns
		var x := col * cell_size + (cell_size - source.get_width()) / 2
		var y := row * cell_size + (cell_size - source.get_height()) / 2
		atlas.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(x, y))
		regions[String(job["key"])] = [x, y, source.get_width(), source.get_height()]
	if atlas.save_png(output_path) != OK:
		return {"ok": false, "error": "failed to save atlas"}
	return {"ok": true, "regions": regions, "size": [atlas.get_width(), atlas.get_height()], "md5": FileAccess.get_md5(output_path)}
