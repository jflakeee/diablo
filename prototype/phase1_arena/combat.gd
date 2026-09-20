extends RefCounted
# D2 전투 공식 (순수 함수) — 딥리서치 Part 1 §1 / Part 5 §1 기반.
# 전역 class_name 대신 preload 상수로 사용: const CombatLib := preload("res://combat.gd")

# 명중률: 200 * AR/(AR+DR) * Alvl/(Alvl+Dlvl), 하한 5% 상한 95% (Part 1 §1)
static func chance_to_hit(ar: int, defense: int, alvl: int, dlvl: int) -> float:
	var a := float(maxi(ar, 1))
	var d := float(maxi(defense, 0))
	var raw := 200.0 * (a / (a + d)) * (float(alvl) / float(alvl + dlvl))
	return clampf(raw, 5.0, 95.0)

static func roll_hit(rng: RandomNumberGenerator, ar: int, defense: int, alvl: int, dlvl: int) -> bool:
	return rng.randf() * 100.0 < chance_to_hit(ar, defense, alvl, dlvl)

# 물리 데미지: 무기 min~max × (1 + %ED/100) (Part 5 §1, 프로토타입은 단일 ED 버킷)
static func physical_damage(rng: RandomNumberGenerator, dmg_min: int, dmg_max: int, ed_percent: float) -> int:
	var base := rng.randi_range(dmg_min, maxi(dmg_min, dmg_max))
	return int(round(base * (1.0 + ed_percent / 100.0)))

# 바바리안 파생 스탯 (Part 1 §2): 기본55, +4/Vit, +2/Level
static func barbarian_max_life(vit: int, level: int) -> int:
	return int(55 + 4 * vit + 2 * level)

# 바바리안 Mana: 기본10, +1/Energy, +1/Level
static func barbarian_max_mana(energy: int, level: int) -> int:
	return int(10 + energy + level)
