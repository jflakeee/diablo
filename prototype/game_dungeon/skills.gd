extends RefCounted
# 바바리안 스킬 정의 + 효과 계산 (딥리서치 Part 3 §1).
# 프로토타입 계수는 근사값 — 정식 값은 skills.txt 임포트(P3 스펙).
# preload로 사용: const Skills := preload("res://skills.gd")

const DEFS := {
	"sundering_strike": {"name": "Sundering Strike", "tree": "combat", "type": "attack", "element": "physical", "mana": 2, "required_level": 1, "requires": []},
	"void_fury": {"name": "Void Fury", "tree": "combat", "type": "attack", "element": "arcane", "mana": 4, "required_level": 6, "requires": ["sundering_strike"]},
	"iron_chant": {"name": "Iron Chant", "tree": "warcry", "type": "buff", "element": "physical", "mana": 10, "required_level": 4, "requires": ["weapon_discipline"]},
	"weapon_discipline": {"name": "Weapon Discipline", "tree": "discipline", "type": "passive", "element": "physical", "mana": 0, "required_level": 1, "requires": []},
	"ember_bolt": {"name": "Ember Bolt", "tree": "pyromancy", "type": "spell", "element": "fire", "mana": 3, "required_level": 1, "requires": []},
	"frost_shard": {"name": "Frost Shard", "tree": "cryomancy", "type": "spell", "element": "cold", "mana": 3, "required_level": 2, "requires": ["ember_bolt"]},
	"storm_lance": {"name": "Storm Lance", "tree": "tempest", "type": "spell", "element": "light", "mana": 4, "required_level": 4, "requires": ["frost_shard"]},
	"phase_step": {"name": "Phase Step", "tree": "tempest", "type": "mobility", "element": "arcane", "mana": 6, "required_level": 6, "requires": ["storm_lance"]},
}

const MAX_LEVEL := 20
const SYNERGIES := {
	"sundering_strike": {"weapon_discipline": 4.0},
	"void_fury": {"sundering_strike": 6.0},
	"iron_chant": {"weapon_discipline": 2.0},
	"ember_bolt": {"frost_shard": 3.0},
	"frost_shard": {"ember_bolt": 3.0},
	"storm_lance": {"phase_step": 4.0},
}

static func def_name(id: String) -> String:
	return DEFS[id]["name"]

static func mana_cost(id: String) -> int:
	return int(DEFS[id]["mana"])

static func can_invest(id: String, learned: Dictionary, character_level: int) -> bool:
	if not DEFS.has(id) or int(learned.get(id, 0)) >= MAX_LEVEL:
		return false
	var definition: Dictionary = DEFS[id]
	if character_level < int(definition.get("required_level", 1)):
		return false
	for prerequisite in definition.get("requires", []):
		if int(learned.get(String(prerequisite), 0)) <= 0:
			return false
	return true

static func synergy_bonus_pct(id: String, learned: Dictionary) -> float:
	var total := 0.0
	var links: Dictionary = SYNERGIES.get(id, {})
	for contributor in links:
		total += float(links[contributor]) * float(learned.get(contributor, 0))
	return total

static func apply_synergy(base_damage: int, id: String, learned: Dictionary) -> int:
	return int(round(float(base_damage) * (1.0 + synergy_bonus_pct(id, learned) / 100.0)))

# Bash: +데미지% / +명중%
static func sundering_damage_pct(lvl: int) -> float:
	return 30.0 + 15.0 * lvl

static func sundering_ar_pct(lvl: int) -> float:
	return 45.0 + 5.0 * lvl

# Berserk: 큰 데미지%(물리→마법 전환), 적 방어 무시(프로토타입)
static func void_fury_damage_pct(lvl: int) -> float:
	return 100.0 + 15.0 * lvl

# Battle Orders: 최대 Life/Mana +% / 지속
static func iron_chant_bonus_pct(lvl: int) -> float:
	return 35.0 + 3.0 * (lvl - 1)

static func iron_chant_duration(lvl: int) -> float:
	return 30.0 + 10.0 * (lvl - 1)

# Mastery(패시브): +데미지% / +명중% / 데들리스트라이크%(Part 5 §4)
static func discipline_damage_pct(lvl: int) -> float:
	return 28.0 + 8.0 * lvl

static func discipline_ar_pct(lvl: int) -> float:
	return 30.0 + 5.0 * lvl

static func discipline_deadly_strike(lvl: int) -> float:
	return minf(5.0 + 2.0 * lvl, 80.0)
