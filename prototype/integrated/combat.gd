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

# 바바리안 파생 스탯 (Part 1 §2)
static func barbarian_max_life(vit: int, level: int) -> int:
	return int(55 + 4 * vit + 2 * level)

static func barbarian_max_mana(energy: int, level: int) -> int:
	return int(10 + energy + level)
