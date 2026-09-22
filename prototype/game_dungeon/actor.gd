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

enum AnimState { IDLE, WALK, ATTACK, CAST, HIT, DEATH }
enum Facing { SOUTH, EAST, NORTH, WEST }

var _sprite: AnimatedSprite2D
var _idle_texture: Texture2D
var _walk_frames: Array = []
var _direction_sets := {}
var _facing: Facing = Facing.SOUTH
var _facings_seen := {Facing.SOUTH: true}
var _anim_state: AnimState = AnimState.IDLE
var _states_seen := {AnimState.IDLE: true}
var _state_timer := 0.0
var _facing_hold := 0.0

func setup(tex: Texture2D) -> void:
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	set_sprite_texture(tex)

var _base_scale := 1.0
var _prev_grid := Vector2.ZERO
var _anim_t := 0.0
var _pop_t := 0.0

func _new_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.clear_all()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	return frames

func _add_animation(frames: SpriteFrames, name: String, textures: Array, fps: float) -> void:
	frames.add_animation(name)
	frames.set_animation_loop(name, true)
	frames.set_animation_speed(name, fps)
	for texture in textures:
		frames.add_frame(name, texture)

func _rebuild_animations() -> void:
	if _sprite == null or _idle_texture == null:
		return
	var frames := _new_frames()
	if _direction_sets.is_empty():
		_add_animation(frames, "idle", [_idle_texture], 1.0)
		_add_animation(frames, "walk", _walk_frames if not _walk_frames.is_empty() else [_idle_texture], 8.0)
	else:
		var names := ["s", "e", "n", "w"]
		for direction in 4:
			var selected: Dictionary = _direction_sets.get(direction, {})
			if selected.is_empty():
				continue
			_add_animation(frames, "idle_" + names[direction], [selected["idle"]], 1.0)
			_add_animation(frames, "walk_" + names[direction], selected["walk"], 8.0)
	_sprite.sprite_frames = frames
	_apply_animation(true)

func set_sprite_texture(tex: Texture2D, scale_v: float = 1.0) -> void:
	if _sprite:
		_base_scale = scale_v
		_sprite.scale = Vector2(scale_v, scale_v)
		_idle_texture = tex
		_walk_frames.clear()
		_direction_sets.clear()
		_rebuild_animations()

func set_sprite_frames(idle: Texture2D, walk: Array, scale_v: float = 1.0) -> void:
	_idle_texture = idle
	_walk_frames = walk
	_direction_sets.clear()
	if _sprite:
		_base_scale = scale_v
		_sprite.scale = Vector2(scale_v, scale_v)
		_rebuild_animations()

func set_directional_frames(sets: Dictionary, scale_v: float = 1.0) -> void:
	_direction_sets = sets
	_facing = Facing.SOUTH
	var south: Dictionary = sets.get(0, {})
	if south.is_empty():
		return
	_idle_texture = south["idle"]
	_walk_frames = south["walk"]
	if _sprite:
		_base_scale = scale_v
		_sprite.scale = Vector2(scale_v, scale_v)
		_rebuild_animations()

static func direction_for_motion(motion: Vector2, current: int) -> int:
	if motion.length() < 0.05 or absf(absf(motion.x) - absf(motion.y)) < 0.05:
		return current
	if absf(motion.x) > absf(motion.y):
		return Facing.EAST if motion.x > 0.0 else Facing.WEST
	return Facing.SOUTH if motion.y > 0.0 else Facing.NORTH

func update_facing(grid_velocity: Vector2, immediate: bool = false) -> void:
	var next_facing := direction_for_motion(grid_velocity, _facing)
	if next_facing == _facing or (_facing_hold > 0.0 and not immediate):
		return
	_facing = next_facing as Facing
	_facing_hold = 0.075
	_facings_seen[_facing] = true
	var selected: Dictionary = _direction_sets.get(_facing, {})
	if not selected.is_empty():
		_idle_texture = selected["idle"]
		_walk_frames = selected["walk"]
	_apply_animation(true)

func facing_count() -> int:
	return _facings_seen.size()

func pop() -> void:   # 공격 시 살짝 팽창
	play_attack(Vector2.ZERO)

static func _priority(state: AnimState) -> int:
	return [0, 1, 3, 3, 4, 5][state]

func _set_state(state: AnimState, duration: float = 0.0) -> void:
	if _state_timer > 0.0 and _priority(state) < _priority(_anim_state):
		return
	_anim_state = state
	_states_seen[state] = true
	_state_timer = duration
	_apply_animation()

func set_motion(grid_velocity: Vector2) -> void:
	update_facing(grid_velocity)
	if _anim_state in [AnimState.ATTACK, AnimState.CAST, AnimState.HIT, AnimState.DEATH] and _state_timer > 0.0:
		return
	_set_state(AnimState.WALK if grid_velocity.length() >= 0.05 else AnimState.IDLE)

func play_attack(target_grid_delta: Vector2) -> void:
	if target_grid_delta.length() >= 0.05:
		update_facing(target_grid_delta, true)
	_set_state(AnimState.ATTACK, 0.16)
	_pop_t = 0.16

func play_cast(target_grid_delta: Vector2) -> void:
	if target_grid_delta.length() >= 0.05:
		update_facing(target_grid_delta, true)
	_set_state(AnimState.CAST, 0.20)
	_pop_t = 0.16

func play_hit() -> void:
	_set_state(AnimState.HIT, 0.12)

func play_death() -> void:
	_anim_state = AnimState.DEATH
	_states_seen[AnimState.DEATH] = true
	_state_timer = INF
	_apply_animation(true)

func _apply_animation(force: bool = false) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var base := "walk" if _anim_state == AnimState.WALK else "idle"
	var suffix: String = String(["s", "e", "n", "w"][_facing]) if not _direction_sets.is_empty() else ""
	var animation: String = base + ("_" + suffix if not suffix.is_empty() else "")
	if _sprite.sprite_frames.has_animation(animation) and (force or _sprite.animation != animation):
		_sprite.play(animation)

static func animation_selftest() -> bool:
	return direction_for_motion(Vector2(1, 0), Facing.SOUTH) == Facing.EAST \
		and direction_for_motion(Vector2(-1, 0), Facing.SOUTH) == Facing.WEST \
		and direction_for_motion(Vector2(0, -1), Facing.SOUTH) == Facing.NORTH \
		and direction_for_motion(Vector2(0.01, 0), Facing.SOUTH) == Facing.SOUTH \
		and direction_for_motion(Vector2(1, 1), Facing.NORTH) == Facing.NORTH \
		and _priority(AnimState.DEATH) > _priority(AnimState.HIT) \
		and _priority(AnimState.HIT) > _priority(AnimState.ATTACK) \
		and _priority(AnimState.ATTACK) > _priority(AnimState.WALK)

func state_count() -> int:
	return _states_seen.size()

# AnimatedSprite2D 상태 전이 + 기존 bob/pop 폴백 효과.
func animate(delta: float) -> void:
	if slow_timer > 0.0:
		slow_timer -= delta
	if _sprite == null:
		return
	_facing_hold = maxf(0.0, _facing_hold - delta)
	if _state_timer > 0.0 and _state_timer != INF:
		_state_timer = maxf(0.0, _state_timer - delta)
	var grid_position := Vector2(gx, gy)
	var grid_motion := grid_position - _prev_grid
	_prev_grid = grid_position
	var moving := grid_motion.length() > 0.01
	set_motion(grid_motion)
	if moving:
		_anim_t += delta * 12.0
		_sprite.offset.y = -absf(sin(_anim_t)) * 2.0   # offset은 y-sort에 영향 X
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
		play_death()
		modulate = Color(0.4, 0.4, 0.4, 0.7)
		died.emit(self)
	else:
		play_hit()
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
