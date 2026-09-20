extends Control
# 가상 조이스틱: 눌린 지점 기준 드래그로 방향 벡터(value, -1..1) 산출.

var value: Vector2 = Vector2.ZERO
var _radius := 135.0
var _knob := 58.0
var _touch_id := -1
var _center := Vector2.ZERO
var _knob_pos := Vector2.ZERO

func _ready() -> void:
	size = Vector2(320, 320)
	_center = size * 0.5
	_knob_pos = _center

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if get_global_rect().has_point(e.position):
				_touch_id = e.index
				_update(e.position)
		elif e.index == _touch_id:
			_reset()
	elif e is InputEventScreenDrag and e.index == _touch_id:
		_update(e.position)

func _update(global_pos: Vector2) -> void:
	var off := (global_pos - global_position) - _center
	if off.length() > _radius:
		off = off.normalized() * _radius
	_knob_pos = _center + off
	value = Vector2(off.x / _radius, off.y / _radius)
	queue_redraw()

func _reset() -> void:
	_touch_id = -1
	_knob_pos = _center
	value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	draw_circle(_center, _radius, Color(1, 1, 1, 0.10))
	draw_arc(_center, _radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(_knob_pos, _knob, Color(1, 1, 1, 0.5))
