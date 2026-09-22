extends RefCounted
# Mobile-first HUD geometry in logical pixels. Visuals remain project-owned.

const EDGE := 16.0
const MENU_SIZE := Vector2(120, 56)
const SKILL_SIZE := Vector2(132, 132)
const JOYSTICK_SIZE := Vector2(320, 320)
const POTION_SIZE := Vector2(96, 96)
const MINIMAP_SIZE := Vector2(190, 190)
const MIN_LOGICAL := Vector2(960, 540)

static func effective_scale(requested: float, viewport: Vector2) -> float:
	return minf(requested, minf(viewport.x / MIN_LOGICAL.x, viewport.y / MIN_LOGICAL.y))

static func logical_safe_area(viewport: Vector2) -> Rect2:
	var window_size := Vector2(DisplayServer.window_get_size())
	var physical := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or window_size.y <= 0.0 or physical.size.x <= 0.0 or physical.size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport)
	var scale := Vector2(viewport.x / window_size.x, viewport.y / window_size.y)
	return Rect2(physical.position * scale, physical.size * scale)

static func layout(viewport: Vector2, safe: Rect2 = Rect2()) -> Dictionary:
	var area := safe
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = Rect2(Vector2.ZERO, viewport)
	var left := area.position.x + EDGE
	var top := area.position.y + EDGE
	var right := area.end.x - EDGE
	var bottom := area.end.y - EDGE
	var minimap_x := (left + right - MINIMAP_SIZE.x) * 0.5 if area.size.y < 650.0 else right - MINIMAP_SIZE.x
	return {
		"hud": Vector2(left, top),
		"char": Vector2(right - 380, top), "shop": Vector2(right - 250, top), "bag": Vector2(right - 120, top),
		"minimap": Vector2(minimap_x, top + MENU_SIZE.y + 16),
		"joystick": Vector2(left, bottom - JOYSTICK_SIZE.y),
		"potion_hp": Vector2(left, bottom - JOYSTICK_SIZE.y - POTION_SIZE.y - 8),
		"potion_mp": Vector2(left + POTION_SIZE.x + 14, bottom - JOYSTICK_SIZE.y - POTION_SIZE.y - 8),
		"skill_primary": Vector2(right - SKILL_SIZE.x, bottom - SKILL_SIZE.y),
		"skill_secondary": Vector2(right - SKILL_SIZE.x * 2.0 - 8, bottom - SKILL_SIZE.y),
		"skill_utility": Vector2(right - SKILL_SIZE.x * 1.5 - 4, bottom - SKILL_SIZE.y * 2.0 - 8),
		"panel": Vector2(right - 360, top + MENU_SIZE.y + 8),
		"settings": Vector2((left + right - 96) * 0.5, bottom - 56),
		"settings_panel": Vector2((left + right - 360) * 0.5, (top + bottom - 250) * 0.5),
	}

static func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return bounds.encloses(rect)

static func validate(viewport: Vector2) -> Dictionary:
	var positions := layout(viewport)
	var bounds := Rect2(Vector2(EDGE, EDGE), viewport - Vector2(EDGE * 2.0, EDGE * 2.0))
	var rects := {
		"joystick": Rect2(positions["joystick"], JOYSTICK_SIZE),
		"potion_hp": Rect2(positions["potion_hp"], POTION_SIZE),
		"potion_mp": Rect2(positions["potion_mp"], POTION_SIZE),
		"skill_primary": Rect2(positions["skill_primary"], SKILL_SIZE),
		"skill_secondary": Rect2(positions["skill_secondary"], SKILL_SIZE),
		"skill_utility": Rect2(positions["skill_utility"], SKILL_SIZE),
		"minimap": Rect2(positions["minimap"], MINIMAP_SIZE),
	}
	var failures: Array = []
	for id in rects:
		if not _inside(rects[id], bounds): failures.append(id + " outside safe margin")
	var combat_ids := ["joystick", "potion_hp", "potion_mp", "skill_primary", "skill_secondary", "skill_utility", "minimap"]
	for i in combat_ids.size():
		for j in range(i + 1, combat_ids.size()):
			if (rects[combat_ids[i]] as Rect2).intersects(rects[combat_ids[j]]):
				failures.append(combat_ids[i] + " overlaps " + combat_ids[j])
	return {"ok": failures.is_empty(), "failures": failures}

static func selftest() -> bool:
	for viewport in [Vector2(960, 540), Vector2(960, 720), Vector2(1280, 720), Vector2(1600, 720)]:
		if not bool(validate(viewport)["ok"]):
			push_error("Mobile UI layout failed %s: %s" % [str(viewport), str(validate(viewport)["failures"])])
			return false
	for requested in [0.8, 1.0, 1.2, 1.4]:
		var applied := effective_scale(requested, Vector2(1280, 720))
		if applied > requested or (Vector2(1280, 720) / applied).x < MIN_LOGICAL.x:
			return false
	return SKILL_SIZE.x >= 72.0 and POTION_SIZE.x >= 48.0 and MENU_SIZE.y >= 48.0
