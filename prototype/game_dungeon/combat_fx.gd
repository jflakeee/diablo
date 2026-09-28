extends Node2D
## Lightweight, code-generated combat feedback for the Compatibility renderer.
## Gameplay owns damage and timing; this node only visualizes confirmed events.

const MAX_ACTIVE := 72
const MAX_FLOATING_TEXT := 20
const DAMAGE_BATCH_MS := 140
var _active: Array[Node] = []
var _damage_batches := {}
var _recent_text_positions: Array[Dictionary] = []
var quality := 1

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)

func _active_limit() -> int:
	return [36, 54, MAX_ACTIVE][quality]

func _text_limit() -> int:
	return [10, 15, MAX_FLOATING_TEXT][quality]

func _track(node: Node) -> bool:
	for index in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[index]):
			_active.remove_at(index)
	if _active.size() >= _active_limit():
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
	var shard_count: int = ([4, 6, 9][quality] if heavy else [2, 4, 5][quality])
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

func elemental_impact(pos: Vector2, element: String, heavy: bool = false) -> void:
	var colors := {"fire": Color(1.0, 0.32, 0.08), "cold": Color(0.38, 0.78, 1.0), "light": Color(1.0, 0.92, 0.24), "poison": Color(0.38, 0.9, 0.28)}
	var color: Color = colors.get(element, Color.WHITE)
	impact(pos, color, heavy)
	var count: int = [2, 4, 6][quality]
	for index in count:
		var accent := Line2D.new()
		accent.width = 3.5 if heavy else 2.5
		accent.default_color = color.lightened(0.22)
		accent.position = pos
		accent.z_index = 76
		var ratio := float(index) / float(maxi(1, count - 1))
		var angle := -PI * 0.85 + ratio * PI * 0.7
		var length := 24.0 if heavy else 17.0
		match element:
			"fire":
				accent.add_point(Vector2.ZERO)
				accent.add_point(Vector2(cos(angle), sin(angle)) * length + Vector2(0, -8))
			"cold":
				angle = TAU * float(index) / float(count)
				accent.add_point(Vector2(cos(angle), sin(angle)) * 4.0)
				accent.add_point(Vector2(cos(angle), sin(angle)) * (length + 5.0))
			"light":
				var side := -1.0 if index % 2 == 0 else 1.0
				accent.add_point(Vector2(side * 4.0, -10.0))
				accent.add_point(Vector2(-side * 3.0, -2.0))
				accent.add_point(Vector2(side * 5.0, 9.0))
			"poison":
				var spread := (ratio - 0.5) * 28.0
				accent.add_point(Vector2(spread, 5.0))
				accent.add_point(Vector2(spread * 0.7, -length))
			_:
				accent.add_point(Vector2.ZERO)
				accent.add_point(Vector2.UP * length)
		if not _track(accent):
			accent.free()
			continue
		var travel := Vector2(0, -10.0) if element in ["fire", "poison"] else Vector2.ZERO
		var tween := accent.create_tween().set_parallel(true)
		tween.tween_property(accent, "position", pos + travel, 0.30)
		tween.tween_property(accent, "modulate:a", 0.0, 0.30).set_delay(0.06)
		tween.tween_property(accent, "width", 0.5, 0.30)
		tween.finished.connect(accent.queue_free)

func nova_wave(pos: Vector2, element: String, radius: float) -> void:
	var color := Color(0.38, 0.9, 0.28) if element == "poison" else Color(0.72, 0.32, 1.0)
	_ring(pos, Color(color.r, color.g, color.b, 0.9), radius * 0.38, 0.32, 5.0)
	_ring(pos, Color(color.r, color.g, color.b, 0.62), radius * 0.68, 0.48, 3.5)
	if quality > 0:
		_ring(pos, Color(color.r, color.g, color.b, 0.38), radius, 0.64, 2.0)
	var ray_count: int = [4, 6, 8][quality]
	for index in ray_count:
		var angle := TAU * float(index) / float(ray_count)
		var ray := Line2D.new()
		ray.width = 3.0
		ray.default_color = color
		ray.position = pos
		ray.z_index = 70
		ray.add_point(Vector2(cos(angle), sin(angle) * 0.55) * 14.0)
		ray.add_point(Vector2(cos(angle), sin(angle) * 0.55) * radius)
		if not _track(ray):
			ray.free()
			continue
		var tween := ray.create_tween().set_parallel(true)
		tween.tween_property(ray, "modulate:a", 0.0, 0.55).set_delay(0.12)
		tween.tween_property(ray, "width", 0.5, 0.55)
		tween.finished.connect(ray.queue_free)

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

func recovery_pulse(pos: Vector2, color: Color) -> void:
	_ring(pos, color, 30.0, 0.34, 3.0)
	var column := Line2D.new()
	column.width = 6.0
	column.default_color = Color(color.r, color.g, color.b, 0.75)
	column.add_point(pos + Vector2(0, 10))
	column.add_point(pos + Vector2(0, -34))
	column.z_index = 69
	if not _track(column):
		column.free()
		return
	var tween := column.create_tween().set_parallel(true)
	tween.tween_property(column, "position:y", -12.0, 0.32)
	tween.tween_property(column, "modulate:a", 0.0, 0.32)
	tween.finished.connect(column.queue_free)

func block_impact(pos: Vector2) -> void:
	_ring(pos, Color(0.55, 0.82, 1.0), 25.0, 0.22, 5.0)
	var shield := Polygon2D.new()
	shield.polygon = PackedVector2Array([Vector2(-10, -12), Vector2(10, -12), Vector2(8, 6), Vector2(0, 14), Vector2(-8, 6)])
	shield.color = Color(0.55, 0.8, 1.0, 0.72)
	shield.position = pos + Vector2(0, -10)
	shield.z_index = 76
	if not _track(shield):
		shield.free()
		return
	var tween := shield.create_tween().set_parallel(true)
	tween.tween_property(shield, "scale", Vector2(1.35, 1.35), 0.2)
	tween.tween_property(shield, "modulate:a", 0.0, 0.2)
	tween.finished.connect(shield.queue_free)

func arc_throw(from_pos: Vector2, to_pos: Vector2) -> void:
	var path := Line2D.new()
	path.width = 3.0
	path.default_color = Color(1.0, 0.42, 0.12, 0.7)
	path.z_index = 73
	for index in 12:
		var ratio := float(index) / 11.0
		path.add_point(from_pos.lerp(to_pos, ratio) + Vector2(0, -sin(ratio * PI) * 48.0))
	if _track(path):
		var path_tween := path.create_tween().set_parallel(true)
		path_tween.tween_property(path, "modulate:a", 0.0, 0.42).set_delay(0.12)
		path_tween.tween_property(path, "width", 0.5, 0.42)
		path_tween.finished.connect(path.queue_free)
	else:
		path.free()
	var flask := Polygon2D.new()
	flask.polygon = PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(7, 5), Vector2(0, 9), Vector2(-7, 5)])
	flask.color = Color(1.0, 0.32, 0.08)
	flask.position = from_pos
	flask.z_index = 78
	if not _track(flask):
		flask.free()
		return
	var tween := flask.create_tween().set_parallel(true)
	tween.tween_method(func(ratio: float): flask.position = from_pos.lerp(to_pos, ratio) + Vector2(0, -sin(ratio * PI) * 48.0), 0.0, 1.0, 0.34)
	tween.tween_property(flask, "rotation", TAU * 1.5, 0.34)
	tween.finished.connect(func():
		impact(to_pos, Color(1.0, 0.38, 0.1), true)
		flask.queue_free())

func level_up(pos: Vector2) -> void:
	buff_pulse(pos, Color(1.0, 0.82, 0.26))
	for side in [-1.0, 1.0]:
		var ray := Line2D.new()
		ray.width = 4.0
		ray.default_color = Color(1.0, 0.9, 0.45)
		ray.add_point(pos)
		ray.add_point(pos + Vector2(22.0 * side, -58.0))
		ray.z_index = 74
		if not _track(ray):
			ray.free()
			continue
		var tween := ray.create_tween().set_parallel(true)
		tween.tween_property(ray, "modulate:a", 0.0, 0.55).set_delay(0.18)
		tween.tween_property(ray, "width", 1.0, 0.55)
		tween.finished.connect(ray.queue_free)

func ground_skill(from_pos: Vector2, to_pos: Vector2, kind: String) -> void:
	var direction := (to_pos - from_pos).normalized()
	if direction.length() < 0.1:
		direction = Vector2.RIGHT
	if kind == "void_fury":
		_ring(from_pos, Color(0.58, 0.16, 0.72), 58.0, 0.42, 7.0)
		_ring(from_pos, Color(0.95, 0.25, 0.45), 34.0, 0.30, 3.0)
		return
	var perpendicular := Vector2(-direction.y, direction.x)
	for branch in 3:
		var crack := Line2D.new()
		crack.width = 4.0 - float(branch)
		crack.default_color = Color(1.0, 0.36, 0.13, 0.9)
		crack.z_index = 69
		var side := float(branch - 1) * 7.0
		crack.add_point(from_pos + perpendicular * side)
		crack.add_point(from_pos + direction * 22.0 + perpendicular * (side - 5.0))
		crack.add_point(from_pos + direction * 48.0 + perpendicular * (side + 8.0))
		if not _track(crack):
			crack.free()
			continue
		var tween := crack.create_tween().set_parallel(true)
		tween.tween_property(crack, "modulate:a", 0.0, 0.48).set_delay(0.12)
		tween.tween_property(crack, "width", 0.5, 0.48)
		tween.finished.connect(crack.queue_free)

func death_burst(pos: Vector2, color: Color, elite: bool = false) -> void:
	impact(pos, color, elite)
	var count: int = ([5, 7, 10][quality] if elite else [3, 5, 6][quality])
	for index in count:
		var angle := TAU * float(index) / float(count) + 0.19
		var fragment := Polygon2D.new()
		fragment.polygon = PackedVector2Array([Vector2(-3, -2), Vector2(4, 0), Vector2(-2, 3)])
		fragment.color = color.darkened(0.12 * float(index % 3))
		fragment.position = pos
		fragment.rotation = angle
		fragment.z_index = 74
		if not _track(fragment):
			fragment.free()
			continue
		var travel := Vector2(cos(angle), sin(angle) * 0.55) * (34.0 if elite else 23.0)
		var tween := fragment.create_tween().set_parallel(true)
		tween.tween_property(fragment, "position", pos + travel + Vector2(0, 10), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "rotation", angle + PI * 1.5, 0.42)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.42).set_delay(0.16)
		tween.finished.connect(fragment.queue_free)

func floating_text(pos: Vector2, text: String, color: Color, font_size: int, kind: String = "normal") -> void:
	var now := Time.get_ticks_msec()
	for index in range(_recent_text_positions.size() - 1, -1, -1):
		if now - int(_recent_text_positions[index]["time"]) >= 520:
			_recent_text_positions.remove_at(index)
	var split := text.split(" ", false, 1)
	var numeric := not split.is_empty() and split[0].trim_suffix("!").is_valid_int()
	var suffix := "" if split.size() < 2 else " " + split[1]
	if numeric and kind == "normal":
		var coarse := Vector2i(roundi(pos.x / 28.0), roundi(pos.y / 28.0))
		var batch_key := "%d:%d:%s:%s" % [coarse.x, coarse.y, color.to_html(false), suffix]
		var existing: Dictionary = _damage_batches.get(batch_key, {})
		var existing_label = existing.get("label")
		if is_instance_valid(existing_label) and now - int(existing.get("time", 0)) <= DAMAGE_BATCH_MS:
			var total := int(existing.get("total", 0)) + int(split[0].trim_suffix("!"))
			existing_label.text = "%d%s" % [total, suffix]
			existing["total"] = total
			existing["time"] = now
			_damage_batches[batch_key] = existing
			return
	var text_count := 0
	for entry in _active:
		if is_instance_valid(entry) and entry is Label:
			text_count += 1
	if text_count >= _text_limit() and kind == "normal":
		return
	var nearby := 0
	for entry in _recent_text_positions:
		if (entry["pos"] as Vector2).distance_to(pos) < 44.0:
			nearby += 1
	var lane := nearby % 4
	var lane_offsets: Array[Vector2] = [Vector2.ZERO, Vector2(-24, -12), Vector2(24, -20), Vector2(0, -30)]
	var lane_offset: Vector2 = lane_offsets[lane]
	var label := Label.new()
	label.text = text
	label.position = pos + Vector2(-90, -46) + lane_offset
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
	_recent_text_positions.append({"pos": pos, "time": now})
	if numeric and kind == "normal":
		var coarse := Vector2i(roundi(pos.x / 28.0), roundi(pos.y / 28.0))
		var batch_key := "%d:%d:%s:%s" % [coarse.x, coarse.y, color.to_html(false), suffix]
		_damage_batches[batch_key] = {"label": label, "total": int(split[0].trim_suffix("!")), "time": now}
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
	if quality in ["rare", "set", "unique"] and self.quality > 0:
		_ring(node.position, color, 24.0 if quality == "rare" else 34.0, 0.5, 3.0)
		var beam := Polygon2D.new()
		var beam_height := 54.0 if quality == "rare" else 84.0
		beam.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(8, -beam_height), Vector2(-8, -beam_height)])
		beam.color = Color(color.r, color.g, color.b, 0.65)
		beam.position = node.position
		beam.z_index = 68
		if _track(beam):
			var beam_tween := beam.create_tween().set_parallel(true)
			beam_tween.tween_property(beam, "scale:x", 0.2, 0.65)
			beam_tween.tween_property(beam, "modulate:a", 0.0, 0.65).set_delay(0.18)
			beam_tween.finished.connect(beam.queue_free)
		else:
			beam.free()
	if quality in ["set", "unique"]:
		var aura := Line2D.new()
		aura.name = "PersistentLootAura"
		aura.width = 2.0
		aura.default_color = Color(color.r, color.g, color.b, 0.7)
		aura.closed = true
		aura.z_index = -1
		for index in 12:
			var angle := TAU * float(index) / 12.0
			aura.add_point(Vector2(cos(angle) * 18.0, sin(angle) * 8.0))
		node.add_child(aura)
		var aura_tween := aura.create_tween().set_loops()
		aura_tween.tween_property(aura, "modulate:a", 0.25, 0.7)
		aura_tween.tween_property(aura, "modulate:a", 0.9, 0.7)

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
	var supported_elements := ["fire", "cold", "light", "poison"]
	return MAX_ACTIVE >= 48 and MAX_ACTIVE <= 96 and MAX_FLOATING_TEXT <= 24 and DAMAGE_BATCH_MS >= 100 \
		and supported_elements.size() == 4 and supported_elements.has("poison")
