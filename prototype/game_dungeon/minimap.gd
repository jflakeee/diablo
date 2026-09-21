extends Control
# 자동 지도(미니맵) — 지형은 ImageTexture(1회 생성)로 블릿, 동적 점만 매 프레임 그림.
# 저사양 최적화: draw는 텍스처 1회 + 소수 점. preload로 사용.

var tex: Texture2D
var gw := 45
var gh := 45
var player_cell := Vector2.ZERO
var exit_cell := Vector2.ZERO
var monster_cells: Array = []   # Array[Vector2]
var merc_cell = null            # Vector2 또는 null

func _to_px(c: Vector2) -> Vector2:
	return Vector2(c.x / float(maxi(gw, 1)) * size.x, c.y / float(maxi(gh, 1)) * size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.05, 0.6))
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	# 테두리
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.55, 0.4, 0.7), false, 2.0)
	for c in monster_cells:
		draw_circle(_to_px(c), 2.2, Color(0.9, 0.2, 0.2))
	if merc_cell != null:
		draw_circle(_to_px(merc_cell), 2.6, Color(0.3, 0.6, 1.0))
	draw_circle(_to_px(exit_cell), 3.4, Color(1.0, 0.85, 0.2))     # 출구=금색
	var p := _to_px(player_cell)
	draw_circle(p, 3.6, Color(0.3, 1.0, 0.4))                       # 플레이어=초록
	draw_circle(p, 5.2, Color(0.3, 1.0, 0.4, 0.35))
