extends RefCounted
# D2 전투 공식 (순수 함수) — 딥리서치 Part 1/5 기반. preload로 사용.

# 명중률: 200 * AR/(AR+DR) * Alvl/(Alvl+Dlvl), 5~95% (Part 1 §1)
static func chance_to_hit(ar: int, defense: int, alvl: int, dlvl: int) -> float:
	var a := float(maxi(ar, 1))
	var d := float(maxi(defense, 0))
	var raw := 200.0 * (a / (a + d)) * (float(alvl) / float(alvl + dlvl))
	return clampf(raw, 5.0, 95.0)

static func roll_hit(rng: RandomNumberGenerator, ar: int, defense: int, alvl: int, dlvl: int) -> bool:
	return rng.randf() * 100.0 < chance_to_hit(ar, defense, alvl, dlvl)

# 물리 데미지: min~max × (1 + %ED/100) (Part 5 §1)
static func physical_damage(rng: RandomNumberGenerator, dmg_min: int, dmg_max: int, ed_percent: float) -> int:
	var base := rng.randi_range(dmg_min, maxi(dmg_min, dmg_max))
	return int(round(base * (1.0 + ed_percent / 100.0)))

# 데들리스트라이크: 확률로 물리 2배 (Part 5 §4)
static func roll_deadly_strike(rng: RandomNumberGenerator, ds_percent: float) -> bool:
	return rng.randf() * 100.0 < ds_percent

# 캐릭터 공격력 근사: AR = max(Dex*5 - 35, 5) × (1 + 보너스%/100)
# (정식은 charstats.txt 클래스 기본 + 무기/스킬 반영 — P2 스펙)
static func character_ar(dex: int, bonus_pct: float) -> int:
	var base := maxf(dex * 5.0 - 35.0, 5.0)
	return int(base * (1.0 + bonus_pct / 100.0))

# 캐릭터 방어 근사: Defense = base + floor(Dex/4)
static func character_defense(dex: int, base_def: int) -> int:
	return int(base_def + floor(dex / 4.0))

# ── 전투 심화 (Part 5 §2~4 / Part 6) ──

# 저항 적용: dmg × (1 − min(resist,cap)/100). resist≥100 → 면역(0). 음수 저항=약점(증폭). (Part 5 §2)
static func apply_resistance(dmg: int, resist: int, cap: int = 75) -> int:
	if resist >= 100:
		return 0
	var r := mini(resist, cap)
	return int(round(dmg * (1.0 - float(r) / 100.0)))

# 최대 저항 캡(기본 75, 아이템으로 최대 95)
static func effective_resist(resist: int, max_cap: int = 75) -> int:
	return mini(resist, max_cap)

# 블록 확률: (shieldBlock × (Dex−15)) / (cLvl × 2), 상한 75% (Part 5 §3)
static func block_chance(shield_block: int, dex: int, clvl: int) -> float:
	if clvl <= 0:
		return 0.0
	var b := float(shield_block) * float(dex - 15) / float(clvl * 2)
	return clampf(b, 0.0, 75.0)

static func roll_block(rng: RandomNumberGenerator, shield_block: int, dex: int, clvl: int) -> bool:
	return rng.randf() * 100.0 < block_chance(shield_block, dex, clvl)

# 생명 흡혈: 물리뎀 × leech% × penalty (Part 5 §4)
static func leech_life(dmg: int, leech_pct: int, penalty: float = 1.0) -> int:
	return int(round(float(dmg) * (float(leech_pct) / 100.0) * penalty))

# 크러싱 블로우: 대상 현재 생명의 비율 감소 (일반 근접 1/4·원거리 1/8, 보스 1/8·1/16) (Part 5 §4)
static func crushing_blow(current_life: int, is_ranged: bool, is_boss: bool) -> int:
	var frac := 0.0
	if is_boss:
		frac = (1.0 / 16.0) if is_ranged else (1.0 / 8.0)
	else:
		frac = (1.0 / 8.0) if is_ranged else (1.0 / 4.0)
	return int(current_life * frac)

# ── 브레이크포인트 (Part 2 §1) ──
# 소서리스 FCR(일반 스펠) → 시전 프레임
static func sorc_fcr_frames(fcr: int) -> int:
	if fcr >= 200: return 7
	if fcr >= 105: return 8
	if fcr >= 63: return 9
	if fcr >= 37: return 10
	if fcr >= 20: return 11
	if fcr >= 9: return 12
	return 13

# 바바리안 FHR → 경직 회복 프레임
static func barb_fhr_frames(fhr: int) -> int:
	if fhr >= 27: return 6
	if fhr >= 15: return 7
	if fhr >= 8: return 8
	return 9

# 프레임 → 초 (25 FPS 논리 모델)
static func frames_to_sec(frames: int) -> float:
	return float(frames) / 25.0

# ── 난이도 스케일링 (Part 2 §3) ──
static func diff_monster_hp_mult(diff: int) -> float:
	var t := [1.0, 1.8, 3.5]
	return float(t[clampi(diff, 0, 2)])

static func diff_monster_resist_bonus(diff: int) -> int:
	var t := [0, 20, 50]
	return int(t[clampi(diff, 0, 2)])

static func diff_player_resist_penalty(diff: int) -> int:
	var t := [0, -40, -100]
	return int(t[clampi(diff, 0, 2)])

static func diff_hell_physical_floor(diff: int) -> int:
	return 50 if diff >= 2 else 0  # Hell: 모든 몬스터 물리 50% 저항 바닥

# 몬스터 Life: X × (n+1)/2 (v1.10+ 인원수)
static func monster_life_players(base_hp: int, players: int) -> int:
	return int(base_hp * (players + 1) / 2.0)

# 바바리안 파생 스탯 (Part 1 §2)
static func barbarian_max_life(vit: int, level: int) -> int:
	return int(55 + 4 * vit + 2 * level)

static func barbarian_max_mana(energy: int, level: int) -> int:
	return int(10 + energy + level)
