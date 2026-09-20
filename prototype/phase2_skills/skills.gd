extends RefCounted
# 바바리안 스킬 정의 + 효과 계산 (딥리서치 Part 3 §1).
# 프로토타입 계수는 근사값 — 정식 값은 skills.txt 임포트(P3 스펙).
# preload로 사용: const Skills := preload("res://skills.gd")

const DEFS := {
	"bash": {"name": "Bash", "tree": "combat", "type": "attack", "mana": 2},
	"berserk": {"name": "Berserk", "tree": "combat", "type": "attack", "mana": 4},
	"battle_orders": {"name": "Battle Orders", "tree": "warcry", "type": "buff", "mana": 10},
	"mastery": {"name": "Sword Mastery", "tree": "mastery", "type": "passive", "mana": 0},
}

static func def_name(id: String) -> String:
	return DEFS[id]["name"]

static func mana_cost(id: String) -> int:
	return int(DEFS[id]["mana"])

# Bash: +데미지% / +명중%
static func bash_damage_pct(lvl: int) -> float:
	return 30.0 + 15.0 * lvl

static func bash_ar_pct(lvl: int) -> float:
	return 45.0 + 5.0 * lvl

# Berserk: 큰 데미지%(물리→마법 전환), 적 방어 무시(프로토타입)
static func berserk_damage_pct(lvl: int) -> float:
	return 100.0 + 15.0 * lvl

# Battle Orders: 최대 Life/Mana +% / 지속
static func bo_bonus_pct(lvl: int) -> float:
	return 35.0 + 3.0 * (lvl - 1)

static func bo_duration(lvl: int) -> float:
	return 30.0 + 10.0 * (lvl - 1)

# Mastery(패시브): +데미지% / +명중% / 데들리스트라이크%(Part 5 §4)
static func mastery_damage_pct(lvl: int) -> float:
	return 28.0 + 8.0 * lvl

static func mastery_ar_pct(lvl: int) -> float:
	return 30.0 + 5.0 * lvl

static func mastery_deadly_strike(lvl: int) -> float:
	return minf(5.0 + 2.0 * lvl, 80.0)
