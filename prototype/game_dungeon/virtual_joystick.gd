extends Control
# 가상 조이스틱: 눌린 지점 기준 드래그로 방향 벡터(value, -1..1) 산출.

var value: Vector2 = Vector2.ZERO
var control_size := Vector2(240, 240)
var _radius := 102.0
var _knob := 44.0
var _touch_id := -1
var _center := Vector2.ZERO
var _knob_pos := Vector2.ZERO

func _ready() -> void:
	size = control_size
	_radius = minf(size.x, size.y) * 0.425
	_knob = minf(size.x, size.y) * 0.183
	_center = size * 0.5
	_knob_pos = _center

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * e.position
			if Rect2(Vector2.ZERO, size).has_point(local_pos):
				_touch_id = e.index
				_update_local(local_pos)
		elif e.index == _touch_id:
			_reset()
	elif e is InputEventScreenDrag and e.index == _touch_id:
		_update_local(get_global_transform_with_canvas().affine_inverse() * e.position)

func _update_local(local_pos: Vector2) -> void:
	var off := local_pos - _center
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
