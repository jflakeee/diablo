extends Panel
# 인벤토리 셀 — 아이템 표시 + 클릭 장착 + 드래그(드래그&드롭 소스). preload로 사용.

signal clicked(item: Dictionary)

var item: Dictionary = {}
var _label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(80, 44)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.position = Vector2(4, 3)
	_label.size = Vector2(74, 38)
	_label.add_theme_font_size_override("font_size", 10)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

func set_item(it: Dictionary, disp: String, tip: String, col: Color) -> void:
	item = it
	_label.text = disp
	tooltip_text = tip
	self_modulate = col

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if not item.is_empty():
			clicked.emit(item)

func _get_drag_data(_pos: Vector2) -> Variant:
	if item.is_empty():
		return null
	var preview := Label.new()
	preview.text = _label.text
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"kind": "inv_item", "item": item}
