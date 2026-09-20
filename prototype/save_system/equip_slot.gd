extends Panel
# 장비 슬롯 — 장착 아이템 표시 + 클릭 해제 + 드롭 수용(드래그&드롭 타겟). preload로 사용.

signal unequip_requested(slot: String)
signal equip_dropped(slot: String, item: Dictionary)

var slot := "weapon"
var _title: Label
var _label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(150, 52)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = Label.new()
	_title.position = Vector2(4, 1)
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(_title)
	_label = Label.new()
	_label.position = Vector2(4, 16)
	_label.size = Vector2(144, 34)
	_label.add_theme_font_size_override("font_size", 11)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

func set_slot(s: String) -> void:
	slot = s
	_title.text = "[%s]" % s

func set_display(disp: String, tip: String, col: Color) -> void:
	_label.text = disp
	tooltip_text = tip
	self_modulate = col

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		unequip_requested.emit(slot)

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and String(data.get("kind", "")) == "inv_item" and String((data["item"] as Dictionary).get("slot", "")) == slot

func _drop_data(_pos: Vector2, data: Variant) -> void:
	equip_dropped.emit(slot, data["item"])
