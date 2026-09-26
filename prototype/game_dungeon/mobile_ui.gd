extends RefCounted
# Mobile-first HUD geometry in logical pixels. Visuals remain project-owned.

const EDGE := 16.0
const MENU_SIZE := Vector2(104, 48)
const SKILL_SIZE := Vector2(112, 112)
const JOYSTICK_SIZE := Vector2(240, 240)
const POTION_SIZE := Vector2(80, 80)
const MINIMAP_SIZE := Vector2(160, 160)
const DESKTOP_MENU_SIZE := Vector2(92, 42)
const DESKTOP_SKILL_SIZE := Vector2(88, 88)
const DESKTOP_POTION_SIZE := Vector2(64, 64)
const DESKTOP_MINIMAP_SIZE := Vector2(180, 180)
const MIN_LOGICAL := Vector2(960, 540)

static func prefer_mobile(viewport: Vector2) -> bool:
	if OS.get_name() in ["Android", "iOS"]:
		return true
	if OS.has_feature("web"):
		var user_agent := String(JavaScriptBridge.eval("navigator.userAgent", true)).to_lower()
		for marker in ["android", "iphone", "ipad", "ipod", "mobile"]:
			if user_agent.contains(marker):
				return true
	return viewport.x < 1000.0

static func effective_scale(requested: float, viewport: Vector2) -> float:
	return minf(requested, minf(viewport.x / MIN_LOGICAL.x, viewport.y / MIN_LOGICAL.y))

static func logical_safe_area(viewport: Vector2) -> Rect2:
	var window_size := Vector2(DisplayServer.window_get_size())
	var physical := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or window_size.y <= 0.0 or physical.size.x <= 0.0 or physical.size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport)
	var scale := Vector2(viewport.x / window_size.x, viewport.y / window_size.y)
	return Rect2(physical.position * scale, physical.size * scale)

static func layout(viewport: Vector2, safe: Rect2 = Rect2(), mobile: bool = true) -> Dictionary:
	var area := safe
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = Rect2(Vector2.ZERO, viewport)
	var left := area.position.x + EDGE
	var top := area.position.y + EDGE
	var right := area.end.x - EDGE
	var bottom := area.end.y - EDGE
	var menu_size := MENU_SIZE if mobile else DESKTOP_MENU_SIZE
	var skill_size := SKILL_SIZE if mobile else DESKTOP_SKILL_SIZE
	var potion_size := POTION_SIZE if mobile else DESKTOP_POTION_SIZE
	var minimap_size := MINIMAP_SIZE if mobile else DESKTOP_MINIMAP_SIZE
	var minimap_x := (left + right - minimap_size.x) * 0.5 if mobile and area.size.y < 650.0 else right - minimap_size.x
	var skill_primary := Vector2(right - skill_size.x, bottom - skill_size.y)
	var skill_secondary := Vector2(right - skill_size.x * 2.0 - 8, bottom - skill_size.y)
	var skill_utility := Vector2(right - skill_size.x, bottom - skill_size.y * 2.0 - 8)
	var skill_quaternary := Vector2(right - skill_size.x * 2.0 - 8, bottom - skill_size.y * 2.0 - 8)
	if not mobile:
		skill_utility = Vector2(right - skill_size.x * 3.0 - 16, bottom - skill_size.y)
		skill_quaternary = Vector2(right - skill_size.x * 4.0 - 24, bottom - skill_size.y)
	return {
		"mobile": mobile, "menu_size": menu_size, "skill_size": skill_size, "potion_size": potion_size, "minimap_size": minimap_size,
		"hud": Vector2(left, top),
		"char": Vector2(right - menu_size.x * 3.0 - 16, top), "shop": Vector2(right - menu_size.x * 2.0 - 8, top), "bag": Vector2(right - menu_size.x, top),
		"minimap": Vector2(minimap_x, top + menu_size.y + 16),
		"joystick": Vector2(left, bottom - JOYSTICK_SIZE.y),
		"potion_hp": Vector2(left, bottom - (JOYSTICK_SIZE.y + potion_size.y + 8 if mobile else potion_size.y)),
		"potion_mp": Vector2(left + potion_size.x + 14, bottom - (JOYSTICK_SIZE.y + potion_size.y + 8 if mobile else potion_size.y)),
		"skill_primary": skill_primary,
		"skill_secondary": skill_secondary,
		"skill_utility": skill_utility,
		"skill_quaternary": skill_quaternary,
		"panel": Vector2(right - 360, top + menu_size.y + 8),
		"settings": Vector2((left + right - 96) * 0.5, bottom - (56 if mobile else 42)),
		"settings_panel": Vector2((left + right - 360) * 0.5, (top + bottom - 250) * 0.5),
	}

static func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return bounds.encloses(rect)

static func validate(viewport: Vector2, mobile: bool = true) -> Dictionary:
	var positions := layout(viewport, Rect2(), mobile)
	var bounds := Rect2(Vector2(EDGE, EDGE), viewport - Vector2(EDGE * 2.0, EDGE * 2.0))
	var skill_size: Vector2 = positions["skill_size"]
	var potion_size: Vector2 = positions["potion_size"]
	var minimap_size: Vector2 = positions["minimap_size"]
	var rects := {
		"potion_hp": Rect2(positions["potion_hp"], potion_size),
		"potion_mp": Rect2(positions["potion_mp"], potion_size),
		"skill_primary": Rect2(positions["skill_primary"], skill_size),
		"skill_secondary": Rect2(positions["skill_secondary"], skill_size),
		"skill_utility": Rect2(positions["skill_utility"], skill_size),
		"skill_quaternary": Rect2(positions["skill_quaternary"], skill_size),
		"minimap": Rect2(positions["minimap"], minimap_size),
	}
	if mobile:
		rects["joystick"] = Rect2(positions["joystick"], JOYSTICK_SIZE)
	var failures: Array = []
	for id in rects:
		if not _inside(rects[id], bounds): failures.append(id + " outside safe margin")
	var combat_ids := rects.keys()
	for i in combat_ids.size():
		for j in range(i + 1, combat_ids.size()):
			if (rects[combat_ids[i]] as Rect2).intersects(rects[combat_ids[j]]):
				failures.append(combat_ids[i] + " overlaps " + combat_ids[j])
	return {"ok": failures.is_empty(), "failures": failures}

static func selftest() -> bool:
	for viewport in [Vector2(960, 540), Vector2(960, 720), Vector2(1280, 720), Vector2(1600, 720)]:
		for mobile in [true, false]:
			if not bool(validate(viewport, mobile)["ok"]):
				push_error("Responsive UI layout failed %s mobile=%s: %s" % [str(viewport), str(mobile), str(validate(viewport, mobile)["failures"])])
				return false
	for requested in [0.8, 1.0, 1.2, 1.4]:
		var applied := effective_scale(requested, Vector2(1280, 720))
		if applied > requested or (Vector2(1280, 720) / applied).x < MIN_LOGICAL.x:
			return false
	return SKILL_SIZE.x >= 72.0 and POTION_SIZE.x >= 48.0 and MENU_SIZE.y >= 48.0 and JOYSTICK_SIZE.x <= 240.0 \
		and DESKTOP_SKILL_SIZE.x < SKILL_SIZE.x and DESKTOP_POTION_SIZE.x < POTION_SIZE.x
