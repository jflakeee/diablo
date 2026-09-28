extends Node2D
## Lightweight, code-generated combat feedback for the Compatibility renderer.
## Gameplay owns damage and timing; this node only visualizes confirmed events.

const MAX_ACTIVE := 72
var _active: Array[Node] = []

func _track(node: Node) -> bool:
	for index in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[index]):
			_active.remove_at(index)
	if _active.size() >= MAX_ACTIVE:
		return false
	_active.append(node)
	add_child(node)
	return true

func _ring(pos: Vector2, color: Color, radius: float, duration: float = 0.28, width: float = 3.0) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.closed = true
	line.position = pos
	for index in 16:
		var angle := TAU * float(index) / 16.0
		line.add_point(Vector2(cos(angle), sin(angle)) * radius)
	line.scale = Vector2(0.25, 0.25)
	line.z_index = 72
	if not _track(line):
		line.free()
		return
	var tween := line.create_tween().set_parallel(true)
	tween.tween_property(line, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "modulate:a", 0.0, duration)
	tween.finished.connect(line.queue_free)

func cast_burst(pos: Vector2, color: Color) -> void:
	_ring(pos, color, 22.0, 0.22, 2.5)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(0, -12), Vector2(7, 0), Vector2(0, 12), Vector2(-7, 0)])
	glow.color = color
	glow.position = pos + Vector2(0, -10)
	glow.z_index = 73
	if not _track(glow):
		glow.free()
		return
	var tween := glow.create_tween().set_parallel(true)
	tween.tween_property(glow, "rotation", PI, 0.22)
	tween.tween_property(glow, "scale", Vector2(1.8, 1.8), 0.22)
	tween.tween_property(glow, "modulate:a", 0.0, 0.22)
	tween.finished.connect(glow.queue_free)

func impact(pos: Vector2, color: Color, heavy: bool = false) -> void:
	_ring(pos, color, 34.0 if heavy else 24.0, 0.32 if heavy else 0.24, 4.0 if heavy else 2.5)
	var shard_count := 9 if heavy else 5
	for index in shard_count:
		var angle := TAU * float(index) / float(shard_count) + 0.27
		var shard := Line2D.new()
		shard.width = 3.0 if heavy else 2.0
		shard.default_color = color
		shard.position = pos
		shard.add_point(Vector2.ZERO)
		shard.add_point(Vector2(cos(angle), sin(angle)) * (18.0 if heavy else 12.0))
		shard.z_index = 73
		if not _track(shard):
			shard.free()
			continue
		var offset := Vector2(cos(angle), sin(angle)) * (26.0 if heavy else 17.0)
		var tween := shard.create_tween().set_parallel(true)
		tween.tween_property(shard, "position", pos + offset, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "modulate:a", 0.0, 0.22)
		tween.finished.connect(shard.queue_free)

func slash(from_pos: Vector2, to_pos: Vector2, color: Color, heavy: bool = false) -> void:
	var delta := to_pos - from_pos
	if delta.length() < 1.0:
		return
	var direction := delta.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var line := Line2D.new()
	line.width = 7.0 if heavy else 4.0
	line.default_color = color
	line.add_point(from_pos + perpendicular * 12.0)
	line.add_point(from_pos.lerp(to_pos, 0.55) + perpendicular * 22.0)
	line.add_point(to_pos - direction * 5.0)
	line.z_index = 74
	if not _track(line):
		line.free()
		return
	var tween := line.create_tween().set_parallel(true)
	tween.tween_property(line, "width", 0.5, 0.18)
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.finished.connect(line.queue_free)

func lightning(from_pos: Vector2, to_pos: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(1.0, 0.95, 0.35, 1.0)
	var delta := to_pos - from_pos
	var perpendicular := Vector2(-delta.y, delta.x).normalized()
	for index in 7:
		var ratio := float(index) / 6.0
		var jitter := 0.0 if index in [0, 6] else sin(float(index) * 7.13) * 7.0
		line.add_point(from_pos.lerp(to_pos, ratio) + perpendicular * jitter)
	line.z_index = 75
	if not _track(line):
		line.free()
		return
	var tween := line.create_tween().set_parallel(true)
	tween.tween_property(line, "width", 1.0, 0.16)
	tween.tween_property(line, "modulate:a", 0.0, 0.16)
	tween.finished.connect(line.queue_free)
	impact(to_pos, Color(1.0, 0.9, 0.3), true)

func phase_step(from_pos: Vector2, to_pos: Vector2) -> void:
	_ring(from_pos, Color(0.65, 0.3, 1.0), 28.0, 0.30, 3.0)
	_ring(to_pos, Color(0.85, 0.55, 1.0), 38.0, 0.34, 4.0)
	var trail := Line2D.new()
	trail.width = 8.0
	trail.default_color = Color(0.55, 0.2, 0.9, 0.65)
	trail.add_point(from_pos)
	trail.add_point(from_pos.lerp(to_pos, 0.5) + Vector2(0, -16))
	trail.add_point(to_pos)
	trail.z_index = 71
	if not _track(trail):
		trail.free()
		return
	var tween := trail.create_tween().set_parallel(true)
	tween.tween_property(trail, "width", 0.5, 0.28)
	tween.tween_property(trail, "modulate:a", 0.0, 0.28)
	tween.finished.connect(trail.queue_free)

func buff_pulse(pos: Vector2, color: Color) -> void:
	_ring(pos, color, 46.0, 0.48, 4.0)
	_ring(pos, color.lightened(0.25), 28.0, 0.32, 2.0)

func floating_text(pos: Vector2, text: String, color: Color, font_size: int, kind: String = "normal") -> void:
	var label := Label.new()
	label.text = text
	label.position = pos + Vector2(-90, -46)
	label.size = Vector2(180, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 100
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 4 if kind in ["critical", "status"] else 3)
	label.add_theme_font_size_override("font_size", roundi(float(font_size) * (1.25 if kind == "critical" else 1.0)))
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.3, 1.3) if kind == "critical" else Vector2.ONE
	if not _track(label):
		label.free()
		return
	var duration := 1.0 if kind in ["critical", "status"] else 0.75
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -34 if kind == "critical" else -26), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.45)
	if kind == "critical":
		tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(label.queue_free)

func loot_drop(node: Node2D, quality: String, color: Color) -> void:
	var sprite := node.get_child(0) as Sprite2D
	var label := node.get_node_or_null("DropLabel") as Label
	if sprite == null:
		return
	var final_scale := sprite.scale
	sprite.position = Vector2(0, -30)
	sprite.scale = final_scale * 0.35
	if label != null:
		label.modulate.a = 0.0
	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", final_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if label != null:
		tween.tween_property(label, "modulate:a", 1.0, 0.16).set_delay(0.16)
	if quality in ["rare", "set", "unique"]:
		_ring(node.position, color, 24.0 if quality == "rare" else 34.0, 0.5, 3.0)

func pickup(texture: Texture2D, from_pos: Vector2, to_pos: Vector2, color: Color, initial_scale: Vector2) -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = from_pos
	sprite.scale = initial_scale
	sprite.modulate = color
	sprite.z_index = 90
	if not _track(sprite):
		sprite.free()
		return
	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "position", to_pos + Vector2(0, -24), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18).set_delay(0.08)
	tween.finished.connect(sprite.queue_free)

static func selftest() -> bool:
	return MAX_ACTIVE >= 48 and MAX_ACTIVE <= 96
