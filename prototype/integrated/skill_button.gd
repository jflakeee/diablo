extends Control
# 스킬 버튼: 탭 시 지정 스킬 사용. (홀드/차징은 P0 프로토타입 참조)

signal used(skill_id: String)

var skill_id := "bash"
var label_text := "?"
var color := Color.ORANGE

func _ready() -> void:
	size = Vector2(132, 132)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed:
		used.emit(skill_id)

func _draw() -> void:
	var c := size * 0.5
	var r := 62.0
	var base := color
	base.a = 0.32
	draw_circle(c, r, base)
	draw_arc(c, r, 0.0, TAU, 40, color, 3.0)
	var f := ThemeDB.fallback_font
	draw_string(f, c + Vector2(-r + 10, 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, 2 * r - 20, 22, Color.WHITE)
