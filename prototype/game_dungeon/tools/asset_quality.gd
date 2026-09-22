extends RefCounted
# 절차 픽셀 자산의 구조적 품질 검사. 미적 판단 대신 회귀 가능한 불변식을 측정한다.

static func opaque_pixels(img: Image) -> int:
	var count := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				count += 1
	return count

static func palette_size(img: Image) -> int:
	var colors := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				colors[c.to_html()] = true
	return colors.size()

static func touches_edge(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		if img.get_pixel(x, 0).a >= 0.5 or img.get_pixel(x, h - 1).a >= 0.5:
			return true
	for y in h:
		if img.get_pixel(0, y).a >= 0.5 or img.get_pixel(w - 1, y).a >= 0.5:
			return true
	return false

static func connected_components(img: Image) -> int:
	var seen := {}
	var components := 0
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	for y in img.get_height():
		for x in img.get_width():
			var start := Vector2i(x, y)
			if seen.has(start) or img.get_pixelv(start).a < 0.5:
				continue
			components += 1
			var queue: Array[Vector2i] = [start]
			seen[start] = true
			while not queue.is_empty():
				var p: Vector2i = queue.pop_back()
				for d in dirs:
					var n: Vector2i = p + d
					if n.x < 0 or n.y < 0 or n.x >= img.get_width() or n.y >= img.get_height():
						continue
					if not seen.has(n) and img.get_pixelv(n).a >= 0.5:
						seen[n] = true
						queue.append(n)
	return components

static func pixel_difference(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return maxi(a.get_width() * a.get_height(), b.get_width() * b.get_height())
	var different := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				different += 1
	return different

static func opaque_bounds(img: Image) -> Rect2i:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				min_x = mini(min_x, x); min_y = mini(min_y, y)
				max_x = maxi(max_x, x); max_y = maxi(max_y, y)
	return Rect2i(min_x, min_y, maxi(0, max_x - min_x + 1), maxi(0, max_y - min_y + 1))

static func silhouette_iou(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 0.0
	var intersection := 0
	var union := 0
	for y in a.get_height():
		for x in a.get_width():
			var aa := a.get_pixel(x, y).a >= 0.5
			var bb := b.get_pixel(x, y).a >= 0.5
			if aa or bb: union += 1
			if aa and bb: intersection += 1
	return float(intersection) / float(maxi(union, 1))

static func validate_animation(label: String, frames: Array) -> Dictionary:
	var failures: Array = []
	var foot_min := 999
	var foot_max := -1
	var head_min := 999
	var head_max := -1
	var min_iou := 1.0
	for frame in frames:
		var bounds := opaque_bounds(frame)
		head_min = mini(head_min, bounds.position.y)
		head_max = maxi(head_max, bounds.position.y)
		foot_min = mini(foot_min, bounds.end.y - 1)
		foot_max = maxi(foot_max, bounds.end.y - 1)
	for i in frames.size():
		var next := (i + 1) % frames.size()
		var iou := silhouette_iou(frames[i], frames[next])
		var difference := pixel_difference(frames[i], frames[next])
		min_iou = minf(min_iou, iou)
		if iou < 0.55: failures.append("%s: frame %d IoU %.3f" % [label, i, iou])
		if difference < 4 or difference > int(frames[i].get_width() * frames[i].get_height() * 0.45):
			failures.append("%s: frame %d difference %d" % [label, i, difference])
	if foot_max - foot_min > 2: failures.append("%s: foot anchor drift %d" % [label, foot_max - foot_min])
	if head_max - head_min > 2: failures.append("%s: head anchor drift %d" % [label, head_max - head_min])
	return {"ok": failures.is_empty(), "failures": failures, "anchor_drift": maxi(foot_max - foot_min, head_max - head_min), "min_iou": min_iou}

static func validate_sprite(img: Image) -> Dictionary:
	var opaque := opaque_pixels(img)
	var colors := palette_size(img)
	var components := connected_components(img)
	var ok := opaque >= 24 and opaque <= int(img.get_width() * img.get_height() * 0.8)
	ok = ok and colors >= 3 and colors <= 48 and components <= 6 and not touches_edge(img)
	return {"ok": ok, "opaque": opaque, "colors": colors, "components": components, "edge": touches_edge(img)}

static func suite(pixel_gen: GDScript, samples: Array) -> Dictionary:
	var failures: Array = []
	var checked := 0
	for i in range(4, samples.size()): # 노이즈 타일은 제한 팔레트 검사 대상에서 제외
		var img: Image = (samples[i][0] as Texture2D).get_image()
		var report := validate_sprite(img)
		checked += 1
		if not bool(report["ok"]):
			failures.append("%s:%s" % [String(samples[i][1]), str(report)])
	var barb0: Image = pixel_gen.hero("barbarian", Color(0.7, 0.2, 0.15), 10, 0, 0).get_image()
	var barb1: Image = pixel_gen.hero("barbarian", Color(0.7, 0.2, 0.15), 10, 0, 1).get_image()
	var sorc: Image = pixel_gen.hero("sorceress", Color(0.3, 0.3, 0.75), 11, 0, 0).get_image()
	var variant_a: Image = pixel_gen.monster(Color(0.5, 0.4, 0.3), 1).get_image()
	var variant_b: Image = pixel_gen.monster(Color(0.5, 0.4, 0.3), 2).get_image()
	var silhouette_diff := pixel_difference(barb0, sorc)
	var walk_diff := pixel_difference(barb0, barb1)
	var seed_diff := pixel_difference(variant_a, variant_b)
	if silhouette_diff < 100: failures.append("hero silhouette difference too small: %d" % silhouette_diff)
	if walk_diff < 8: failures.append("walk frame difference too small: %d" % walk_diff)
	if seed_diff < 8: failures.append("seed variation too small: %d" % seed_diff)
	var animation_checked := 0
	var max_anchor_drift := 0
	var min_animation_iou := 1.0
	var hero_defs := [["barbarian", Color(0.7, 0.2, 0.15), 10], ["sorceress", Color(0.3, 0.3, 0.75), 11], ["rogue", Color(0.5, 0.15, 0.2), 7]]
	for hero in hero_defs:
		for direction in 4:
			var hero_frames: Array = []
			for frame in 3: hero_frames.append(pixel_gen.hero(hero[0], hero[1], hero[2], direction, frame).get_image())
			var report := validate_animation("hero/%s/%d" % [hero[0], direction], hero_frames)
			failures.append_array(report["failures"])
			max_anchor_drift = maxi(max_anchor_drift, int(report["anchor_drift"]))
			min_animation_iou = minf(min_animation_iou, float(report["min_iou"]))
			animation_checked += 1
	for sample in samples:
		var recipe: Dictionary = sample[3]
		if String(recipe.get("type", "")) != "monster": continue
		var monster_frames: Array = []
		var color := Color.from_string(String(recipe.get("color", "#808080")), Color.GRAY)
		for frame in 3: monster_frames.append(pixel_gen.monster_named(String(recipe.get("kind", recipe["id"])), color, int(recipe.get("seed", 0)), frame).get_image())
		var report := validate_animation("monster/" + String(recipe["id"]), monster_frames)
		failures.append_array(report["failures"])
		max_anchor_drift = maxi(max_anchor_drift, int(report["anchor_drift"]))
		min_animation_iou = minf(min_animation_iou, float(report["min_iou"]))
		animation_checked += 1
	return {"ok": failures.is_empty(), "checked": checked, "failures": failures,
		"silhouette_diff": silhouette_diff, "walk_diff": walk_diff, "seed_diff": seed_diff,
		"animation_checked": animation_checked, "max_anchor_drift": max_anchor_drift, "min_animation_iou": min_animation_iou}
