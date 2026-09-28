extends Control
# 스킬 버튼: 탭 시 지정 스킬 사용. (홀드/차징은 P0 프로토타입 참조)

signal used(skill_id: String)

var skill_id := "bash"
var label_text := "?"
var color := Color.ORANGE
var control_size := Vector2(112, 112)
var _cooldown_remaining := 0.0
var _cooldown_duration := 1.0
var _press_pulse := 0.0

func _ready() -> void:
	size = control_size
	pivot_offset = size * 0.5
	set_process(true)

func press_feedback() -> void:
	_press_pulse = 0.16
	queue_redraw()

func start_cooldown(duration: float) -> void:
	_cooldown_duration = maxf(0.01, duration)
	_cooldown_remaining = _cooldown_duration
	queue_redraw()

func cooldown_ratio() -> float:
	return clampf(_cooldown_remaining / _cooldown_duration, 0.0, 1.0)

func _process(delta: float) -> void:
	var changed := false
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		changed = true
	if _press_pulse > 0.0:
		_press_pulse = maxf(0.0, _press_pulse - delta)
		var pulse_ratio := _press_pulse / 0.16
		scale = Vector2.ONE * (1.0 - sin(pulse_ratio * PI) * 0.10)
		changed = true
	elif scale != Vector2.ONE:
		scale = Vector2.ONE
		changed = true
	if changed:
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed:
		press_feedback()
		used.emit(skill_id)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		press_feedback()
		used.emit(skill_id)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.47
	var base := color
	base.a = 0.32
	draw_circle(c, r, base)
	draw_arc(c, r, 0.0, TAU, 40, color, 3.0)
	var ratio := cooldown_ratio()
	if ratio > 0.0:
		var wedge := PackedVector2Array([c])
		var steps := maxi(2, ceili(28.0 * ratio))
		for index in range(steps + 1):
			var angle := -PI * 0.5 + TAU * ratio * float(index) / float(steps)
			wedge.append(c + Vector2(cos(angle), sin(angle)) * (r - 2.0))
		draw_colored_polygon(wedge, Color(0.02, 0.025, 0.04, 0.72))
		draw_arc(c, r * 0.76, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - ratio), 28, color.lightened(0.35), 4.0)
	var f := ThemeDB.fallback_font
	draw_string(f, c + Vector2(-r + 6, 5), label_text, HORIZONTAL_ALIGNMENT_CENTER, 2 * r - 12, 14 if size.x < 100 else 20, Color.WHITE)

static func selftest() -> bool:
	var button := new()
	button.start_cooldown(0.5)
	var result := is_equal_approx(button.cooldown_ratio(), 1.0) and button._cooldown_duration >= 0.5
	button.free()
	return result
