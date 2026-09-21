extends Node2D
# 엔티티(플레이어/몬스터 공용): 스탯 + 생명/마나 + 스킬레벨 + 버프 + HP/MP바.
# preload로 사용: const ActorScript := preload("res://actor.gd")

signal died(actor: Node)

var actor_name := "Actor"
var is_player := false
var level := 1
var stat_str := 10
var stat_dex := 10
var stat_vit := 10
var stat_energy := 10

var base_max_life := 50
var max_life := 50
var life := 50
var base_max_mana := 20
var max_mana := 20
var mana := 20

var attack_rating := 100
var defense := 10
var dmg_min := 1
var dmg_max := 3
var res_fire := 0      # 화염 저항%
var block_val := 0     # 방패 블록값
var leech_pct := 0     # 생명 흡혈%(바바리안 물리 / 소서리스 스펠)

var speed := 4.0
var gx := 0.0
var gy := 0.0
var alive := true
var attack_cd := 0.0

var xp := 0
var skill_points := 0
var skills := {}          # id(String) -> level(int)
var bo_pct := 0.0         # Battle Orders 최대 Life/Mana 보너스%
var bo_timer := 0.0       # 남은 지속(초)

var _sprite: Sprite2D

func setup(tex: Texture2D) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	add_child(_sprite)

var _base_scale := 1.0
var _prev_pos := Vector2.ZERO
var _anim_t := 0.0
var _pop_t := 0.0

func set_sprite_texture(tex: Texture2D, scale_v: float = 1.0) -> void:
	if _sprite:
		_sprite.texture = tex
		_base_scale = scale_v
		_sprite.scale = Vector2(scale_v, scale_v)

func pop() -> void:   # 공격 시 살짝 팽창
	_pop_t = 0.16

# 코드 기반 애니메이션: 걷기 bob + 방향 전환 + 공격 팝
func animate(delta: float) -> void:
	if _sprite == null:
		return
	var moving := position.distance_to(_prev_pos) > 0.6
	var dx := position.x - _prev_pos.x
	_prev_pos = position
	if absf(dx) > 0.2:
		_sprite.flip_h = dx < 0.0
	if moving:
		_anim_t += delta * 12.0
		_sprite.offset.y = -absf(sin(_anim_t)) * 3.0   # offset은 y-sort에 영향 X
	else:
		_anim_t = 0.0
		_sprite.offset.y = lerpf(_sprite.offset.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	if _pop_t > 0.0:
		_pop_t -= delta
		var s := _base_scale * (1.0 + 0.35 * maxf(_pop_t, 0.0) / 0.16)
		_sprite.scale = Vector2(s, s)
	else:
		_sprite.scale = Vector2(_base_scale, _base_scale)

func skill_level(id: String) -> int:
	return int(skills.get(id, 0))

func spend_mana(cost: int) -> bool:
	if mana >= cost:
		mana -= cost
		return true
	return false

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
	var life_frac := clampf(float(life) / float(maxi(max_life, 1)), 0.0, 1.0)
	var top := Vector2(-w * 0.5, -36.0)
	draw_rect(Rect2(top, Vector2(w, 5)), Color(0, 0, 0, 0.6))
	var fill := Color(0.3, 0.8, 0.35) if is_player else Color(0.85, 0.22, 0.2)
	draw_rect(Rect2(top, Vector2(w * life_frac, 5)), fill)
	if is_player:
		var mana_frac := clampf(float(mana) / float(maxi(max_mana, 1)), 0.0, 1.0)
		var mtop := Vector2(-w * 0.5, -29.0)
		draw_rect(Rect2(mtop, Vector2(w, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(mtop, Vector2(w * mana_frac, 3)), Color(0.3, 0.5, 0.9))
