extends Node2D
# 엔티티(플레이어/몬스터 공용): 스탯 + 생명/마나 + 스킬레벨 + 버프 + HP/MP바.
# preload로 사용: const ActorScript := preload("res://actor.gd")

signal died(actor: Node)

var actor_name := "Actor"
var is_player := false
var is_ally := false      # 용병 등 아군(초록 체력바)
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
var res_cold := 0      # 냉기 저항%
var res_light := 0     # 번개 저항%
var res_poison := 0    # 독 저항%
var slow_timer := 0.0  # 냉기 슬로우 남은 시간
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
var _idle_texture: Texture2D
var _walk_frames: Array = []
var _shown_frame := -1
var _direction_sets := {}
var _facing := 0 # 0=남, 1=동, 2=북, 3=서
var _facings_seen := {0: true}

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
		_idle_texture = tex
		_walk_frames.clear()
		_direction_sets.clear()

func set_sprite_frames(idle: Texture2D, walk: Array, scale_v: float = 1.0) -> void:
	_idle_texture = idle
	_walk_frames = walk
	_direction_sets.clear()
	_shown_frame = -1
	if _sprite:
		_sprite.texture = idle
		_base_scale = scale_v
		_sprite.scale = Vector2(scale_v, scale_v)

func set_directional_frames(sets: Dictionary, scale_v: float = 1.0) -> void:
	_direction_sets = sets
	_facing = 0
	_shown_frame = -1
	var south: Dictionary = sets.get(0, {})
	if south.is_empty():
		return
	_idle_texture = south["idle"]
	_walk_frames = south["walk"]
	if _sprite:
		_sprite.texture = _idle_texture
		_base_scale = scale_v
		_sprite.scale = Vector2(scale_v, scale_v)

func _set_facing_from_motion(dx: float, dy: float) -> void:
	var next_facing := 0
	if absf(dx) > absf(dy):
		next_facing = 1 if dx > 0.0 else 3
	else:
		next_facing = 0 if dy > 0.0 else 2
	if next_facing == _facing:
		return
	_facing = next_facing
	_facings_seen[_facing] = true
	var selected: Dictionary = _direction_sets.get(_facing, {})
	if not selected.is_empty():
		_idle_texture = selected["idle"]
		_walk_frames = selected["walk"]
		_shown_frame = -1

func facing_count() -> int:
	return _facings_seen.size()

func pop() -> void:   # 공격 시 살짝 팽창
	_pop_t = 0.16

# 코드 기반 애니메이션: 걷기 bob + 방향 전환 + 공격 팝
func animate(delta: float) -> void:
	if slow_timer > 0.0:
		slow_timer -= delta
	if _sprite == null:
		return
	var moving := position.distance_to(_prev_pos) > 0.6
	var dx := position.x - _prev_pos.x
	var dy := position.y - _prev_pos.y
	_prev_pos = position
	if not _direction_sets.is_empty() and Vector2(dx, dy).length() > 0.2:
		var old_facing := _facing
		_set_facing_from_motion(dx, dy)
		if old_facing != _facing:
			_sprite.texture = _idle_texture
		_sprite.flip_h = false
	elif absf(dx) > 0.2:
		_sprite.flip_h = dx < 0.0
	if moving:
		_anim_t += delta * 12.0
		if not _walk_frames.is_empty():
			var fi := int(_anim_t / 3.0) % _walk_frames.size()
			if fi != _shown_frame:
				_shown_frame = fi
				_sprite.texture = _walk_frames[fi]
		_sprite.offset.y = -absf(sin(_anim_t)) * 2.0   # offset은 y-sort에 영향 X
	else:
		_anim_t = 0.0
		if _shown_frame != -1 and _idle_texture != null:
			_shown_frame = -1
			_sprite.texture = _idle_texture
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
	var fill := Color(0.3, 0.8, 0.35) if (is_player or is_ally) else Color(0.85, 0.22, 0.2)
	draw_rect(Rect2(top, Vector2(w * life_frac, 5)), fill)
	if is_player:
		var mana_frac := clampf(float(mana) / float(maxi(max_mana, 1)), 0.0, 1.0)
		var mtop := Vector2(-w * 0.5, -29.0)
		draw_rect(Rect2(mtop, Vector2(w, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(mtop, Vector2(w * mana_frac, 3)), Color(0.3, 0.5, 0.9))
