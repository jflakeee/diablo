extends Node2D
# 기본 엔티티(플레이어/몬스터 공용): 스탯 + 생명 + HP바.
# preload로 사용: const ActorScript := preload("res://actor.gd")

signal died(actor: Node)

var actor_name := "Actor"
var is_player := false
var level := 1
var stat_str := 10
var stat_dex := 10
var stat_vit := 10
var stat_energy := 10

var max_life := 50
var life := 50
var attack_rating := 100
var defense := 10
var dmg_min := 1
var dmg_max := 3

var speed := 4.0          # grid units/sec
var gx := 0.0
var gy := 0.0
var alive := true
var attack_cd := 0.0      # 남은 공격 쿨다운(초)

var _sprite: Sprite2D

func setup(tex: Texture2D) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	add_child(_sprite)

func take_damage(amount: int) -> void:
	if not alive:
		return
	life -= amount
	if life <= 0:
		life = 0
		alive = false
		modulate = Color(0.4, 0.4, 0.4, 0.7)
		died.emit(self)
	queue_redraw()

func _draw() -> void:
	if not alive:
		return
	var w := 34.0
	var frac := clampf(float(life) / float(maxi(max_life, 1)), 0.0, 1.0)
	var top := Vector2(-w * 0.5, -34.0)
	draw_rect(Rect2(top, Vector2(w, 5)), Color(0, 0, 0, 0.6))
	var fill := Color(0.3, 0.8, 0.35) if is_player else Color(0.85, 0.22, 0.2)
	draw_rect(Rect2(top, Vector2(w * frac, 5)), fill)
