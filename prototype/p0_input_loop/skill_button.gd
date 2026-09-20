extends Control
# 스킬 버튼: 탭(짧게)=즉시 자동조준 시전 / 홀드(길게)=차징 후 방출.
# Diablo Immortal 조작 패턴(Part 7 §2) 프로토타입.

signal tapped(skill_name: String)
signal charge_released(skill_name: String, charge: float)

var skill_name := "Skill"
var color := Color.ORANGE

const TAP_MAX_MS := 200.0
const CHARGE_FULL_MS := 1000.0

var _pressed := false
var _press_msec := 0
var _charge := 0.0

func _ready() -> void:
	size = Vector2(96, 96)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_pressed = true
			_press_msec = Time.get_ticks_msec()
		elif _pressed:
			var held := float(Time.get_ticks_msec() - _press_msec)
			if held <= TAP_MAX_MS:
				tapped.emit(skill_name)
			else:
				charge_released.emit(skill_name, _charge)
			_pressed = false
			_charge = 0.0
			queue_redraw()

func _process(_delta: float) -> void:
	if _pressed:
		var held := float(Time.get_ticks_msec() - _press_msec)
		_charge = clampf(held / CHARGE_FULL_MS, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := 44.0
	var base := color
	base.a = 0.6 if _pressed else 0.32
	draw_circle(c, r, base)
	draw_arc(c, r, 0.0, TAU, 32, color, 2.0)
	if _pressed and _charge > 0.0:
		draw_arc(c, r - 6.0, -PI / 2.0, -PI / 2.0 + TAU * _charge, 32, Color.WHITE, 4.0)
