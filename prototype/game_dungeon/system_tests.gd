extends RefCounted

const Combat := preload("res://combat.gd")
const Skills := preload("res://skills.gd")
const Craft := preload("res://craft.gd")
const LevelGen := preload("res://level_gen.gd")
const Item := preload("res://item.gd")

static func _check(condition: bool, label: String, failures: Array) -> void:
	if not condition:
		failures.append(label)

static func _connected(level: Dictionary) -> bool:
	var start: Vector2i = level["entrance"]
	var goal: Vector2i = level["exit"]
	var grid: Array = level["grid"]
	var width := int(level["w"])
	var height := int(level["h"])
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if current == goal:
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if not visited.has(next) and int(grid[next.y][next.x]) == 1:
				visited[next] = true
				queue.append(next)
	return false

static func run() -> Dictionary:
	var failures: Array = []

	_check(is_equal_approx(Combat.chance_to_hit(1, 100000, 1, 99), 5.0), "combat hit floor", failures)
	_check(is_equal_approx(Combat.chance_to_hit(100000, 0, 99, 1), 95.0), "combat hit cap", failures)
	_check(Combat.apply_resistance(100, 100) == 0, "resistance immunity", failures)
	_check(Combat.apply_resistance(100, -50) == 150, "negative resistance", failures)
	_check(Combat.sorc_fcr_frames(0) == 13 and Combat.sorc_fcr_frames(200) == 7, "cast breakpoints", failures)
	_check(is_equal_approx(Combat.frames_to_sec(25), 1.0), "25 fps timing", failures)
	_check(Combat.diff_player_resist_penalty(2) == -100 and Combat.diff_hell_physical_floor(2) == 50, "difficulty penalties", failures)
	_check(Combat.warden_max_life(25, 1) == 157 and Combat.warden_max_mana(15, 1) == 26, "warden vitals", failures)

	var expected_skills := ["ember_bolt", "frost_shard", "iron_chant", "phase_step", "storm_lance", "sundering_strike", "void_fury", "weapon_discipline"]
	var actual_skills: Array = Skills.DEFS.keys()
	actual_skills.sort()
	_check(actual_skills == expected_skills, "project-owned skill ids", failures)
	_check(Skills.mana_cost("iron_chant") == 10, "skill mana cost", failures)
	_check(Skills.mana_cost("ember_bolt") == 3 and Skills.mana_cost("storm_lance") == 4 and Skills.mana_cost("phase_step") == 6, "arcanist mana costs", failures)
	_check(is_equal_approx(Skills.sundering_damage_pct(1), 45.0), "sundering scaling", failures)
	_check(is_equal_approx(Skills.iron_chant_bonus_pct(1), 35.0), "iron chant scaling", failures)

	_check(String(Craft.match_runeword("weapon", ["Vey", "Ahn"]).get("name", "")) == "Tempered Edge", "sigil order match", failures)
	_check(Craft.match_runeword("weapon", ["Ahn", "Vey"]).is_empty(), "sigil reverse rejection", failures)
	_check(Craft.upgrade_rune("Ahn") == "Ahnor", "sigil upgrade", failures)
	_check(Craft.upgrade_gem_quality("flawless") == "perfect", "gem upgrade", failures)

	var level_a := LevelGen.generate(424242)
	var level_b := LevelGen.generate(424242)
	_check(int(level_a["w"]) == 27 and int(level_a["h"]) == 27, "level dimensions", failures)
	_check(int(level_a["rooms"]) == 9 and int(level_a["doors"]) == 8, "level topology", failures)
	_check(level_a["entrance"] != level_a["exit"], "distinct level endpoints", failures)
	_check(level_a["entrance"] == level_b["entrance"] and level_a["exit"] == level_b["exit"] and level_a["grid"] == level_b["grid"], "level determinism", failures)
	_check(_connected(level_a), "level connectivity", failures)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var unique_item := Item.generate(rng, Item.WEAPON_BASES[1], 20, "unique")
	_check(Item.display_name(unique_item) == "Rift Cleaver (Hand Axe)", "unique identity", failures)
	_check(int(unique_item["affixes"].get("ed", 0)) == 70, "unique fixed affix", failures)
	_check(Item.quality_color("unique") == Color(0.72, 0.55, 0.28), "unique quality color", failures)

	return {"ok": failures.is_empty(), "checks": 25, "failures": failures}
